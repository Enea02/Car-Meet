# 04 — GARAGE

> **Subagente:** Garage personale (lista, dettaglio, aggiungi auto)
> **Repository:** `Car-Meet/raduni_app/`
> **Prerequisiti:** `00-BOOTSTRAP.md` + `01-AUTH.md` completati. **Non** dipende da Raduni.
> **Output:** Garage funzionante con foto, dettaglio, aggiunta. Auto utilizzabili come "auto esposta" nelle iscrizioni.
> **Stima:** 6-8 ore di lavoro Claude Code

---

## 1. Obiettivo

Tre stub diventano feature reali:

1. `GarageScreen` — hero auto principale + griglia auto secondarie.
2. `AutoDetailScreen` — dettaglio auto con cover, spec mono, raduni passati.
3. `AddAutoScreen` — form aggiungi auto con foto.

**Schermate coinvolte:**

| File | Stato attuale | Azione |
|---|---|---|
| `lib/features/garage/presentation/garage_screen.dart` | ❌ Stub | Implementare layout `HANDOFF.md` § 5.7 |
| `lib/features/garage/presentation/auto_detail_screen.dart` | ❌ Stub | Implementare `HANDOFF.md` § 5.8 |
| `lib/features/garage/presentation/add_auto_screen.dart` | ❌ Stub | Form `HANDOFF.md` § 5.8 |

> ✋ **Nota:** può andare in **parallelo** con `03-MAPPA.md`. Sono feature
> indipendenti (sessioni Claude Code separate, ok).

---

## 2. Modello dati

### 2.1 Lato Supabase

Da `Car-Meet/01-ARCHITETTURA.md`. Tabella `auto`:

| Campo | Tipo | Note |
|---|---|---|
| `id` | uuid (PK) | |
| `proprietario_uid` | uuid (FK profiles) | |
| `marca` | text | |
| `modello` | text | |
| `anno` | int | |
| `targa` | text? | |
| `colore` | text? | |
| `cilindrata` | text? | "2.0 V6", "1600cc", ecc. |
| `cv` | int? | |
| `cover_url` | text? | URL Storage |
| `note` | text? | |
| `principale` | boolean | Default false |
| `created_at` | timestamptz | |

Bucket Storage: `auto-photos` (pubblico).

### 2.2 Lato Dart — modello esistente

Il file `lib/shared/models/auto.dart` **esiste già**. **Leggi prima** la
struttura attuale e poi adatta. Probabili campi presenti (verificare):

```dart
class Auto {
  final String id;
  final String marca;
  final String modello;
  final int anno;
  final String targa;
  final String? colore;
  final String? cilindrata;
  final int? cv;
  final String coverUrl;
  // ...
}
```

> ⚠️ **Nota:** il modello potrebbe **non avere** i campi `principale` (bool) e
> `note` (String?). Se mancano, **aggiungili** con default sensati (`bool
> principale = false`, `String? note`) per non rompere i `MockData` esistenti.

### 2.3 Funzione SQL `set_auto_principale`

Vincolo "una sola auto principale per utente": deve esistere **lato Supabase**.
Se in `01-ARCHITETTURA.md` non c'è, segnalalo all'utente e includi questa
funzione SQL come parte del task — **da eseguire da Supabase SQL Editor**:

```sql
create or replace function set_auto_principale(auto_id uuid, utente_uid uuid)
returns void
language plpgsql security definer as $$
begin
  update auto set principale = false where proprietario_uid = utente_uid;
  update auto set principale = true where id = auto_id and proprietario_uid = utente_uid;
end;
$$;
```

---

## 3. Architettura della feature

```
features/garage/
├── data/
│   └── auto_repository.dart        # Da creare
├── application/
│   └── garage_providers.dart       # Da creare
└── presentation/
    ├── garage_screen.dart          # Da costruire
    ├── auto_detail_screen.dart     # Da costruire
    ├── add_auto_screen.dart        # Da costruire
    └── widgets/                    # Da creare
        ├── auto_hero_card.dart
        └── auto_compact_card.dart
```

