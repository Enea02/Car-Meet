# RADUNI APP — SETUP MACBOOK PRO

**Documento:** 00 di 03 — Setup ambiente di sviluppo
**Versione:** 1.0
**Data:** 7 Maggio 2026
**Target:** Sviluppatore senza Flutter installato sulla macchina

> **Obiettivo:** Avere un MacBook Pro pronto a compilare e fare girare l'app Raduni su simulatore iOS, emulatore Android e dispositivo fisico, con `flutter doctor` completamente verde.

---

## Indice

1. Prerequisiti macOS
2. Installazione Flutter SDK
3. Toolchain iOS (Xcode + CocoaPods)
4. Toolchain Android (Android Studio + SDK)
5. Editor consigliato (VS Code)
6. Verifica finale `flutter doctor`
7. Setup progetto Supabase
8. Bootstrap del progetto Flutter
9. Troubleshooting comuni

---

## 1. Prerequisiti macOS

Verifica versione macOS (serve macOS 13 Ventura o successivo per Xcode 15+):

```bash
sw_vers
```

Installa **Homebrew** se non l'hai già fatto (è il package manager standard su Mac):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

A fine installazione segui le istruzioni che ti stampa per aggiungere Brew al `PATH` (dipende se hai Mac Intel o Apple Silicon — il comando è diverso e te lo dice lui stesso).

Verifica:

```bash
brew --version
```

Installa utility di base utili:

```bash
brew install git
brew install --cask warp   # terminale opzionale ma comodo
```

---

## 2. Installazione Flutter SDK

Su macOS la via consigliata è installare via **fvm** (Flutter Version Manager) anziché scaricare manualmente lo zip. Permette di gestire più versioni di Flutter sullo stesso Mac, utile per progetti diversi.

```bash
brew tap leoafarias/fvm
brew install fvm
```

Installa l'ultima stable di Flutter:

```bash
fvm install stable
fvm global stable
```

Aggiungi fvm al `PATH`. Apri il file `~/.zshrc` (Mac usa zsh di default):

```bash
nano ~/.zshrc
```

Aggiungi in fondo:

```bash
export PATH="$PATH:$HOME/fvm/default/bin"
```

Salva (`Ctrl+O`, `Enter`, `Ctrl+X`) e ricarica:

```bash
source ~/.zshrc
```

Verifica:

```bash
flutter --version
```

