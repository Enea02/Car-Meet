# 05 — PROFILO

> **Subagente:** Profilo utente, statistiche, impostazioni, logout
> **Repository:** `Car-Meet/raduni_app/`
> **Prerequisiti:** `00-BOOTSTRAP.md` + `01-AUTH.md` + `02-RADUNI.md` + `04-GARAGE.md` completati.
> **Output:** `ProfileScreen` completa con avatar, statistiche, raduni passati, lista impostazioni, logout funzionante.
> **Stima:** 3-5 ore di lavoro Claude Code

---

## 1. Obiettivo

Trasformare `lib/features/profile/presentation/profile_screen.dart` da stub a
schermata completa, con:

1. Header avatar + nome + città + bottone "Modifica".
2. 3 numeri grandi: raduni partecipati · raduni passati · auto.
3. Lista navigabile: I miei raduni · Raduni passati · Impostazioni · Logout.

È **l'ultimo subagente**. Quando questo è completo, l'app è MVP-ready.

> ✋ **Vincolo:** non implementare l'editing del profilo full ora. Il bottone
> "Modifica" può aprire una schermata `/profile/edit` che è uno stub semplice
> (TextField nome, città, bio, salva). Se il tempo è poco, lascialo come
> `TODO` — il logout e le statistiche sono prioritari.

---

## 2. Modello dati

Riusa `AppUser` da `01-AUTH.md` e i provider già esistenti:

- `currentUserProvider` → `AsyncValue<AppUser?>`
- `mieAutoProvider` da `04-GARAGE.md` → numero auto

**Nuove query** da aggiungere in un provider dedicato (vedi §4):

- Conteggio raduni a cui l'utente è iscritto (futuri + passati).
- Conteggio raduni passati a cui l'utente ha partecipato.

---

## 3. Architettura

```
features/profile/
├── application/
│   └── profile_providers.dart      # Da creare
└── presentation/
    ├── profile_screen.dart         # Da costruire (sostituisce stub)
    ├── edit_profile_screen.dart    # OPZIONALE — solo se c'è tempo
    └── widgets/                    # Da creare
        ├── stat_block.dart
        └── settings_tile.dart
```

```bash
mkdir -p raduni_app/lib/features/profile/application
mkdir -p raduni_app/lib/features/profile/presentation/widgets
```

---

## 4. Step 1 — Provider statistiche

`raduni_app/lib/features/profile/application/profile_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/guard.dart';
import '../../../core/supabase/supabase_client.dart';

class ProfileStats {
  final int raduniPartecipati;
  final int raduniPassati;
  final int autoCount;
  const ProfileStats({
    required this.raduniPartecipati,
    required this.raduniPassati,
    required this.autoCount,
  });
}

final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser!.id;

  return guardSupabase(() async {
    // Conteggio iscrizioni totali con join sui raduni per la data
    final iscrizioniRes = await client
        .from('iscrizioni')
        .select('raduno_id, raduni!inner(quando)')
        .eq('utente_uid', uid);

    final all = iscrizioniRes as List;
    final now = DateTime.now();
    final passati = all.where((r) {
      final q = DateTime.parse(
        (r as Map)['raduni']['quando'] as String,
      );
      return q.isBefore(now);
    }).length;

    // Conteggio auto
    final autoRes = await client
        .from('auto')
        .select('id')
        .eq('proprietario_uid', uid);

    return ProfileStats(
      raduniPartecipati: all.length,
      raduniPassati: passati,
      autoCount: (autoRes as List).length,
    );
  });
});
```

> ⚠️ **Nota Importante:** la riga "seguaci" in `HANDOFF.md` § 5.9 è una
> feature social non implementata. **Sostituiscila** con "auto" (numero di
> auto in garage). Documentalo in un commento del codice.

---

