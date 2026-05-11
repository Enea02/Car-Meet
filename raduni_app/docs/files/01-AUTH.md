# 01 — AUTH

> **Subagente:** Autenticazione & Onboarding
> **Repository:** `Car-Meet/raduni_app/`
> **Prerequisiti:** `00-BOOTSTRAP.md` completato.
> **Output:** L'utente può registrarsi, fare login e logout. Sessione persistente.
> **Stima:** 4-6 ore di lavoro Claude Code

---

## 1. Obiettivo

Sostituire i `context.go('/home')` finti negli stub di `LoginScreen` e
`SignupScreen` con vere chiamate Supabase Auth, creare il provider di
sessione, e fare in modo che l'app parta direttamente sulla home se l'utente
è già loggato.

**Schermate coinvolte:**

| File | Stato attuale | Azione |
|---|---|---|
| `lib/features/auth/presentation/onboarding_screen.dart` | ✅ UI fatta | Non toccare |
| `lib/features/auth/presentation/login_screen.dart` | ⚠️ UI fatta, `onPressed` finto | Collegare a `AuthRepository.signIn()` |
| `lib/features/auth/presentation/signup_screen.dart` | ⚠️ UI fatta, `onPressed` finto | Collegare a `AuthRepository.signUp()` |
| `lib/routing/app_router.dart` | ⚠️ Initial location hardcoded a `/onboarding` | Aggiungere redirect basato su sessione |

> ⚠️ **Punto Chiave:** **non riscrivere la UI**. I file `login_screen.dart` e
> `signup_screen.dart` hanno layout pixel-perfect con il prototipo. Devi
> **solo** sostituire la logica dietro i bottoni.

---

## 2. Modello dati di riferimento

Da `Car-Meet/01-ARCHITETTURA.md` § 7:

**Tabella `profiles`** (popolata dal trigger `on_auth_user_created`):

| Campo | Tipo | Note |
|---|---|---|
| `id` | uuid (PK) | Stesso valore di `auth.users.id` |
| `nome` | text | Estratto dal metadata `user_metadata.nome` |
| `email` | text | Estratto da `auth.users.email` |
| `avatar_url` | text? | Null all'inizio |
| `citta` | text? | Null all'inizio |
| `bio` | text? | Null all'inizio |
| `created_at` | timestamp | Auto |

> ✅ **Beneficio:** il trigger Postgres crea la riga `profiles` automaticamente
> al signup. Tu non devi farlo manualmente lato client.

> ⚠️ **Nota su nomenclatura:** il `HANDOFF.md` parla di collection `users`
> (Firestore-style) — è obsoleto. La tabella Supabase si chiama **`profiles`**
> come da `01-ARCHITETTURA.md`.

---

## 3. Architettura della feature

Crea sotto `lib/features/auth/`:

```
features/auth/
├── data/
│   └── auth_repository.dart        # Wrap Supabase Auth
├── domain/
│   └── app_user.dart               # Modello utente di dominio
├── application/
│   └── auth_providers.dart         # authStateProvider, currentUserProvider
└── presentation/
    ├── onboarding_screen.dart      # ✋ Già fatta
    ├── login_screen.dart           # Collega
    └── signup_screen.dart          # Collega
```

```bash
mkdir -p raduni_app/lib/features/auth/data
mkdir -p raduni_app/lib/features/auth/domain
mkdir -p raduni_app/lib/features/auth/application
```

---

## 4. Step 1 — Modello `AppUser`

`raduni_app/lib/features/auth/domain/app_user.dart`:

```dart
class AppUser {
  final String id;
  final String email;
  final String? nome;
  final String? avatarUrl;
  final String? citta;
  final String? bio;

  const AppUser({
    required this.id,
    required this.email,
    this.nome,
    this.avatarUrl,
    this.citta,
    this.bio,
  });

  factory AppUser.fromProfileRow(Map<String, dynamic> row) => AppUser(
        id: row['id'] as String,
        email: row['email'] as String,
        nome: row['nome'] as String?,
        avatarUrl: row['avatar_url'] as String?,
        citta: row['citta'] as String?,
        bio: row['bio'] as String?,
      );

  AppUser copyWith({
    String? nome,
    String? avatarUrl,
    String? citta,
    String? bio,
  }) =>
      AppUser(
        id: id,
        email: email,
        nome: nome ?? this.nome,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        citta: citta ?? this.citta,
        bio: bio ?? this.bio,
      );
}
```

---

## 5. Step 2 — `AuthRepository`