```bash
mkdir -p raduni_app/lib/features/garage/data
mkdir -p raduni_app/lib/features/garage/application
mkdir -p raduni_app/lib/features/garage/presentation/widgets
```

---

## 4. Step 1 — `AutoRepository`

`raduni_app/lib/features/garage/data/auto_repository.dart`:

```dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/guard.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/models/auto.dart';

class AutoRepository {
  final sb.SupabaseClient _client;
  AutoRepository(this._client);

  /// Tutte le auto dell'utente loggato, ordinate con principale per prima.
  Future<List<Auto>> mieAuto() {
    return guardSupabase(() async {
      final uid = _client.auth.currentUser!.id;
      final rows = await _client
          .from('auto')
          .select()
          .eq('proprietario_uid', uid)
          .order('principale', ascending: false)
          .order('created_at');
      return (rows as List)
          .map((r) => _autoFromRow(r as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Auto> getById(String id) {
    return guardSupabase(() async {
      final row = await _client.from('auto').select().eq('id', id).single();
      return _autoFromRow(row);
    });
  }

  Future<String> create({
    required String marca,
    required String modello,
    required int anno,
    String? targa,
    String? colore,
    String? cilindrata,
    int? cv,
    String? note,
    File? coverFile,
    bool principale = false,
  }) {
    return guardSupabase(() async {
      final uid = _client.auth.currentUser!.id;

      String? coverUrl;
      if (coverFile != null) {
        coverUrl = await _uploadCover(coverFile, uid);
      }

      final inserted = await _client
          .from('auto')
          .insert({
            'proprietario_uid': uid,
            'marca': marca,
            'modello': modello,
            'anno': anno,
            'targa': targa,
            'colore': colore,
            'cilindrata': cilindrata,
            'cv': cv,
            'note': note,
            'cover_url': coverUrl,
            'principale': principale,
          })
          .select('id')
          .single();

      return inserted['id'] as String;
    });
  }

  Future<void> update(String id, Map<String, dynamic> fields) {
    return guardSupabase(() async {
      await _client.from('auto').update(fields).eq('id', id);
    });
  }

  Future<void> delete(String id) {
    return guardSupabase(() async {
      await _client.from('auto').delete().eq('id', id);
    });
  }

  Future<void> setPrincipale(String id) {
    return guardSupabase(() async {
      final uid = _client.auth.currentUser!.id;
      await _client.rpc('set_auto_principale', params: {
        'auto_id': id,
        'utente_uid': uid,
      });
    });
  }

  Future<String> _uploadCover(File file, String uid) async {
    final fileName = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage
        .from('auto-photos')
        .upload(fileName, file, fileOptions: const sb.FileOptions(upsert: true));
    return _client.storage.from('auto-photos').getPublicUrl(fileName);
  }

  Auto _autoFromRow(Map<String, dynamic> row) {
    return Auto(
      id: row['id'] as String,
      marca: row['marca'] as String,
      modello: row['modello'] as String,
      anno: row['anno'] as int,
      targa: row['targa'] as String? ?? '',
      colore: row['colore'] as String?,
      cilindrata: row['cilindrata'] as String?,
      cv: row['cv'] as int?,
      coverUrl: row['cover_url'] as String? ?? _defaultAutoCover,
      // Aggiungi qui altri campi (note, principale) se li hai aggiunti al
      // modello Auto secondo §2.2
    );
  }

  static const _defaultAutoCover =
      'https://images.unsplash.com/photo-1494976388531-d1058494cdd8?w=900';
}

final autoRepositoryProvider = Provider<AutoRepository>((ref) {
  return AutoRepository(ref.watch(supabaseClientProvider));
});
```

> ⚠️ **Adatta il factory `_autoFromRow` ai campi reali** del modello `Auto`
> dopo averlo letto. Se il modello esistente non ha `id`, **aggiungilo come
> primo campo** (è essenziale per qualsiasi DB).

