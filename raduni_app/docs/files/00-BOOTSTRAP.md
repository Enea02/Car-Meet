# 00 — BOOTSTRAP

> **Subagente:** Bootstrap & Infrastructure
> **Repository:** `Car-Meet/raduni_app/`
> **Prerequisiti:** Nessuno. È il primo task in assoluto.
> **Output:** App che si compila e parla con Supabase, senza ancora alcuna feature collegata.
> **Stima:** 2-3 ore di lavoro Claude Code

---

## 1. Obiettivo

Preparare l'infrastruttura comune che tutti gli altri subagenti useranno:

1. Aggiungere al `pubspec.yaml` il pacchetto `flutter_dotenv` (Supabase è già
   installato).
2. Creare `.env` con le credenziali Supabase (in `raduni_app/`, **non** nella
   root del repo).
3. Aggiornare `raduni_app/lib/main.dart` per inizializzare Supabase + locale
   italiano. Il `main.dart` corrente ha solo un TODO Firebase commentato.
4. Creare `lib/core/supabase/supabase_client.dart` con provider Riverpod.
5. Creare `lib/core/errors/app_exception.dart` + `lib/core/errors/guard.dart`
   per la gestione errori uniforme.

> ⚠️ **Punto Chiave:** non passare a nessun altro subagente finché questo non
> è completo e l'app si avvia senza errori a runtime.

---

## 2. Pre-condizioni

Verifica che siano vere prima di iniziare:

- [ ] Sei dentro la cartella `raduni_app/` quando lanci `flutter pub get`. Se
      sei nella root `Car-Meet/`, fai `cd raduni_app` prima.
- [ ] L'utente ha fornito `SUPABASE_URL` e `SUPABASE_ANON_KEY`. Se mancano,
      **chiedili prima di procedere**, non improvvisare valori placeholder.
- [ ] Tabelle Supabase create da SQL Editor secondo
      `Car-Meet/01-ARCHITETTURA.md` § 7. Se non sono state create, **fermati**
      e chiedi all'utente di eseguire gli script SQL.
- [ ] `lib/main.dart` corrente contiene il commento `// TODO: inizializza
      Firebase prima di runApp() ...` — se non c'è, qualcuno ha già toccato
      il file: rileggilo e adatta i passi sotto invece di sovrascriverlo
      ciecamente.

Se uno di questi punti è falso, mostra all'utente cosa manca e cosa deve fare
prima di tornare da te.

---

## 3. Step 1 — Aggiungere `flutter_dotenv` al `pubspec.yaml`

Il `pubspec.yaml` di `raduni_app/` ha **già** `supabase_flutter: ^2.5.0`, quindi
non aggiungerlo. **Aggiungi solo `flutter_dotenv`**:

Apri `raduni_app/pubspec.yaml`. Sotto la sezione `dependencies:`, dopo
`cached_network_image`, aggiungi:

```yaml
  # Configurazione runtime
  flutter_dotenv: ^5.1.0
```

E **dichiara `.env` come asset** in fondo al file. La sezione `flutter:`
attuale è praticamente vuota (solo `uses-material-design: true`). Trasformala
in:

```yaml
flutter:
  uses-material-design: true
  assets:
    - .env
```

> ⚠️ **Nota Importante:** se l'utente in futuro aggiungerà cartelle
> `assets/images/` o `assets/icons/`, andranno aggiunte qui. Per ora il `.env`
> è l'unico asset necessario.

Esegui poi:

```bash
cd raduni_app
flutter pub get
```

> ✅ **Beneficio:** `flutter_dotenv` permette di tenere `SUPABASE_URL` e
> `SUPABASE_ANON_KEY` fuori dal repository git, in un `.env` aggiunto a
> `.gitignore`.

---

## 4. Step 2 — File `.env` e `.gitignore`

**Crea `raduni_app/.env`** (NON committare):

```env
SUPABASE_URL=https://xxxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJI...
```

**Crea `raduni_app/.env.example`** (committare):

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

**Aggiorna `raduni_app/.gitignore`** aggiungendo in fondo (in coda alla sezione
"Flutter/Dart/Pub related"):

```gitignore
# ── Env files
.env
.env.local
```

> ⚠️ **Nota Importante:** la `anon_key` è ok nel client perché protetta da RLS.
> La `service_role_key` **non deve mai** apparire nell'app, nemmeno per test.

---

## 5. Step 3 — Aggiornare `raduni_app/lib/main.dart`

Il file corrente è:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle( ... );

  // TODO: inizializza Firebase prima di runApp() quando integri il backend.
  runApp(const ProviderScope(child: RaduniApp()));
}
```

**Sostituiscilo** con:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Carica variabili d'ambiente
  await dotenv.load(fileName: '.env');

  // ── 2. Inizializza Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    debug: false, // a true se vuoi log dettagliati delle query
  );

  // ── 3. Localizzazione italiana per DateFormat
  await initializeDateFormatting('it_IT', null);
  Intl.defaultLocale = 'it_IT';

  // ── 4. Status bar trasparente — coerente col design del prototipo
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFFAFAF7),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: RaduniApp()));
}
```

**Cosa cambia rispetto al file attuale:**

- `void main()` → `Future<void> main()` (necessario per `await dotenv.load`).
- Aggiunti 4 import: `flutter_dotenv`, `intl/date_symbol_data_local`, `intl`,
  `supabase_flutter`.
- Aggiunti 3 `await` di setup prima di `runApp`.
- Rimosso il TODO Firebase (non serve più).
- Mantenuto invariato il blocco `SystemChrome.setSystemUIOverlayStyle` con gli
  stessi colori (è già pixel-perfect).