`raduni_app/lib/features/auth/data/auth_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/guard.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/app_user.dart';

class AuthRepository {
  final sb.SupabaseClient _client;
  AuthRepository(this._client);

  /// Stream della sessione corrente. Emette null quando l'utente fa logout.
  Stream<sb.Session?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((event) => event.session);
  }

  sb.Session? get currentSession => _client.auth.currentSession;

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String nome,
  }) {
    return guardSupabase(() async {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'nome': nome},
      );
      if (res.user == null) {
        throw const AuthAppException('Registrazione fallita');
      }
      // Il trigger Postgres ha già creato la riga profiles.
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', res.user!.id)
          .single();
      return AppUser.fromProfileRow(profile);
    });
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) {
    return guardSupabase(() async {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user == null) {
        throw const AuthAppException('Email o password errati');
      }
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', res.user!.id)
          .single();
      return AppUser.fromProfileRow(profile);
    });
  }

  Future<void> signOut() {
    return guardSupabase(() => _client.auth.signOut());
  }

  Future<AppUser?> currentUser() async {
    final session = currentSession;
    if (session == null) return null;
    return guardSupabase(() async {
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', session.user.id)
          .single();
      return AppUser.fromProfileRow(profile);
    });
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});
```

---

## 6. Step 3 — Provider di sessione

`raduni_app/lib/features/auth/application/auth_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

/// Stream della sessione: emette ad ogni cambio (login/logout/refresh token).
final authStateProvider = StreamProvider<sb.Session?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Utente corrente (profile completo). Null se non loggato.
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  // Ricarica quando cambia la sessione
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).currentUser();
});

/// Helper sincrono — true se l'utente è loggato.
final isLoggedInProvider = Provider<bool>((ref) {
  final session = ref.watch(authStateProvider).valueOrNull;
  return session != null;
});
```

---

## 7. Step 4 — Aggiornare `app_router.dart` con redirect

Il file attuale (`raduni_app/lib/routing/app_router.dart`) usa `Provider<GoRouter>`
e ha tutte le rotte. Da modificare in due punti:

1. Importare i provider auth.
2. Aggiungere `redirect` + `refreshListenable`.

**Modifica così:**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/auth/data/auth_repository.dart';

// ... import esistenti delle schermate (NON modificare)

final routerProvider = Provider<GoRouter>((ref) {
  // Ascolta il cambiamento di sessione per rivalutare il redirect
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authRepositoryProvider).authStateChanges(),
    ),
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = ['/onboarding', '/login', '/signup']
          .contains(state.matchedLocation);

      // Loggato e sta per andare su onboarding/login/signup → home
      if (isLoggedIn && isAuthRoute) return '/home';

      // Sloggato e sta cercando una rotta protetta → onboarding
      if (!isLoggedIn && !isAuthRoute) return '/onboarding';

      return null; // Non interferire
    },
    routes: [
      // ... TUTTE le rotte esistenti, INVARIATE
    ],
  );
});

