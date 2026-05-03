# RealBridge codegen runbook

Phase 2.4 final step: generate Dart FFI bindings from upstream
`client/src/flutter_ffi.rs` and wire them into `RealBridge`.

## Prerequisites

1. Rust core builds — i.e. `cargo build --release` succeeds in `client/`.
   That means `vcpkg` is installed and bootstrapped, and all native deps
   (libvpx, libyuv, libopus, libaom, libsodium) are compiled. ~1.5h cold
   build the first time. See `client/build.py --help`.

   **Important**: clone vcpkg with **full history** (do NOT use
   `git clone --depth 1`). vcpkg uses git history to resolve baseline
   versions, and shallow clones break with `failed to git show
   versions/baseline.json`. Use:

   ```
   git clone https://github.com/microsoft/vcpkg.git client/vcpkg
   client/vcpkg/bootstrap-vcpkg.bat -disableMetrics
   $env:VCPKG_ROOT = "D:\Vibecoding\GoDesk\client\vcpkg"
   .\vcpkg.exe install libvpx:x64-windows-static libyuv:x64-windows-static `
                       opus:x64-windows-static aom:x64-windows-static
   ```
2. `flutter_rust_bridge_codegen` v1.80.1 installed:
   ```
   cargo install flutter_rust_bridge_codegen --version 1.80.1
   ```
3. Our package's `pubspec.yaml` already has matching deps:
   ```
   ffi: ^2.1.0
   flutter_rust_bridge: 1.80.1
   ffigen: ^8.0.2
   ```

## Generate the bindings

From the `client/` directory:

```bash
flutter_rust_bridge_codegen \
  --rust-input ./src/flutter_ffi.rs \
  --dart-output ./flutter_godesk/lib/bridge/generated_bridge.dart \
  --c-output ./flutter_godesk/macos/Runner/bridge_generated.h
```

The generator emits:
- `flutter_godesk/lib/bridge/generated_bridge.dart` — the Dart-side FFI surface
- `flutter_godesk/lib/bridge/bridge_generated.io.dart` — IO impl
- `flutter_godesk/lib/bridge/bridge_generated.web.dart` — web stubs
- A header file (used by macOS/iOS builds).

## Wire into the app

After generation, replace the `MockBridge()` line in `lib/main.dart` with:

```dart
import 'bridge/real_bridge.dart';
// ...
final bridge = RealBridge();
runApp(GoDeskApp(controller: controller, bridge: bridge));
```

And implement `RealBridge` (currently a stub at `real_bridge_todo.dart`)
calling the methods exposed by `generated_bridge.dart`. Method names mirror
the upstream `flutter_ffi.rs` exports: `getMyId`, `getPeers`, `connect`,
etc. The mapping of generated method → our Bridge interface is mechanical;
each method is one line.

## Fallback if upstream codegen does not work against our package

If `flutter_rust_bridge_codegen` refuses our directory layout, the
escape hatch is to **let the upstream `client/flutter/` build run normally,
generate `generated_bridge.dart` there, then symlink or copy** the file:

```bash
cp client/flutter/lib/generated_bridge.dart \
   client/flutter_godesk/lib/bridge/generated_bridge.dart
```

The generated file has no awareness of the package directory it ends up in,
so this works as long as the `flutter_rust_bridge` runtime version matches
on both sides.

## Smoke test after wiring

```bash
cd client/flutter_godesk
flutter run -d windows
```

Expected:
- App boots — same UI as MockBridge.
- Home screen shows a real ID from the Rust core (instead of mock `742 819 365`).
- Address book is initially empty (or whatever upstream stores in its peer DB).
- Connect to a peer ID actually attempts a network handshake against
  `id.godeskflow.com:21115`.

If any of these fail with type mismatches between `Bridge` interface and
`generated_bridge.dart`, adapt `Bridge` (in `lib/bridge/bridge.dart`) to
match. The interface is ours and is allowed to evolve.

## Estimate

3–5 days focused work for one engineer:
- 0.5 day: vcpkg bootstrap + first successful `cargo build --release`
- 0.5 day: codegen runs cleanly, file shows up
- 1–2 days: wire RealBridge methods, debug type mismatches
- 1–2 days: real-world sessions (Home → Address Book → Connect → Session
  → Disconnect) on an actual remote machine through our hbbs/hbbr.
