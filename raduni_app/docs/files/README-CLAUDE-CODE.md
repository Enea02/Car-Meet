# Claude Code — istruzioni d'uso

Questi 7 file (`CLAUDE.md` + 6 file numerati) servono a far lavorare **Claude
Code** sull'app **Raduni** (repository `Car-Meet`, cartella Flutter
`raduni_app/`) con un sistema di subagenti, dove ogni subagente è
specializzato su una feature.

---

## Come si usano

### 1. Posiziona i file nel repo

Nella root del repository **Car-Meet** (NON dentro `raduni_app/`):

```
Car-Meet/
├── CLAUDE.md                  ← qui (root del repo, non raduni_app/)
├── 00-SETUP-MACBOOK.md        ← già esistenti
├── 01-ARCHITETTURA.md
├── 02-FASI-IMPLEMENTAZIONE.md
├── claude/                    ← cartella nuova
│   ├── 00-BOOTSTRAP.md
│   ├── 01-AUTH.md
│   ├── 02-RADUNI.md
│   ├── 03-MAPPA.md
│   ├── 04-GARAGE.md
│   └── 05-PROFILO.md
└── raduni_app/                ← cartella Flutter (codice)
    ├── pubspec.yaml
    ├── lib/
    ├── ios/
    ├── android/
    ├── README.md
    └── HANDOFF.md
```

`CLAUDE.md` deve stare in **root del repo** (non dentro `raduni_app/`):
Claude Code legge automaticamente il `CLAUDE.md` più vicino al punto in cui è
stato lanciato. Lanciandolo dalla root di Car-Meet, vede sia il `CLAUDE.md`
sia la cartella `raduni_app/` come sotto-directory di lavoro.

> ⚠️ **Perché non dentro `raduni_app/`:** se metti `CLAUDE.md` dentro la
> cartella Flutter, finisce nel pacchetto pubblicato e nei log di build. Non
> è un disastro, ma è più pulito tenerlo fuori.

### 2. Avvia Claude Code dalla root del repo

```bash
cd ~/Documents/GitHub/Car-Meet
claude
```

Claude Code carica subito `CLAUDE.md` e da lì conosce stack, regole, mappa
dei subagenti, e soprattutto il fatto che il codice Flutter sta in
`raduni_app/`.

### 3. Per ogni feature, lancia il subagente

In Claude Code scrivi:

```
Lavora sul subagente Auth. Leggi claude/01-AUTH.md e seguilo.
```

Oppure più diretto:

```
Esegui claude/01-AUTH.md.
```

Claude Code legge il file, propone un piano, e attende conferma prima di
scrivere codice (è il comportamento richiesto in `CLAUDE.md` § 11).

### 4. Ordine consigliato

1. `00-BOOTSTRAP.md` — sempre per primo, sblocca il resto.
2. `01-AUTH.md` — sblocca tutte le RLS Supabase.
3. `02-RADUNI.md` — feature core.
4. `03-MAPPA.md` e `04-GARAGE.md` — possono andare in **parallelo** in due sessioni Claude Code separate.
5. `05-PROFILO.md` — chiude l'MVP.

---

## Cosa fa ogni file

| File | Cosa contiene | Quando leggerlo |
|---|---|---|
| `CLAUDE.md` | Regole comuni: stack, struttura cartelle (con `raduni_app/` come root Flutter), convenzioni Riverpod, vincoli design, mappa subagenti | Auto-letto da Claude Code ogni sessione |
| `00-BOOTSTRAP.md` | Aggiungere `flutter_dotenv`, creare `.env`, sostituire il TODO Firebase di `main.dart` con init Supabase + locale italiano, creare `core/supabase/` e `core/errors/` | Una volta sola, primo task |
| `01-AUTH.md` | Auth repository, provider sessione, redirect router, integrazione signup/login screens esistenti | Subito dopo bootstrap |
| `02-RADUNI.md` | RaduniRepository, home con dati reali, DetailRadunoScreen, CreateRadunoScreen, iscrizioni | Core dell'app |
| `03-MAPPA.md` | flutter_map + cluster + geolocator + bottom sheet preview | Dopo Raduni (riusa il repository) |
| `04-GARAGE.md` | AutoRepository, GarageScreen, AutoDetailScreen, AddAutoScreen | In parallelo a Mappa |
| `05-PROFILO.md` | ProfileScreen, statistiche, logout, MieiRaduniScreen | Ultimo |

---

## Cosa **non** fanno questi file

