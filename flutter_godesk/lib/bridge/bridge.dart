// Bridge interface — the seam between the UI layer (lib/screens/, lib/kit/)
// and whatever provides identity/peers/session/transfer events.
//
// The UI consumes `BridgeProvider` regardless of whether the underlying
// implementation is `MockBridge` (mock data, used today) or `RealBridge`
// (Phase 2.4: wired through to the Rust core's FFI methods).
//
// All commands return Future<void>; all event streams are broadcast Streams
// so multiple widgets can subscribe (e.g. Home + footer both showing online
// state).

import 'dart:async';

import '../data/peers.dart';
import '../data/transfers.dart';

/// Local-side identity that doesn't change for the lifetime of the install.
class Identity {
  const Identity({required this.id, required this.deviceName});
  final String id;
  final String deviceName;
}

/// Diagnostics line items (the 4 rows on Home → Diagnostics).
class Diagnostics {
  const Diagnostics({
    required this.relay,
    required this.cipher,
    required this.latencyMs,
    required this.natType,
  });
  final String relay;
  final String cipher;
  final int latencyMs;
  final String natType;
}

/// Stage of an in-progress connect attempt — drives the ConnectingOverlay.
enum ConnectStage { resolving, tunnel, authenticating, connected, failed }

class ConnectEvent {
  const ConnectEvent({required this.peer, required this.stage, this.message});
  final Peer peer;
  final ConnectStage stage;
  final String? message;
}

abstract class Bridge {
  // — Identity —
  Future<Identity> identity();
  Future<String> oneTimePassword();
  Future<String> regeneratePassword();

  // — Address book —
  Stream<List<Peer>> peers();
  Future<void> upsertPeer(Peer p);
  Future<void> forgetPeer(String id);

  // — Diagnostics —
  Stream<Diagnostics> diagnostics();

  // — Connect / disconnect —
  Stream<ConnectEvent> connectEvents();
  Future<void> connect(String peerId);
  Future<void> cancelConnect();
  Future<void> disconnect();

  // — Transfers —
  Stream<List<TransferItem>> transfers();
  Future<void> addTransfer({required String filePath, required TransferDir dir});
  Future<void> cancelTransfer(int id);
  Future<void> clearCompleted();

  void dispose();
}