---

## 5. Step 2 — Provider

`raduni_app/lib/features/garage/application/garage_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/auto.dart';
import '../data/auto_repository.dart';

final mieAutoProvider = FutureProvider<List<Auto>>((ref) {
  return ref.watch(autoRepositoryProvider).mieAuto();
});

/// Auto principale (la prima con principale=true) o null se nessuna.
final autoPrincipaleProvider = Provider<AsyncValue<Auto?>>((ref) {
  final all = ref.watch(mieAutoProvider);
  return all.whenData((list) {
    if (list.isEmpty) return null;
    return list.first; // ordinata per principale desc nel repo
  });
});

/// Tutte le altre auto (esclusa la principale).
final autoSecondarieProvider = Provider<AsyncValue<List<Auto>>>((ref) {
  final all = ref.watch(mieAutoProvider);
  return all.whenData((list) => list.length > 1 ? list.sublist(1) : []);
});

final autoDetailProvider = FutureProvider.family<Auto, String>((ref, id) {
  return ref.watch(autoRepositoryProvider).getById(id);
});
```

---

## 6. Step 3 — `GarageScreen`

Spec: `raduni_app/HANDOFF.md` § 5.7. Layout:

```
┌─────────────────────────────────┐
│ Mio garage          [+ Aggiungi] │  ← header (no AppBar)
├─────────────────────────────────┤
│  ┌───────────────────────────┐  │
│  │   Cover auto principale   │  │
│  │     full-bleed 280h       │  │
│  │  CR 123 AB (mono)         │  │
│  │  Alfa Romeo 147 GTA       │  │
│  │  2003 · 250 CV            │  │
│  └───────────────────────────┘  │
│ Le tue altre auto               │
│  ┌────────┐ ┌────────┐          │
│  │  BMW   │ │ Lancia │          │
│  │  E30   │ │ Delta  │          │
│  └────────┘ └────────┘          │
└─────────────────────────────────┘
```

```dart
class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final principale = ref.watch(autoPrincipaleProvider);
    final secondarie = ref.watch(autoSecondarieProvider);

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async => ref.invalidate(mieAutoProvider),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Mio garage',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/auto/new'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Aggiungi'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Hero auto principale
            principale.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: _ErrorBlock(
                  message: e is AppException ? e.message : 'Errore',
                  onRetry: () => ref.invalidate(mieAutoProvider),
                ),
              ),
              data: (auto) {
                if (auto == null) {
                  return const SliverToBoxAdapter(child: _EmptyGarage());
                }
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AutoHeroCard(
                      auto: auto,
                      onTap: () => context.push('/auto/${auto.id}'),
                    ),
                  ),
                );
              },
            ),

            // ── Sezione "Altre auto"
            secondarie.maybeWhen(
              data: (list) => list.isEmpty
                  ? const SliverToBoxAdapter(child: SizedBox.shrink())
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 100),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Le tue altre auto',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.9,
                              children: list
                                  .map((a) => AutoCompactCard(
                                        auto: a,
                                        onTap: () =>
                                            context.push('/auto/${a.id}'),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
              orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 7. Step 4 — `AutoHeroCard` e `AutoCompactCard`

`auto_hero_card.dart`:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../shared/models/auto.dart';
import '../../../../theme/app_colors.dart';

class AutoHeroCard extends StatelessWidget {
  final Auto auto;
  final VoidCallback onTap;
  const AutoHeroCard({super.key, required this.auto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Hero(
                tag: 'auto-${auto.id}-cover',
                child: CachedNetworkImage(
                  imageUrl: auto.coverUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (auto.targa.isNotEmpty)
                    Text(
                      auto.targa,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSubtle,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${auto.marca} ${auto.modello}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      auto.anno.toString(),
                      if (auto.cilindrata != null) auto.cilindrata!,
                      if (auto.cv != null) '${auto.cv} CV',
                    ].join(' · '),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

> ⚠️ **Su `fontFamily: 'monospace'`:** è il fallback di sistema. Se in
> `app_theme.dart` esiste un helper `AppTheme.mono(...)`, **usalo invece**.
> Verifica leggendo `lib/theme/app_theme.dart`.

`auto_compact_card.dart`: card 2-col più piccola, struttura analoga ma
`AspectRatio: 4/3` e font ridotti. Stesso pattern.

---

## 8. Step 5 — `AutoDetailScreen`

Spec: `raduni_app/HANDOFF.md` § 5.8.

Layout: `SliverAppBar` con cover + sezione spec mono + sezione "Raduni passati
con questa auto".

```dart
class AutoDetailScreen extends ConsumerWidget {
  final String id;
  const AutoDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoAsync = ref.watch(autoDetailProvider(id));