- ❌ Non istruiscono Claude Code a modificare il design system (`raduni_app/lib/theme/`).
- ❌ Non gli dicono di cambiare i widget pixel-perfect già fatti
  (`AppShell`, `CompactRadunoCard`, `HomeScreen`).
- ❌ Non rimuovono Firebase da `pubspec.yaml`: il `pubspec.yaml` di
  `raduni_app/` **ha già** Supabase e **non ha mai avuto** Firebase. Il
  `pubspec.yaml` con Firebase che vedi nel repo è un file vecchio nella root
  di Car-Meet, non quello in uso.
- ❌ Non implementano pagamenti, OAuth Apple/Google, push notifications
  (fasi successive in `02-FASI-IMPLEMENTAZIONE.md`).
- ❌ Non fanno setup Supabase lato dashboard (tabelle, trigger, RLS) — quello
  sta in `01-ARCHITETTURA.md` ed è responsabilità tua eseguirlo da SQL Editor
  **prima** di lanciare i subagenti.

---

## Pre-condizioni assolute

Prima di lanciare il primo subagente, verifica:

- [ ] Hai eseguito `00-SETUP-MACBOOK.md` — Flutter installato, `flutter
      doctor` verde, `cd raduni_app && flutter pub get` completato.
- [ ] Hai eseguito tutti gli script SQL di `01-ARCHITETTURA.md` su Supabase
      (tabelle `profiles`, `raduni`, `auto`, `iscrizioni` + funzione
      `raduni_nearby` + RLS + trigger `on_auth_user_created`).
- [ ] Hai a portata di mano `SUPABASE_URL` e `SUPABASE_ANON_KEY`.
- [ ] Hai un simulatore iOS o emulatore Android pronto a partire.

Se uno di questi punti è falso, il primo subagente si bloccherà quasi subito.
Sistemali ora.

---

## Cose da sapere su questo specifico repo

Tre dettagli da tenere a mente quando interpreti i `.md`:

1. **Cartella di lavoro Flutter = `raduni_app/`.** I file `.md` dicono
   "modifica `lib/...`" intendendo sempre `raduni_app/lib/...`. Tutti i
   comandi `flutter ...` vanno lanciati con `cd raduni_app` davanti.

2. **Bundle id reale = `com.eneafrontera.raduniApp`.** Va usato come
   `userAgentPackageName` nel TileLayer di flutter_map (vedi `03-MAPPA.md`).
   Non cambiare il bundle id nemmeno se ti vien detto di farlo da source
   esterne.

3. **Stato attuale del `pubspec.yaml` di `raduni_app/`** — già installati:
   `supabase_flutter`, `flutter_riverpod`, `go_router`, `flutter_map`,
   `latlong2`, `geolocator`, `permission_handler`, `image_picker`, `intl`,
   `cached_network_image`. **Da aggiungere** quando i subagenti li chiedono:
   `flutter_dotenv` (00-BOOTSTRAP), `geocoding` (02-RADUNI),
   `flutter_map_marker_cluster` (03-MAPPA). **Non è installato** `google_fonts`
   — se vedi codice che usa `AppTheme.displayNumber()` o `AppTheme.mono()`,
   verifica prima `lib/theme/app_theme.dart` per capire come sono caricati i
   font (potrebbero essere fallback di sistema).

---

## Quando un subagente sbaglia

Se Claude Code:

- **Modifica file marcati "✋ NON TOCCARE"** in `CLAUDE.md` § 4 → fermalo,
  fagli rileggere `CLAUDE.md`.
- **Aggiunge dipendenze non elencate** → fermalo, chiedi giustificazione,
  eventualmente aggiorna `CLAUDE.md` § 3.
- **Improvvisa schema DB diverso** da `01-ARCHITETTURA.md` → fermalo,
  ridagli il documento.
- **Lascia `MockData` nella schermata che doveva integrare** → non
  considerare il task completo. La definition of done è esplicita in ogni
  file.
- **Lavora dalla root del repo invece che da `raduni_app/`** → `flutter pub
  get` fallisce con "no pubspec.yaml". Fagli notare di fare `cd raduni_app`.

Il principio: Claude Code segue i `.md` solo se glieli ricordi. Quando
deraglia, *cita il vincolo specifico violato*, non un generico "non
funziona".

---

## Ultimo step (manuale, post-MVP)

Quando tutti i 5 subagenti hanno consegnato e l'app gira con dati Supabase,
fai:

```bash
cd raduni_app

# Verifica zero residui di MockData
grep -r "MockData" lib/

# Se output vuoto:
rm lib/shared/mock_data.dart
flutter analyze

# Tag git dalla root del repo
cd ..
git tag v0.2.0-mvp
```

Buon lavoro.