## 5. Step 2 — `ProfileScreen`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_colors.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../application/profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(profileStatsProvider);

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {
          ref.invalidate(currentUserProvider);
          ref.invalidate(profileStatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            // ── Header utente
            userAsync.when(
              loading: () => const _UserHeaderSkeleton(),
              error: (e, _) => Text('Errore: $e'),
              data: (user) {
                if (user == null) return const SizedBox.shrink();
                return _UserHeader(user: user);
              },
            ),
            const SizedBox(height: 28),

            // ── Statistiche
            statsAsync.when(
              loading: () => const _StatsSkeleton(),
              error: (_, __) => const SizedBox.shrink(),
              data: (stats) => _StatsRow(stats: stats),
            ),
            const SizedBox(height: 32),

            // ── Lista impostazioni
            _SettingsTile(
              icon: Icons.event_note_outlined,
              label: 'I miei raduni',
              onTap: () => context.push('/profile/raduni'),
            ),
            _SettingsTile(
              icon: Icons.history,
              label: 'Raduni passati',
              onTap: () => context.push('/profile/raduni?filter=passati'),
            ),
            const Divider(height: 1, color: AppColors.divider),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Notifiche',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifiche in arrivo')),
                );
              },
            ),
            _SettingsTile(
              icon: Icons.help_outline,
              label: 'Aiuto e contatti',
              onTap: () {},
            ),
            const Divider(height: 1, color: AppColors.divider),
            _SettingsTile(
              icon: Icons.logout,
              label: 'Esci',
              destructive: true,
              onTap: () => _confirmLogout(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Uscire?'),
        content: const Text("Dovrai accedere di nuovo per usare l'app."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Esci'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authRepositoryProvider).signOut();
      // Il redirect del router porta automaticamente a /onboarding
    }
  }
}
```

---

## 6. Step 3 — Widget `_UserHeader` e `_StatsRow`

```dart
class _UserHeader extends StatelessWidget {
  final AppUser user;
  const _UserHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.surfaceMuted,
          backgroundImage: user.avatarUrl != null
              ? CachedNetworkImageProvider(user.avatarUrl!)
              : null,
          child: user.avatarUrl == null
              ? Text(
                  (user.nome ?? '?').substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.nome ?? user.email,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
              if (user.citta != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 14, color: AppColors.inkMuted),
                    const SizedBox(width: 4),
                    Text(
                      user.citta!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        OutlinedButton(
          onPressed: () => context.push('/profile/edit'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: const Text('Modifica'),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final ProfileStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.divider),
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _StatBlock(value: stats.raduniPartecipati, label: 'Raduni')),
          Container(width: 1, height: 40, color: AppColors.divider),
          Expanded(child: _StatBlock(value: stats.raduniPassati, label: 'Passati')),
          Container(width: 1, height: 40, color: AppColors.divider),
          Expanded(child: _StatBlock(value: stats.autoCount, label: 'Auto')),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final int value;
  final String label;
  const _StatBlock({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w400,
            color: AppColors.ink,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.inkSubtle,
            letterSpacing: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
```

> ⚠️ **Sui font display:** `HANDOFF.md` parla di "Instrument Serif Italic" per
> i numeri grandi. Se in `app_theme.dart` esiste un helper
> `AppTheme.displayNumber(...)` o simile, **usalo** al posto del `TextStyle`
> hardcoded sopra. Se non esiste e `google_fonts` non è installato (vedi
> `CLAUDE.md` § 3), tieni il font di sistema — è accettabile per MVP.

---

## 7. Step 4 — `_SettingsTile`

```dart
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.red.shade700 : AppColors.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (!destructive)
              const Icon(Icons.arrow_forward_ios,
                  color: AppColors.inkSubtle, size: 14),
          ],
        ),
      ),
    );
  }
}
```

---

## 8. Step 5 — Editing profilo (opzionale)

`edit_profile_screen.dart`: form `Nome` + `Città` + `Bio` + cambio avatar
(image picker → upload su bucket `avatars` Storage). Aggiorna `profiles`
table. Invalida `currentUserProvider`.

> ✋ **Solo se tempo.** Bottone "Modifica" può temporaneamente mostrare
> SnackBar "Modifica profilo in arrivo".

---

## 9. Routing — aggiunte

In `raduni_app/lib/routing/app_router.dart` aggiungi due rotte (mantenendo
tutte quelle esistenti):

```dart
GoRoute(
  path: '/profile/edit',
  builder: (_, __) => const EditProfileScreen(),
),
GoRoute(
  path: '/profile/raduni',
  builder: (_, state) {
    final filter = state.uri.queryParameters['filter']; // 'passati' o null
    return MieiRaduniScreen(filter: filter);
  },
),
```

`MieiRaduniScreen` è una semplice lista che riusa `CompactRadunoCard`
filtrando le iscrizioni dell'utente. Implementazione minima:

```dart
final mieiRaduniProvider = FutureProvider.autoDispose
    .family<List<Raduno>, bool>((ref, soloPassati) async {
  final client = ref.watch(supabaseClientProvider);
  final repo = ref.watch(raduniRepositoryProvider);
  final uid = client.auth.currentUser!.id;

  final res = await client
      .from('iscrizioni')
      .select('raduni!inner(*)')
      .eq('utente_uid', uid);

  final raduni = (res as List)
      .map((r) => repo.radunoFromRow(
            (r as Map)['raduni'] as Map<String, dynamic>,
          ))
      .toList();

  if (soloPassati) {
    final now = DateTime.now();
    return raduni.where((r) => r.quando.isBefore(now)).toList();
  }
  return raduni;
});
```

> ⚠️ **Importante:** `radunoFromRow` deve essere già pubblico (non
> `_radunoFromRow`) sul `RaduniRepository` — il subagente Raduni l'ha già
> esposto pubblico in `02-RADUNI.md` § 4. Se non lo è, aprilo come pubblico.

---

## 10. Test manuali

1. **Profilo utente loggato:** mostra avatar (iniziale del nome se senza
   foto), nome, città.
2. **Statistiche:** numeri reali dal DB, non zero hardcoded.
3. **Pull to refresh:** aggiorna nome (se editato altrove) e statistiche.
4. **Tap "I miei raduni":** lista delle iscrizioni.
5. **Tap "Raduni passati":** lista filtrata.
6. **Tap "Esci" → "Annulla":** dialog si chiude, sessione mantenuta.
7. **Tap "Esci" → "Esci":** sessione chiusa, redirect automatico a
   `/onboarding`.
8. **Riapertura app dopo logout:** parte da onboarding, non da home.
9. **Utente senza nome (signup con solo email):** mostra l'email, non crash.

---

## 11. Rischi e mitigazioni

| Rischio | Impatto | Mitigazione |
|---|---|---|
| Statistiche query lenta (join iscrizioni × raduni) | **Basso** | Indice DB su `iscrizioni.utente_uid`. Se >1s, sposta conteggi su funzione SQL aggregata |
| Logout non triggera redirect → utente vede home vuota | **Alto** | Verifica che `GoRouterRefreshStream` di `01-AUTH.md` riceva l'evento `signOut`. Test §10.7 è il check definitivo |
| `currentUserProvider` cachato dopo edit profilo | **Medio** | Sempre `ref.invalidate(currentUserProvider)` dopo update |
| Display number font fallisce → fallback brutto | **Basso** | Su font fallback Material l'aspetto è meno editoriale ma leggibile. Accettabile per MVP. |

---

## 12. Definition of Done

- [ ] `lib/features/profile/application/profile_providers.dart` con `profileStatsProvider`
- [ ] `ProfileScreen` completa con header + stats + lista
- [ ] Logout con confirm dialog funzionante
- [ ] Redirect automatico a `/onboarding` post-logout
- [ ] Pull-to-refresh
- [ ] Empty/loading/error states
- [ ] Statistiche reali da DB
- [ ] Routing `/profile/edit`, `/profile/raduni` aggiunti
- [ ] `MieiRaduniScreen` lista basic implementata
- [ ] Tutti i 9 test manuali §10 passati
- [ ] `cd raduni_app && flutter analyze` pulito
- [ ] `raduni_app/HANDOFF.md` aggiornato (sezione 5.9 da TODO a "✅ FATTA")

Quando completo:

> "Profilo completato. App MVP-ready. **Ultimo passo consigliato:** rimuovere `lib/shared/mock_data.dart` e tutte le sue references. Verificare con `cd raduni_app && flutter analyze` che nessun file le usi più."

---

## 13. Cleanup finale (post-MVP)

Una volta che tutti i 5 subagenti hanno consegnato:

1. **Rimuovi `raduni_app/lib/shared/mock_data.dart`** — non deve esserci nessun import.
2. **Cerca `MockData` in tutto il codice:**
   ```bash
   cd raduni_app
   grep -r "MockData" lib/
   ```
   Deve restituire **zero risultati**.
3. **Aggiorna `raduni_app/README.md`** sezione "Cosa è già fatto" / "Cosa va
   ancora costruito" allo stato reale.
4. **Tag git** dalla root del repo:
   ```bash
   git tag v0.2.0-mvp
   ```
   per marcare la milestone.
