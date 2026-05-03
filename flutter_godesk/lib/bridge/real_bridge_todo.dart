// RealBridge — Phase 2.4 implementation, currently a stub.
//
// This is a deliberate placeholder. The real wiring requires the upstream
// RustDesk Rust crate to be visible from this package and a working FFI
// generator (cargokit or flutter_rust_bridge). Steps that are NOT yet done:
//
// 1. Patch `client/build.py` to accept `--flutter-dir flutter_godesk` so the
//    upstream build pipeline targets our package instead of `flutter/`.
//    See [ADR-011](../../wiki/decisions.md).
//
// 2. Verify upstream's Cargo workspace can be built against
//    `flutter_godesk/` via cargokit. If yes, run their `flutter_rust_bridge`
//    codegen pointed at our package — it generates `bridge_generated.dart`
//    plus the matching `lib.rs` stubs.
//
// 3. Wrap the generated bridge in a `RealBridge` class implementing the
//    `Bridge` interface. Each method calls into the generated FFI:
//
//      Future<Identity> identity() async {
//        final raw = await rustdesk.getMyId();
//        return Identity(id: raw.id, deviceName: raw.deviceName);
//      }
//
// 4. Switch `main.dart` from `MockBridge()` to `RealBridge(client.handle)`
//    behind a `--dart-define=GODESK_REAL_BRIDGE=1` flag during transition.
//
// 5. Remove `MockBridge` once `RealBridge` is stable on Windows + the
//    address book / transfer queue / connect flow all work end-to-end.
//
// Time estimate: 3–5 days of focused FFI work assuming upstream's codegen
// works against our directory layout. Track in roadmap as Phase 2.4.

import '../data/peers.dart';
import '../data/transfers.dart';
import 'bridge.dart';

class RealBridge implements Bridge {
  RealBridge() {
    throw UnimplementedError(
      'RealBridge: Phase 2.4 work pending. See lib/bridge/real_bridge_todo.dart.',
    );
  }

  @override
  Future<Identity> identity() => throw UnimplementedError();

  @override
  Future<String> oneTimePassword() => throw UnimplementedError();

  @override
  Future<String> regeneratePassword() => throw UnimplementedError();

  @override
  Stream<List<Peer>> peers() => throw UnimplementedError();

  @override
  Future<void> upsertPeer(Peer p) => throw UnimplementedError();

  @override
  Future<void> forgetPeer(String id) => throw UnimplementedError();

  @override
  Stream<Diagnostics> diagnostics() => throw UnimplementedError();

  @override
  Stream<ConnectEvent> connectEvents() => throw UnimplementedError();

  @override
  Future<void> connect(String peerId) => throw UnimplementedError();

  @override
  Future<void> cancelConnect() => throw UnimplementedError();

  @override
  Future<void> disconnect() => throw UnimplementedError();

  @override
  Stream<List<TransferItem>> transfers() => throw UnimplementedError();

  @override
  Future<void> addTransfer({required String filePath, required TransferDir dir}) =>
      throw UnimplementedError();

  @override
  Future<void> cancelTransfer(int id) => throw UnimplementedError();

  @override
  Future<void> clearCompleted() => throw UnimplementedError();

  @override
  void dispose() {}
}
