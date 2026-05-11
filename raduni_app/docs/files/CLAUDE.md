# CLAUDE.md — Raduni App

> Documento letto automaticamente da Claude Code all'avvio di ogni sessione nel
> repository **Car-Meet/raduni_app**. Contiene regole, vincoli e mappa dei
> subagenti.
> Versione 2.0 — 10 Maggio 2026

---

## 1. Dove sei

Il repository si chiama **Car-Meet**. La cartella di lavoro Flutter è
**`raduni_app/`** (sottocartella). Tutti i comandi Flutter vanno eseguiti **da
dentro `raduni_app/`**, non dalla root del repo:

```bash
cd raduni_app
flutter pub get
flutter analyze
flutter run
```

I file `claude/0X-*.md` che segui sono **fuori** da `raduni_app/` (in
`Car-Meet/claude/`), così non finiscono nel pacchetto Flutter ma restano
visibili a Claude Code che parte dalla root del repo.

> ⚠️ Quando un file feature dice "modifica `lib/...`" o "crea `lib/...`",
> sottintende sempre **`raduni_app/lib/...`**.

---

## 2. Cosa stai costruendo

App Flutter per appassionati di auto: trovare e creare raduni, gestire un
garage di auto personali, mostrare le proprie auto ai raduni a cui ci si
iscrive.

**Stato attuale del repository (verificato il 10 Maggio 2026):**

- ✅ UI design system completo: `lib/theme/app_colors.dart`, `lib/theme/app_theme.dart`
- ✅ Routing `go_router` con `ShellRoute` (4 tab + FAB centrale): `lib/routing/app_router.dart`
- ✅ Schermate UI complete e pixel-perfect:
  - `OnboardingScreen` (3 step)
  - `LoginScreen`, `SignupScreen`
  - `HomeScreen` (feed con `CompactRadunoCard`, mock data)
  - `AppShell` (bottom nav + FAB Crea)
  - `CompactRadunoCard`
- ✅ Modelli `Raduno` e `Auto` in `lib/shared/models/`
- ✅ `lib/shared/mock_data.dart` con 5 raduni e 2 auto di esempio
- ✅ `pubspec.yaml` con **Supabase già fra le dipendenze** (vedi §3)
- ✅ Permessi Android già configurati in `android/app/src/main/AndroidManifest.xml` (location, camera)
- ⚠️ **Bootstrap NON ancora fatto**: `main.dart` ha il TODO Firebase commentato, Supabase **non è inizializzato a runtime**, manca `.env`, manca `Intl.defaultLocale = 'it_IT'`
- ⚠️ Backend non collegato: tutti i dati arrivano da `MockData`, nessun repository esiste
- ❌ 7 schermate stub (solo `Center(Text('TODO...'))`):
  - `MapScreen`
  - `DetailRadunoScreen`
  - `CreateRadunoScreen`
  - `GarageScreen`
  - `AutoDetailScreen`
  - `AddAutoScreen`
  - `ProfileScreen`

**Documenti di riferimento già esistenti:**

- `Car-Meet/raduni_app/README.md` — quickstart progetto Flutter
- `Car-Meet/raduni_app/HANDOFF.md` — spec funzionale schermata-per-schermata. **Fonte di verità per il design.**
- `Car-Meet/00-SETUP-MACBOOK.md` — installazione Flutter + setup Supabase. **Già eseguito**, non rifare.
- `Car-Meet/01-ARCHITETTURA.md` — decisioni architetturali, modello dati Supabase, RLS, geo-query. **Fonte di verità per il backend.**
- `Car-Meet/02-FASI-IMPLEMENTAZIONE.md` — roadmap a fasi.

> ⚠️ **Punto chiave:** prima di scrivere codice in qualsiasi feature, leggi
> sempre `01-ARCHITETTURA.md` per le tabelle Supabase e `HANDOFF.md` per le
> specifiche UI. Non improvvisare modello dati o layout.

---

## 3. Stack tecnico — vincoli non negoziabili

Il `pubspec.yaml` di `raduni_app/` ha **già** queste dipendenze installate. **NON
modificarle senza chiedere**:

```yaml
dependencies:
  flutter: { sdk: flutter }
  supabase_flutter: ^2.5.0          # backend
  flutter_riverpod: ^2.5.0          # state
  go_router: ^14.0.0                # routing
  flutter_map: ^7.0.0               # mappa
  latlong2: ^0.9.0
  geolocator: ^12.0.0
  permission_handler: ^11.0.0
  image_picker: ^1.0.0
  intl: ^0.19.0
  cached_network_image: ^3.3.0
  cupertino_icons: ^1.0.8

environment:
  sdk: ^3.11.5                      # Dart SDK richiesto
```