> ⚠️ **Nota Importante:** se non vuoi usare fvm puoi scaricare Flutter manualmente da [flutter.dev](https://flutter.dev), ma su questa macchina, dato che parti da zero e potresti avere altri progetti in futuro, **fvm ti farà risparmiare ore** quando dovrai cambiare versione.

---

## 3. Toolchain iOS

### 3.1 Xcode

Installa Xcode dal **Mac App Store** (è grande, ~10GB, mettiti comodo).

A installazione completata, **apri Xcode almeno una volta** per accettare la license e far installare i componenti aggiuntivi. Poi da terminale:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept
```

### 3.2 CocoaPods

CocoaPods è il package manager per le dipendenze native iOS. Flutter lo usa sotto il cofano.

```bash
sudo gem install cocoapods
```

Se sei su **Apple Silicon (M1/M2/M3/M4)** e ricevi errori di permessi sulla gem, l'alternativa pulita è:

```bash
brew install cocoapods
```

Verifica:

```bash
pod --version
```

### 3.3 Simulatore iOS

Apri Xcode → **Settings → Platforms** → installa l'ultimo simulatore iOS (è separato dal pacchetto Xcode base).

Test rapido del simulatore:

```bash
open -a Simulator
```

---

## 4. Toolchain Android

### 4.1 Android Studio

```bash
brew install --cask android-studio
```

Apri Android Studio, completa il setup wizard (lascia tutto di default), che installerà:

- Android SDK
- Android SDK Platform-Tools
- Android SDK Build-Tools
- Un emulatore base

### 4.2 Accetta le licenze Android

```bash
flutter doctor --android-licenses
```

Premi `y` a tutte le domande.

### 4.3 Crea un emulatore Android

In Android Studio: **More Actions → Virtual Device Manager → Create Device**. Scegli un Pixel 7 con immagine API 34 (Android 14).

---

## 5. Editor consigliato — VS Code

```bash
brew install --cask visual-studio-code
```

Estensioni da installare (da terminale è più rapido):

```bash
code --install-extension Dart-Code.flutter
code --install-extension Dart-Code.dart-code
code --install-extension usernamehw.errorlens
```

> ✅ **Beneficio:** VS Code con l'estensione Flutter ti dà hot reload con `Cmd+S`, debugger integrato e completion potente. Android Studio resta valido se ti trovi meglio con un IDE full-featured.

---

## 6. Verifica finale

Esegui:

```bash
flutter doctor -v
```

**Devi vedere tutto ✓ verde su:**

- Flutter SDK
- Android toolchain
- Xcode
- Chrome (opzionale, per dev web)
- Android Studio
- VS Code
- Connected device (almeno il simulatore iOS o un device USB)

Se qualche voce è in rosso, vai alla sezione **9. Troubleshooting**.

---

## 7. Setup progetto Supabase

Per la app servirà un backend. La scelta motivata è documentata nel file `01-ARCHITETTURA.md`. Qui solo i passi operativi.

### 7.1 Crea account e progetto

1. Vai su [supabase.com](https://supabase.com), iscriviti (puoi usare GitHub).
2. **New Project** → nome `raduni-app`, password DB robusta (salvala in 1Password o simile), region `eu-central-1` (Frankfurt) per latenza bassa dall'Italia.
3. Aspetta ~2 minuti che il progetto si crei.

### 7.2 Abilita PostGIS

Questo è **fondamentale** per la mappa "raduni vicini". Senza PostGIS dovresti calcolare distanze a mano in Dart, lentissimo.

Nel pannello Supabase: **Database → Extensions** → cerca `postgis` → **Enable**.

### 7.3 Recupera le credenziali

**Project Settings → API**, segna in un posto sicuro:

- `Project URL` (es. `https://xxxxx.supabase.co`)
- `anon public key` (è la chiave che useremo nell'app, ha permessi limitati via Row Level Security)

> ⚠️ **Nota Importante:** la `service_role key` **non va MAI nell'app** — solo lato server. La `anon key` è ok perché protetta da Row Level Security che configureremo nel file 01.

---

## 8. Bootstrap progetto Flutter

Dal terminale, posizionati dove vuoi tenere il progetto (es. `~/Developer`):

```bash
mkdir -p ~/Developer && cd ~/Developer
flutter create --org com.tuodominio raduni_app
cd raduni_app
```

> Sostituisci `com.tuodominio` con il tuo bundle id (es. `com.mariorossi`). Cambiarlo dopo è una rottura, fallo bene ora.

### 8.1 Pacchetti iniziali

Apri `pubspec.yaml` e aggiungi sotto `dependencies:`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Backend
  supabase_flutter: ^2.5.0

  # State management
  flutter_riverpod: ^2.5.0

  # Routing
  go_router: ^14.0.0

  # Mappa
  flutter_map: ^7.0.0
  latlong2: ^0.9.0
  geolocator: ^12.0.0

  # Permessi
  permission_handler: ^11.0.0

  # Image picker per foto auto/raduni
  image_picker: ^1.0.0

  # Utility
  intl: ^0.19.0
  cached_network_image: ^3.3.0
```

Esegui:

```bash
flutter pub get
```

### 8.2 Configurazione iOS (Info.plist)

Apri `ios/Runner/Info.plist` e aggiungi prima di `</dict>` finale:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Serve a mostrarti i raduni nelle vicinanze sulla mappa.</string>
<key>NSCameraUsageDescription</key>
<string>Serve a fotografare la tua auto per esporla al raduno.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Serve a scegliere foto della tua auto dalla galleria.</string>
```

### 8.3 Configurazione Android

Apri `android/app/src/main/AndroidManifest.xml` e aggiungi prima di `<application`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

Apri `android/app/build.gradle` e verifica/aggiorna `minSdkVersion`:

```gradle
defaultConfig {
    minSdkVersion 21   // geolocator richiede minimo 21
}
```

### 8.4 Test "Hello world"

```bash
flutter run
```

Se sei su simulatore iOS o emulatore Android, deve partire la app demo Flutter di base. Se la vedi: **setup completato**.

---

## 9. Troubleshooting comuni

### `CocoaPods could not find compatible versions`

```bash
cd ios
pod repo update
pod install
cd ..
```

### `Unable to find Flutter SDK`

Hai dimenticato di fare `source ~/.zshrc` dopo aver modificato il file. Chiudi e riapri il terminale.

### Apple Silicon: `Bad CPU type in executable`

Stai eseguendo un binario x86_64 senza Rosetta. Installa Rosetta:

```bash
softwareupdate --install-rosetta --agree-to-license
```

### `flutter doctor` lamenta cmdline-tools

Apri Android Studio → **Settings → Languages & Frameworks → Android SDK → SDK Tools** → spunta `Android SDK Command-line Tools (latest)` → **Apply**.

### Simulatore iOS lentissimo

Assicurati di non avere Docker Desktop o altri container in esecuzione: rubano risorse. Chiudi Chrome con 50 tab aperte (sì, capita).

---

## Stima Tempi Setup

| Attività | Tempo |
|---|---|
| Homebrew + utility base | 15-20 min |
| Flutter SDK via fvm | 10 min |
| Xcode (download + first launch) | 60-90 min (download lungo) |
| CocoaPods + simulatore iOS | 15 min |
| Android Studio + SDK + emulatore | 45-60 min |
| VS Code + estensioni | 5 min |
| Account Supabase + PostGIS | 10 min |
| Bootstrap progetto + dipendenze | 15 min |
| **Totale** | **3-4 ore** (gran parte sono download in background) |

---

**Prossimo documento:** `01-ARCHITETTURA.md` — architettura applicativa, modello dati, struttura cartelle.