/// Listenable che riemette quando lo Stream di auth produce un evento.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
```

> ⚠️ **Nota Importante:** non rimuovere `initialLocation: '/onboarding'`. Il
> redirect agisce **dopo** il routing iniziale, quindi serve comunque un punto
> di partenza valido.

---

## 8. Step 5 — Collegare `SignupScreen`

Trasforma `SignupScreen` da `StatelessWidget` a `ConsumerStatefulWidget`. La UI
**rimane invariata**, cambiano solo i controller e l'`onPressed` del bottone.

**Pattern da seguire** (nel file `signup_screen.dart`):

```dart
class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nome = _nomeCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (nome.isEmpty || email.isEmpty || password.length < 6) {
      _showError('Compila tutti i campi (password ≥ 6 caratteri)');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signUp(
            email: email,
            password: password,
            nome: nome,
          );
      // Il redirect del router porta automaticamente a /home
    } on AppException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
    );
  }

  // build() — collegare i controller ai TextField, sostituire il finto
  // `() => context.go('/home')` con `_submit`, e mostrare un
  // CircularProgressIndicator dentro il FilledButton quando _loading è true.
}
```

> ✋ **Vincolo:** la UI esistente è già perfetta. Quando colleghi i controller,
> mantieni esattamente gli stessi `TextField`, `FilledButton`, `Spacer`,
> padding e copy. **Nulla** di visivo cambia.

> ⚠️ Se in `app_colors.dart` non esiste un colore `danger`, usa
> `Colors.red.shade700` come fallback senza creare nuove costanti — non
> toccare il design system per questo.

---

## 9. Step 6 — Collegare `LoginScreen`

Stesso pattern di Signup ma con due campi (email + password) e chiamata
`signIn`. Il bottone "Password dimenticata?" può rimanere `onPressed: () {}`
con TODO per ora — è fuori scope.

```dart
Future<void> _submit() async {
  final email = _emailCtrl.text.trim();
  final password = _passwordCtrl.text;

  if (email.isEmpty || password.isEmpty) {
    _showError('Inserisci email e password');
    return;
  }

  setState(() => _loading = true);
  try {
    await ref.read(authRepositoryProvider).signIn(
          email: email,
          password: password,
        );
  } on AppException catch (e) {
    _showError(e.message);
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

---

## 10. Step 7 — Logout (preparare il terreno)

Il logout vivrà nella `ProfileScreen`, che è uno stub. **Non implementarlo
qui** — quel lavoro è del subagente Profilo (`05-PROFILO.md`).

Limita la tua responsabilità a:

- Esporre `signOut()` su `AuthRepository` (già fatto in Step 2).
- Verificare che dopo `signOut()` il redirect del router porti
  automaticamente a `/onboarding`.

Lascia un commento esplicito in cima a `auth_repository.dart`:

```dart
// Logout: l'azione è esposta qui ma chiamata da ProfileScreen
// (vedi claude/05-PROFILO.md).
```

---

## 11. Login con Apple / Google (rimandato)

Lo `OutlinedButton.icon(...Apple)` in `signup_screen.dart` (se presente) rimane
con `onPressed: () {}` per ora. **Non implementare OAuth** — richiede:

- Configurazione Apple Developer + Google Cloud Console
- Capabilities in Xcode (`Sign in with Apple`)
- `.plist` modifiche

È fuori scope del subagente Auth. Lascia un TODO commentato:

```dart
OutlinedButton.icon(
  // TODO(auth): implementare Sign in with Apple — richiede config Apple Dev.
  onPressed: () {},
  icon: const Icon(Icons.apple, color: AppColors.ink),
  label: const Text('Continua con Apple'),
),
```

---

## 12. Test manuali da eseguire

Prima di chiudere il task, verifica con l'app aperta:

1. **Signup happy path:**
   - Compila form, premi "Crea account".
   - Vedi il loader sul bottone.
   - Vai automaticamente a `/home`.
   - In Supabase Dashboard → `Authentication → Users` vedi il nuovo utente.
   - In Supabase Dashboard → Table Editor → `profiles` vedi la riga creata dal
     trigger.

2. **Signup con email duplicata:**
   - Riprova la stessa email.
   - Vedi snackbar rosso con messaggio leggibile (no stack trace).

3. **Login happy path:**
   - Logout (per ora chiudi l'app dopo aver svuotato manualmente la sessione,
     o aggiungi temporaneamente un `IconButton` in `HomeScreen` che chiama
     `signOut`).
   - Login con stesse credenziali.
   - Torna a `/home`.

4. **Login password sbagliata:**
   - Snackbar rosso, no crash.

5. **Persistenza sessione:**
   - Login.
   - Kill totale dell'app (swipe via).
   - Riapri.
   - Deve partire direttamente su `/home`, non su `/onboarding`.

6. **Validazione form:**
   - Submit con campi vuoti → snackbar, nessuna chiamata di rete.

---

## 13. Rischi e mitigazioni

| Rischio | Impatto | Mitigazione |
|---|---|---|
| Trigger `on_auth_user_created` non creato → la `select` su `profiles` post-signup fallisce | **Alto** | In `signUp()` se la `select` lancia `NotFoundException`, fallback: insert manuale in `profiles` e log warning |
| `GoRouterRefreshStream` non riceve eventi → router non aggiorna dopo login | **Medio** | Verifica con `debugPrint` nello `onAuthStateChange` che gli eventi arrivino; controlla che `authRepositoryProvider` sia riusato (non ricreato) |
| Sessione scaduta → utente vede home vuota senza errore | **Medio** | Il `redirect` rifà il check ad ogni navigazione. Se `currentSession` è expired → forza signOut e redirect a `/login` |
| Email confirmation abilitata su Supabase → signup non logga subito | **Basso** | Se attiva, mostra messaggio "Controlla la mail" invece di redirect. Per MVP: disabilita conferma email su Supabase (Auth → Providers → Email → Confirm email = OFF) |

---

## 14. Definition of Done

- [ ] `lib/features/auth/domain/app_user.dart` creato
- [ ] `lib/features/auth/data/auth_repository.dart` creato con metodi `signUp`, `signIn`, `signOut`, `currentUser`, `authStateChanges`
- [ ] `lib/features/auth/application/auth_providers.dart` creato con `authStateProvider`, `currentUserProvider`, `isLoggedInProvider`
- [ ] `lib/routing/app_router.dart` ha `redirect` basato su sessione + `GoRouterRefreshStream`
- [ ] `LoginScreen` e `SignupScreen` sono `ConsumerStatefulWidget` collegati al repository
- [ ] La UI di Login e Signup è rimasta visivamente identica (stessi padding, stessi widget)
- [ ] Loading state sul bottone durante chiamate
- [ ] Errori mostrati con SnackBar rosso
- [ ] Persistenza sessione testata (kill + riavvio)
- [ ] `cd raduni_app && flutter analyze` pulito
- [ ] Tutti i 6 test manuali §12 passati
- [ ] `raduni_app/HANDOFF.md` aggiornato: sezione 5.2 da "Da fare: integrare firebase_auth" a "✅ FATTA con Supabase"

Quando completo, comunica:

> "Auth completato. L'app ora autentica con Supabase. Pronto per il subagente Raduni (`claude/02-RADUNI.md`)."
