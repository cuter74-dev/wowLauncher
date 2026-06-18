# Remote Launcher

A safe remote launcher that runs **only programs pre-registered on the PC** from your mobile device.
There is **no** arbitrary command execution, shell execution, or remote-script execution. The mobile app
can only request a launch by `appId`; the actual executable path and arguments come exclusively from the
PC-side configuration.

```
remote_launcher/
  apps/
    desktop_agent/   # Flutter desktop app (Windows/macOS/Linux) — HTTP API + admin UI
    mobile_app/      # Flutter mobile app (Android/iOS) — QR pairing + app launcher
  packages/
    shared/          # Shared models / API DTOs / utils (pure Dart)
  docs/              # Detailed design docs
  README.md
```

### 📚 Documentation

| Document | Contents |
| --- | --- |
| [`docs/PROJECT.md`](docs/PROJECT.md) | Architecture, data model, API, security, Mermaid diagrams (detailed) |
| [`docs/openapi.yaml`](docs/openapi.yaml) | OpenAPI 3.0 API contract (Swagger UI / codegen) |

## Architecture at a glance

```
[Mobile App] ──HTTP(LAN)──▶ [Desktop Agent (shelf HttpServer)]
   Pair via QR scan              Launches only registered apps via Process.start
   Authenticate with Bearer      Token stored as a hash only / launches are logged
```

- **Network scope:** Same Wi-Fi / LAN. Exposing it to the public internet is not recommended.
- **External access:** If needed, use a VPN such as [Tailscale](https://tailscale.com) to join the same
  private network. This MVP does not implement that directly.

---

## 0. Prerequisites

- Flutter 3.19+ (Dart 3.3+)
- Per-OS toolchain for desktop builds (Visual Studio / Xcode / clang+GTK)

```bash
flutter --version
flutter doctor
```

> **Important:** This repository contains only `lib/`, `pubspec.yaml`, and the shared package.
> The platform runner folders (`android/`, `ios/`, `windows/`, `macos/`, `linux/`) are machine- and
> version-dependent, so you must generate them **once** yourself. Follow the steps below.

---

## 1. Run the Desktop Agent

```bash
cd remote_launcher/apps/desktop_agent

# 1) Generate the platform runner folders for the current OS (lib/ and pubspec.yaml are preserved)
flutter create . --platforms=windows,macos,linux

# 2) Install dependencies
flutter pub get

# 3) Run (on the current desktop OS)
flutter run -d windows   # or -d macos / -d linux
```

Once running, the Status tab shows the PC name / port (default 8765) / LAN IP list / pairing QR.

### macOS permissions (network / file access)

Add the following to the two entitlement files created by `flutter create`.
`macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:

```xml
<!-- Bind a LAN server / accept mobile connections -->
<key>com.apple.security.network.server</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<!-- Access user-selected executables/icons -->
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

> To launch executables from arbitrary locations, the simplest approach is to build the desktop app with
> **the sandbox disabled** (for development / personal use). The two `<key>...network...</key>` entries
> above are required for the LAN server.

### Linux

No extra permission setup is usually required. `libsqlite3` must be present for SQLite FFI:

```bash
sudo apt-get install libsqlite3-0    # Debian/Ubuntu family
```

### Windows

No special permission setup is required. On first run, if the firewall asks to allow LAN access, choose **Allow**.

---

## 2. Run the Mobile App

```bash
cd remote_launcher/apps/mobile_app

# 1) Generate the mobile platform runner folders
flutter create . --platforms=android,ios

# 2) Install dependencies
flutter pub get

# 3) Run on a real device (a camera is required, so a real device is preferred over an emulator)
flutter run
```

### Android permissions

Inside `<manifest>` in `android/app/src/main/AndroidManifest.xml`, above `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

> If cleartext HTTP (LAN) calls are blocked on some Android 9+ devices, add
> `android:usesCleartextTraffic="true"` to the `<application>` tag (development / private network only).

### iOS permissions

Add to `ios/Runner/Info.plist`:

```xml
<!-- Camera for QR scanning -->
<key>NSCameraUsageDescription</key>
<string>The camera is used to scan the PC pairing QR code.</string>
<!-- Local network permission to reach the PC on the same Wi-Fi -->
<key>NSLocalNetworkUsageDescription</key>
<string>Connects to a PC on the same Wi-Fi to launch registered apps.</string>
```

---

## 3. Usage flow

1. Launch the **Desktop Agent** → register programs in the **Apps** tab (name / executable / args / icon, etc.).
2. Scan the QR code in the **Status** tab from mobile (**Add PC**).
3. When the **"New device connection request"** banner appears on the desktop, **approve** it.
4. The PC is added on mobile; selecting it shows the registered apps as an **icon grid**.
5. Tapping an icon launches the program on that PC and records it in the desktop **Logs** tab.

---

## 4. HTTP API summary

| Method | Path | Auth | Description |
| ------ | ---- | ---- | ---- |
| GET  | `/api/health` | - | Status / name / platform |
| POST | `/api/pair/request` | Pairing code | Create a pairing request |
| GET  | `/api/pair/status/{requestId}` | - | Poll approval status (accessToken on approval) |
| GET  | `/api/apps` | Bearer | List enabled apps (icons as base64) |
| POST | `/api/apps/{id}/launch` | Bearer | Launch a registered app |

---

## 5. Security design

- Mobile requests launches only by `appId`. The executable / args / working directory all come **solely from the PC DB**.
- `Process.start(..., runInShell: false)` — no shell is involved, so there is no command-injection surface.
- The access token is stored on the PC **only as a SHA-256 hash** (the plaintext lives only on mobile).
- Pairing codes are **single-use** and automatically rotated after approval.
- Every launch is logged as **who / what / when / success**.
- CORS is not enabled (this is not a browser API).
- Non-existent paths / working directories are checked before launch and return a **clear error**.
- ⚠️ **Do not expose the port to the public internet.** Use a VPN / Tailscale for external access.

---

## 6. Development notes

```bash
# Analyze + test the shared package
cd packages/shared && dart pub get && dart analyze && dart test

# Analyze each app (after pub get)
cd apps/desktop_agent && flutter pub get && dart fix --apply && flutter analyze
cd apps/mobile_app   && flutter pub get && dart fix --apply && flutter analyze
```

> `dart fix --apply` automatically applies the style-oriented recommendations from `flutter_lints`
> (e.g. `prefer_const_constructors`). The code itself keeps working as-is.

- State management: Riverpod (`AsyncNotifier`-based CRUD)
- Storage: SQLite (desktop = `sqflite_common_ffi`, mobile = `sqflite`)
- Server: `shelf` + `shelf_router`
- QR: desktop = `qr_flutter`, mobile = `mobile_scanner`