| Area | Scelta | Vincolo |
|---|---|---|
| Framework | Flutter ≥ 3.38.4 (vedi `.metadata`) | `pubspec.yaml` già configurato |
| Dart | ^3.11.5 | record & patterns disponibili |
| State | **Riverpod 2.5+** (`flutter_riverpod`) | NO `setState` per dati di dominio. NO `Provider` package. NO BLoC. |
| Routing | **go_router 14** | Tutte le rotte in `lib/routing/app_router.dart` |
| Backend | **Supabase** | Niente Firebase. È già stata presa la decisione architetturale. |
| Mappa | **flutter_map 7** + OpenStreetMap | NO Google Maps |
| Geo | `geolocator` + PostGIS lato server | Funzione `raduni_nearby` già definita in `01-ARCHITETTURA.md` |
| Lingua | **Italiano** (`it_IT`) | Tutta la UI in italiano. `Intl.defaultLocale = 'it_IT'` da settare in `main.dart`. |

### Dipendenze NON installate — chiedere prima di aggiungere

Le seguenti **non** sono nel `pubspec.yaml` corrente, ma alcuni subagenti ne
hanno bisogno. Quando un file feature te le richiede, **aggiungile** al
`pubspec.yaml`, eseguendo `flutter pub get`, e segnalalo nel commit:

| Pacchetto | Chiesto da | Motivo |
|---|---|---|
| `flutter_dotenv: ^5.1.0` | `00-BOOTSTRAP.md` | Caricare `.env` con credenziali Supabase |
| `flutter_map_marker_cluster: ^1.3.6` | `03-MAPPA.md` | Cluster marker su mappa |
| `geocoding: ^3.0.0` | `02-RADUNI.md` (form Crea) | Geocoding inverso da pin → indirizzo |

### Font — verificare lo stato attuale

Il `pubspec.yaml` **non** dichiara `google_fonts`. Prima di scrivere codice che
usa `AppTheme.displayNumber()` con Instrument Serif o `AppTheme.mono()` con
Geist Mono, **leggi prima** `lib/theme/app_theme.dart` e verifica come sono
caricati i font. Se sono fallback Material di sistema, va bene così; se servono
asset font, **chiedi all'utente** prima di aggiungere `google_fonts` al
pubspec.

---

## 4. Struttura cartelle (vincolante)

Tutto sotto `raduni_app/lib/`:

```
lib/
├── main.dart                       # ⚠️ Da aggiornare nel bootstrap
├── app.dart                        # MaterialApp.router con routerProvider
├── theme/                          # ✋ NON TOCCARE — design system completo
│   ├── app_colors.dart
│   └── app_theme.dart
├── routing/
│   └── app_router.dart             # Modifica solo per nuove rotte / redirect auth
├── core/                           # Da creare nel bootstrap
│   ├── supabase/
│   │   └── supabase_client.dart
│   ├── errors/
│   │   ├── app_exception.dart
│   │   └── guard.dart
│   └── location/
│       └── location_service.dart   # Da creare nel subagente Mappa
├── features/
│   ├── auth/
│   │   ├── data/                   # Da creare
│   │   ├── domain/                 # Da creare
│   │   ├── application/            # Da creare
│   │   └── presentation/           # ✋ Schermate UI già fatte
│   │       ├── onboarding_screen.dart
│   │       ├── login_screen.dart
│   │       └── signup_screen.dart
│   ├── home/
│   │   ├── data/                   # Da creare
│   │   ├── application/            # Da creare
│   │   └── presentation/           # ✋ home_screen.dart già fatta
│   ├── map/
│   │   ├── application/            # Da creare
│   │   └── presentation/
│   ├── raduno/
│   │   ├── application/            # Da creare
│   │   └── presentation/
│   ├── garage/
│   │   ├── data/                   # Da creare
│   │   ├── application/            # Da creare
│   │   └── presentation/
│   └── profile/
│       ├── application/            # Da creare
│       └── presentation/
└── shared/
    ├── models/                     # ✋ NON modificare i campi esistenti
    │   ├── raduno.dart
    │   └── auto.dart
    ├── widgets/                    # ✋ NON TOCCARE
    │   ├── app_shell.dart
    │   └── compact_raduno_card.dart
    └── mock_data.dart              # Da rimuovere a fine integrazione
```

