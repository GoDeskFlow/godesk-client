// MockBridge — current default. Returns the same data the UI was wired to
// during Phase 2.2 (recentPeers, initialQueue, mock diagnostics). Replaces
// inline `data/` imports in screens with a uniform interface so swapping in
// the real Rust-backed bridge in Phase 2.4 is a single-line change.

import 'dart:async';

import '../data/peers.dart';
import '../data/transfers.dart';
import '../util/format.dart';
import 'bridge.dart';

class MockBridge implements Bridge {
  MockBridge() {
    _queue = initialQueue();
    _peers = StreamController<List<Peer>>.broadcast(
      onListen: () => _peers.add(_peersValue),
    );
    _diagnostics = StreamController<Diagnostics>.broadcast(
      onListen: () => _diagnostics.add(_diagnosticsValue),
    );
    _transfers = StreamController<List<TransferItem>>.broadcast(
      onListen: () => _transfers.add(List<TransferItem>.unmodifiable(_queue)),
    );
    _ticker = Timer.periodic(const Duration(milliseconds: 400), (_) => _tick());
  }

  String _password = initialPassword;
  late List<TransferItem> _queue;

  // Last-known snapshots — re-emitted to each new subscriber on attach
  // (broadcast streams otherwise miss late subscribers).
  final List<Peer> _peersValue = List<Peer>.unmodifiable(recentPeers);
  static const Diagnostics _diagnosticsValue = Diagnostics(
    relay: 'eu-west-1',
    cipher: 'AES-256-GCM',
    latencyMs: 12,
    natType: 'Symmetric',
  );

  late final Timer _ticker;
  late final StreamController<List<Peer>> _peers;
  late final StreamController<Diagnostics> _diagnostics;
  final StreamController<ConnectEvent> _connectEvents = StreamController<ConnectEvent>.broadcast();
  late final StreamController<List<TransferItem>> _transfers;

  void _tick() {
    var changed = false;
    for (final i in _queue) {
      if (i.done || i.queued) continue;
      final newSent = (i.sent + (i.speed * 0.4).round()).clamp(0, i.size);
      final isDone = newSent >= i.size;
      if (newSent != i.sent || isDone) {
        i.sent = newSent;
        i.done = isDone;
        i.eta = i.speed > 0 ? ((i.size - newSent) / i.speed).round().clamp(0, 99999) : 0;
        changed = true;
      }
    }
    if (changed) _transfers.add(List<TransferItem>.unmodifiable(_queue));
  }

  @override
  Future<Identity> identity() async => const Identity(id: myId, deviceName: 'My PC');

  @override
  Future<String> oneTimePassword() async => _password;

  @override
  Future<String> regeneratePassword() async => _password = genPassword();

  @override
  Stream<List<Peer>> peers() => _peers.stream;

  @override
  Future<void> upsertPeer(Peer p) async {
    // Mock: no persistence, no-op.
  }

  @override
  Future<void> forgetPeer(String id) async {
    // Mock: no persistence, no-op.
  }

  @override
  Stream<Diagnostics> diagnostics() => _diagnostics.stream;

  @override
  Stream<ConnectEvent> connectEvents() => _connectEvents.stream;

  @override
  Future<void> connect(String peerId) async {
    final peer = recentPeers.firstWhere(
      (p) => p.id == peerId,
      orElse: () => Peer(
        id: peerId,
        name: peerId,
        os: PeerOS.windows,
        tag: 'Manual',
        lastSeen: 'now',
        status: PeerStatus.online,
      ),
    );
    final stages = <(ConnectStage, int)>[
      (ConnectStage.resolving, 700),
      (ConnectStage.tunnel, 1100),
      (ConnectStage.authenticating, 600),
      (ConnectStage.connected, 700),
    ];
    for (final (stage, ms) in stages) {
      await Future<void>.delayed(Duration(milliseconds: ms));
      _connectEvents.add(ConnectEvent(peer: peer, stage: stage));
    }
  }

  @override
  Future<void> cancelConnect() async {
    // Mock: nothing to cancel since `connect` is fire-and-forget here.
  }

  @override
  Future<void> disconnect() async {
    // Mock.
  }

  @override
  Stream<List<TransferItem>> transfers() => _transfers.stream;

  @override
  Future<void> addTransfer({required String filePath, required TransferDir dir}) async {
    _queue.add(TransferItem(
      id: _queue.length + 1,
      name: filePath.split(RegExp(r'[\\/]')).last,
      size: 1024 * 1024,
      sent: 0,
      dir: dir,
      speed: 1024 * 1024,
      eta: 1,
      queued: true,
    ));
    _transfers.add(List<TransferItem>.unmodifiable(_queue));
  }

  @override
  Future<void> cancelTransfer(int id) async {
    _queue.removeWhere((i) => i.id == id && !i.done);
    _transfers.add(List<TransferItem>.unmodifiable(_queue));
  }

  @override
  Future<void> clearCompleted() async {
    _queue.removeWhere((i) => i.done);
    _transfers.add(List<TransferItem>.unmodifiable(_queue));
  }

  @override
  void dispose() {
    _ticker.cancel();
    _peers.close();
    _diagnostics.close();
    _connectEvents.close();
    _transfers.close();
  }
}