    return Scaffold(
      body: autoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (auto) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Hero(
                  tag: 'auto-${auto.id}-cover',
                  child: CachedNetworkImage(
                    imageUrl: auto.coverUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    '${auto.marca} ${auto.modello}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SpecGrid(auto: auto),
                  const SizedBox(height: 32),
                  // TODO: sezione raduni passati con questa auto.
                  // Richiede join iscrizioni × raduni filtrato per auto_id.
                  // Implementabile, ma può rimanere TODO se il tempo è poco.
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

`_SpecGrid` mostra anno/cilindrata/CV/targa/colore in griglia 2-col, ognuno
con label inkSubtle 11pt e valore monospace 14pt.

---

## 9. Step 6 — `AddAutoScreen`

Spec: `raduni_app/HANDOFF.md` § 5.8.

Form scrollabile con campi:

- **Marca** — `DropdownButtonFormField` con lista hardcoded delle 30 marche
  più comuni (Alfa Romeo, BMW, Audi, Mercedes, ...). Voce "Altro" → mostra
  `TextFormField`.
- **Modello** — `TextFormField`, validatore not empty.
- **Anno** — `TextFormField` numerico, range 1900-anno corrente+1.
- **Targa** — `TextFormField` opzionale, autocompleta uppercase.
- **Colore** — `TextFormField` opzionale.
- **Cilindrata** — `TextFormField` opzionale ("2.0 V6").
- **CV** — `TextFormField` numerico opzionale.
- **Note** — `TextFormField(maxLines: 4)` opzionale.
- **Foto** — `image_picker` con preview.
- **Auto principale** — `SwitchListTile`. Se l'utente non ha ancora auto,
  default true.

Bottone "Salva auto" → `repository.create(...)` → `context.pop()` con
`ref.invalidate(mieAutoProvider)`.

```dart
Future<void> _save() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _saving = true);
  try {
    await ref.read(autoRepositoryProvider).create(
          marca: _marca,
          modello: _modelloCtrl.text.trim(),
          anno: int.parse(_annoCtrl.text),
          targa: _targaCtrl.text.trim().toUpperCase(),
          colore: _coloreCtrl.text.trim().isEmpty ? null : _coloreCtrl.text.trim(),
          cilindrata: _cilCtrl.text.trim().isEmpty ? null : _cilCtrl.text.trim(),
          cv: int.tryParse(_cvCtrl.text),
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          coverFile: _foto,
          principale: _principale,
        );
    ref.invalidate(mieAutoProvider);
    if (mounted) context.pop();
  } on AppException catch (e) {
    _showError(e.message);
  } finally {
    if (mounted) setState(() => _saving = false);
  }
}
```

> ⚠️ **Permessi iOS per image_picker:** stesse stringhe di `02-RADUNI.md` § 8.
> Se non sono già state aggiunte (cioè se il subagente Raduni non le ha
> ancora messe), aggiungi tu in `raduni_app/ios/Runner/Info.plist`:
> ```xml
> <key>NSPhotoLibraryUsageDescription</key>
> <string>Raduni usa l'accesso alle foto per scegliere la cover delle tue auto.</string>
> <key>NSCameraUsageDescription</key>
> <string>Raduni usa la fotocamera per scattare foto delle tue auto e dei raduni.</string>
> ```
> Su Android `CAMERA` è già configurato.

---

## 10. Empty state garage

```dart
class _EmptyGarage extends StatelessWidget {
  const _EmptyGarage();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 60, 40, 100),
      child: Column(
        children: [
          const Icon(Icons.garage_outlined, size: 80, color: AppColors.inkSubtle),
          const SizedBox(height: 20),
          const Text(
            'Il tuo garage è vuoto',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            "Aggiungi la tua prima auto. Potrai esporla ai raduni a cui ti iscrivi.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.inkMuted, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/auto/new'),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi prima auto'),
          ),
        ],
      ),
    );
  }
}
```

---

## 11. Test manuali

1. **Garage vuoto:** dopo signup, vedi empty state.
2. **Aggiungi prima auto:** form → submit → torna a garage con hero card.
3. **Aggiungi seconda auto, principale=false:** vedi nella griglia "altre".
4. **Tap su hero:** apre dettaglio con animazione Hero della cover.
5. **Tap su seconda auto:** anch'essa apre dettaglio.
6. **Foto upload:** mostra preview prima di salvare. Dopo save, l'immagine
   appare nella card.
7. **Validazione:** anno = 0 → errore inline. Modello vuoto → errore inline.
8. **No connessione:** error block con bottone retry.

---

## 12. Rischi e mitigazioni

| Rischio | Impatto | Mitigazione |
|---|---|---|
| Modello `Auto` esistente non ha tutti i campi della tabella DB → repository crash al `_autoFromRow` | **Alto** | **Leggi prima** `lib/shared/models/auto.dart` e aggiungi i campi mancanti come nullable / con default |
| Image picker su iOS senza Info.plist → crash | **Alto** | Vedi nota §9 sui permessi iOS |
| Upload foto > 5MB su rete lenta → timeout | **Medio** | `image_picker` ha già parametro `imageQuality: 80, maxWidth: 1600` da impostare nel codice |
| RPC `set_auto_principale` non creata → errore al toggle | **Medio** | Vedi §2.3 — far eseguire SQL all'utente. Fallback: due update sequenziali lato client |
| Trigger DB "una sola principale" non creato → garage con 2 auto principali | **Medio** | Repository legge sempre con `order` e prende la prima. Se ce ne sono 2 → ordine arbitrario, accettabile finché il trigger non c'è |
| User cancella unica auto → garage vuoto ma raduni a cui era iscritto perdono `auto_id` | **Basso** | FK in `iscrizioni` con `on delete set null`. Verificare in `01-ARCHITETTURA.md` |

---

## 13. Definition of Done

- [ ] Modello `Auto` ha tutti i campi necessari (verificato e adattato se mancanti)
- [ ] `auto_repository.dart` con tutti i metodi
- [ ] `garage_providers.dart` con `mieAutoProvider`, `autoPrincipaleProvider`, `autoSecondarieProvider`, `autoDetailProvider`
- [ ] `GarageScreen` completa con hero + griglia + empty state
- [ ] `AutoDetailScreen` con SliverAppBar + spec
- [ ] `AddAutoScreen` con form completo + image picker
- [ ] Hero animation tra card e dettaglio
- [ ] Permessi iOS Info.plist aggiunti per image_picker (se mancanti)
- [ ] Funzione SQL `set_auto_principale` documentata o creata
- [ ] Compressione immagini lato client (`imageQuality: 80, maxWidth: 1600`)
- [ ] Tutti gli 8 test manuali §11 passati
- [ ] `cd raduni_app && flutter analyze` pulito
- [ ] `raduni_app/HANDOFF.md` aggiornato (sezioni 5.7, 5.8 da TODO a "✅ FATTA")

Quando completo:

> "Garage completato. Auto repository, hero card, dettaglio e form aggiungi operativi. Pronto per Profilo (`claude/05-PROFILO.md`)."