> ✋ I file marcati "NON TOCCARE" sono già pixel-perfect col prototipo HTML.
> Modifiche a questi file richiedono approvazione esplicita dell'utente nel
> chat.

### Aggiunte ammesse ai modelli

I modelli `Raduno` e `Auto` esistenti **mancano di alcuni campi** che ti
serviranno (es. `organizzatoreUid` in Raduno, `principale` in Auto, `id` in
Auto se assente). **Puoi aggiungerli** ma:

- Solo **campi nuovi**, mai modificare/rimuovere quelli esistenti.
- Sempre `final` e con valore `nullable` o default sensato (i mock data
  esistenti non li passano, devi non romperli).
- Aggiungi sempre un factory `fromRow(Map<String, dynamic>)` quando aggiungi
  nuovi campi.

---

## 5. Regole di stile e convenzioni

### 5.1 Riverpod

- Provider in fondo al file della feature, non in cartelle separate.
- Usa `Notifier` / `AsyncNotifier` (Riverpod 2.5+), **NO** `StateNotifier`
  legacy.
- Provider che leggono Supabase = `StreamProvider` o `FutureProvider`, mai
  sincroni.
- `keepAlive: true` solo per provider globali (utente loggato, tema). Lista
  raduni → autodispose.

```dart
// ✅ Corretto
final raduniNearbyProvider = StreamProvider.autoDispose<List<Raduno>>((ref) {
  final pos = ref.watch(userPositionProvider);
  return ref.watch(raduniRepositoryProvider).streamNearby(pos);
});

// ❌ Sbagliato — non usiamo StateNotifier
class RaduniNotifier extends StateNotifier<List<Raduno>> { ... }
```

### 5.2 Naming

- File: `snake_case.dart`.
- Classi: `PascalCase`.
- Schermate: terminano sempre con `Screen` (es. `MapScreen`).
- Repository: `XxxRepository` con suffisso, esposti tramite provider
  `xxxRepositoryProvider`.
- Modelli di dominio in italiano (`Raduno`, `Auto`) — coerente col codice
  esistente.

### 5.3 Errori

- Tutto ciò che chiama Supabase è in `try/catch` con conversione a
  `AppException` (vedi `00-BOOTSTRAP.md`).
- La UI mostra errori solo tramite `SnackBar` o stato `AsyncValue.error`.
- Non far mai crashare l'app per un errore di rete: stato vuoto + retry
  button.

### 5.4 Localizzazione

- Stringhe in italiano direttamente nel codice. **NO** ARB / `.l10n` per ora.
- Date sempre formattate con `DateFormat(..., 'it_IT')`.
- Non scrivere mai date inglesi tipo "May 10" — sempre "10 mag".

### 5.5 Vincoli design

Da `HANDOFF.md` § 2 e dal codice esistente in `lib/theme/`:

- Padding contenuto: `EdgeInsets.symmetric(horizontal: 20)` per le schermate principali.
- Card radius: `BorderRadius.circular(16)`.
- Input radius: `BorderRadius.circular(12)`.
- Button radius: `BorderRadius.circular(14)`, height `52`.
- Colori: **solo** quelli in `AppColors`. Mai colori hardcoded.
- Helpers tipografici (`AppTheme.displayNumber()`, `AppTheme.mono()`):
  prima di usarli verifica che esistano in `app_theme.dart` — se hanno nomi
  diversi nel codice reale, usa quelli reali.

---

## 6. Mappa dei subagenti

Quando l'utente chiede di lavorare su una feature, **delega al subagente
corrispondente** caricando il file di feature:

| Feature | File da caricare | Cosa copre |
|---|---|---|
| Bootstrap | `claude/00-BOOTSTRAP.md` | Init Supabase, .env, errori, dipendenze |
| Auth & onboarding | `claude/01-AUTH.md` | Supabase Auth, sessione, integrazione `onboarding_screen` / `login_screen` / `signup_screen` |
| Raduni | `claude/02-RADUNI.md` | `RaduniRepository`, completamento `DetailRadunoScreen` e `CreateRadunoScreen`, integrazione `HomeScreen` reale |
| Mappa | `claude/03-MAPPA.md` | `flutter_map` + cluster + geolocator + bottom sheet preview, completamento `MapScreen` |
| Garage | `claude/04-GARAGE.md` | `AutoRepository`, completamento `GarageScreen` / `AutoDetailScreen` / `AddAutoScreen`, upload foto |
| Profilo | `claude/05-PROFILO.md` | `ProfileScreen`, statistiche, raduni passati, impostazioni, logout |