> ⚠️ **Nota Importante:** `initializeDateFormatting('it_IT', null)` è
> **obbligatorio**. Senza, `DateFormat('d MMM', 'it_IT')` lancia
> `LocaleDataException` la prima volta che `compact_raduno_card.dart` prova a
> renderizzare una card. È il bug più frequente che si dimentica.

---

## 6. Step 4 — `lib/core/supabase/supabase_client.dart`

Crea la cartella e il file:

```bash
mkdir -p raduni_app/lib/core/supabase
```

`raduni_app/lib/core/supabase/supabase_client.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider che espone l'istanza singleton di SupabaseClient.
/// Tutti i repository devono leggere da qui invece di chiamare
/// `Supabase.instance.client` direttamente — questo permette di
/// stubbare il client nei test.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
```

**Pattern d'uso nei repository (per riferimento):**

```dart
// In un repository qualsiasi
final raduniRepositoryProvider = Provider<RaduniRepository>((ref) {
  return RaduniRepository(ref.watch(supabaseClientProvider));
});
```

> ✅ **Beneficio:** disaccoppia i repository dal singleton globale. Per i test
> userai
> `ProviderContainer(overrides: [supabaseClientProvider.overrideWithValue(mockClient)])`.

---

## 7. Step 5 — `lib/core/errors/app_exception.dart` + `guard.dart`

```bash
mkdir -p raduni_app/lib/core/errors
```

`raduni_app/lib/core/errors/app_exception.dart`:

```dart
/// Eccezione di dominio uniforme per tutto il codice dell'app.
/// I repository convertono PostgrestException, AuthException, ecc.
/// in AppException con codice e messaggio leggibile in italiano.
sealed class AppException implements Exception {
  final String message;
  final String? code;
  const AppException(this.message, {this.code});

  @override
  String toString() => 'AppException($code): $message';
}

class NetworkException extends AppException {
  const NetworkException([String message = 'Connessione assente'])
      : super(message, code: 'network');
}

class AuthAppException extends AppException {
  const AuthAppException(super.message, {super.code});
}

class NotFoundException extends AppException {
  const NotFoundException([String message = 'Risorsa non trovata'])
      : super(message, code: 'not_found');
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.code});
}

class UnknownException extends AppException {
  const UnknownException([String message = 'Errore imprevisto'])
      : super(message, code: 'unknown');
}
```

> ⚠️ **Nota Importante:** la classe l'ho chiamata `AuthAppException` invece di
> `AuthException` perché Supabase espone già una sua classe `AuthException` —
> averne due con lo stesso nome porta a conflitti d'import nei repository.

`raduni_app/lib/core/errors/guard.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'app_exception.dart';

/// Wrappa una chiamata Supabase e converte le eccezioni in AppException.
Future<T> guardSupabase<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on sb.PostgrestException catch (e) {
    if (e.code == 'PGRST116') {
      throw const NotFoundException();
    }
    throw UnknownException('Errore database: ${e.message}');
  } on sb.AuthException catch (e) {
    throw AuthAppException(e.message, code: e.statusCode?.toString());
  } catch (e) {
    throw const NetworkException();
  }
}
```

Tutti i repository useranno `guardSupabase`.

---

## 8. Step 6 — Verifica finale

Esegui in ordine, **dentro `raduni_app/`**:

```bash
cd raduni_app
flutter clean
flutter pub get
flutter analyze
flutter run
```

**Aspettative:**

- `flutter analyze` → 0 errori, 0 warning.
- App parte sull'`OnboardingScreen` come prima.
- Nessun crash alla startup.
- In console, **non deve** comparire l'errore `Locale data has not been initialized, call initializeDateFormatting`.

Se uno di questi falla, **non passare** ai subagenti successivi: i bug di
bootstrap sono i più subdoli da debuggare a feature compilate.

---

## 9. Test rapido client Supabase

Per verificare che la connessione funzioni davvero, aggiungi temporaneamente
questo blocco subito dopo `runApp` in `main.dart` (poi rimuovilo):

```dart
// DEBUG ONLY — rimuovi dopo verifica
() async {
  try {
    final res = await Supabase.instance.client
        .from('profiles')
        .select('id')
        .limit(1);
    debugPrint('✅ Supabase OK — risposta: $res');
  } catch (e) {
    debugPrint('❌ Supabase ERRORE: $e');
  }
}();
```

**Risultato atteso:**

- Lista vuota `[]` se la tabella `profiles` esiste ma è vuota → ✅ tutto ok.
- Errore `relation "profiles" does not exist` → l'utente non ha eseguito gli
  script SQL di `01-ARCHITETTURA.md`. **Fermati e dillo.**
- Errore di rete → `.env` sbagliato. Verifica `SUPABASE_URL`.

---

## 10. Definition of Done

- [ ] `flutter_dotenv` aggiunto al `pubspec.yaml`
- [ ] `.env` in `raduni_app/.env` esiste
- [ ] `.env` aggiunto a `.gitignore` di `raduni_app/`
- [ ] `.env.example` creato e committato
- [ ] `lib/main.dart` aggiornato (inizializza Supabase + initializeDateFormatting)
- [ ] `lib/core/supabase/supabase_client.dart` con provider
- [ ] `lib/core/errors/app_exception.dart` con eccezioni di dominio
- [ ] `lib/core/errors/guard.dart` con `guardSupabase`
- [ ] `flutter analyze` pulito
- [ ] App parte senza errori
- [ ] Test rapido query → vede la tabella `profiles`

Quando tutti i checkbox sono spuntati, comunica all'utente:

> "Bootstrap completato. Pronto per il subagente Auth (`claude/01-AUTH.md`)."