### Ordine consigliato di lavorazione

1. **`00-BOOTSTRAP.md`** — sempre prima di tutto il resto.
2. **`01-AUTH.md`** — sblocca tutte le altre feature (servono per `auth.uid()` nelle RLS).
3. **`02-RADUNI.md`** — feature core dell'app.
4. **`04-GARAGE.md`** — può andare in parallelo con 03 in due sessioni separate.
5. **`03-MAPPA.md`** — dipende da 02 (riusa `RaduniRepository`).
6. **`05-PROFILO.md`** — chiude l'MVP.

> ⚠️ **Regola di delega:** se un task tocca più feature (es. "iscriversi a un
> raduno" tocca raduni + profilo), il subagente principale è **sempre quello
> della feature dove vive lo stato persistente** (raduni in questo caso). Il
> profilo legge soltanto.

---

## 7. Output attesi e definition of done

Ogni feature è considerata "fatta" solo quando:

- [ ] Compila senza warning (`cd raduni_app && flutter analyze` pulito)
- [ ] Le schermate stub sono state sostituite con UI funzionanti (no più `Center(Text('TODO'))`)
- [ ] I dati arrivano da Supabase, **non** da `MockData`
- [ ] Stati `loading` / `error` / `empty` gestiti esplicitamente nella UI
- [ ] Pull-to-refresh dove c'è una lista
- [ ] Errori di rete non crashano l'app
- [ ] Test manuale con utente loggato + utente sloggato (dove rilevante)
- [ ] Aggiornato `raduni_app/HANDOFF.md` con lo stato della feature (da "STUB" a "✅ FATTA")

**Non considerare fatto:**

- Codice che usa ancora `MockData.raduni` o `MockData.mieAuto`.
- `print()` o `debugPrint()` lasciati nel codice di produzione.
- TODO non tracciati in commenti.
- File `.dart` con più di 400 righe (refactor in widget separati).

---

## 8. Cosa NON fare mai senza chiedere

- Modificare `lib/theme/` (design system).
- Modificare `app_shell.dart` o `compact_raduno_card.dart` (componenti già pixel-perfect).
- Aggiungere dipendenze a `pubspec.yaml` non elencate in §3.
- Migrare a Firebase (è una decisione architetturale chiusa: Supabase).
- Aggiungere ARB / localizzazione multi-lingua (italiano-only per ora).
- Implementare pagamenti (sono fase 6 futura, vedi `02-FASI-IMPLEMENTAZIONE.md`).
- Usare `setState` per dati di dominio (solo per stato locale UI come animazioni / form temporanei).
- Modificare/rimuovere campi dei modelli `Raduno` e `Auto` esistenti
  (aggiungere è ok, vedi §4).
- Modificare il bundle id `com.eneafrontera.raduniApp`.

---

## 9. Comandi utili

**Ricorda: tutti questi comandi vanno lanciati DA DENTRO `raduni_app/`.**

```bash
# Ti sposti nella cartella Flutter (dalla root del repo Car-Meet)
cd raduni_app

# Avvio app (simulatore deve essere già aperto)
flutter run

# Hot reload — premi r nel terminale dopo flutter run
# Hot restart — premi R

# Analisi statica
flutter analyze

# Pulizia se hot reload fa cose strane
flutter clean && flutter pub get

# Esegui un test
flutter test test/path/to/test.dart
```

---

## 10. Riferimenti rapidi

- Spec UI per ogni schermata: `raduni_app/HANDOFF.md` § 5
- Modello dati Supabase (tabelle, RLS, RPC): `Car-Meet/01-ARCHITETTURA.md` § 4-9
- Funzione `raduni_nearby` SQL: `Car-Meet/01-ARCHITETTURA.md` § 8.3
- Stime tempi: `Car-Meet/02-FASI-IMPLEMENTAZIONE.md`
- File HTML pixel-perfect (se presente): `Car-Meet/Raduni.html`

---

## 11. Workflow per ogni nuova sessione

Quando inizi una nuova sessione di lavoro:

1. Leggi questo file (`CLAUDE.md`).
2. Chiedi all'utente quale subagente eseguire (o lui te lo dice direttamente).
3. Leggi il file feature corrispondente (`claude/0X-XXX.md`).
4. **Verifica lo stato attuale** del codice leggendo i `.dart` rilevanti
   (la realtà del repo può essere diversa da quanto dice questo CLAUDE.md se
   qualcun altro ha già lavorato).
5. Solo dopo, proponi un piano di azione e attendi conferma.
