// MockBridge — placeholder Bridge while Phase 2.4 RealBridge is unfinished.
//
// Two modes, switched by the compile-time flag GODESK_DEMO:
//
//   GODESK_DEMO=false (default, what installer ships)
//     ▸ Empty address book
//     ▸ Empty transfer queue
//     ▸ ID is generated client-side (random 9-digit)
//     ▸ Diagnostics show "—" / "no session" placeholders
//     ▸ Connect always reports `failed` after 1.5s (no Rust core yet)
//   This is what a first-run user sees — looks like the real app
//   pre-RealBridge instead of a fake demo.
//
//   GODESK_DEMO=true
//     ▸ The 6 mock peers, 5 mock transfers, and the eu-west-1
//       diagnostics from data/peers.dart + data/transfers.dart.
//     ▸ Used for screenshots, README, and sales demos. Build with:
//         flutter build windows --release --dart-define=GODESK_DEMO=true

import 'dart:async';
import 'dart:math';

import '../data/peers.dart';
import '../data/transfers.dart';
import '../util/format.dart';
import 'bridge.dart';

const bool _demoMode = bool.fromEnvironment('GODESK_DEMO', defaultValue: false);

class MockBridge implements Bridge {
  MockBridge() {
    _queue = _demoMode ? initialQueue() : <TransferItem>[];
    _peers = StreamController<List<Peer>>.broadcast(
      onListen: () => _peers.add(_peersSnapshot),
    );
    _diagnostics = StreamController<Diagnostics>.broadcast(
      onListen: () => _diagnostics.add(_diagnosticsSnapshot),
    );
    _transfers = StreamController<List<TransferItem>>.broadcast(
      onListen: () => _transfers.add(List<TransferItem>.unmodifiable(_queue)),
    );
    if (_demoMode) {
      _ticker = Timer.periodic(const Duration(milliseconds: 400), (_) => _tick());
    }
  }

  // Local-only ID, persisted in shared_preferences IF/when we wire it.
  // For empty mode we just generate a random one per launch — RealBridge
  // will later replace this with the actual RustDesk-managed ID.
  late final String _myId = _demoMode ? myId : _generateLocalId();
  late String _password = _demoMode ? initialPassword : genPassword();
  late List<TransferItem> _queue;

  static String _generateLocalId() {
    final r = Random();
    final n = List<int>.generate(9, (_) => r.nextInt(10)).join();
    return '${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6, 9)}';
  }

  /// Address book contents — empty by default, demo seed when GODESK_DEMO=true.
  List<Peer> get _peersSnapshot =>
      _demoMode ? List<Peer>.unmodifiable(recentPeers) : const <Peer>[];

  /// Diagnostics — when there's no active session in real life, latency and
  /// NAT are unknown. Empty mode reflects that honestly.
  Diagnostics get _diagnosticsSnapshot => _demoMode
      ? const Diagnostics(
          relay: 'eu-west-1',
          cipher: 'AES-256-GCM',
          latencyMs: 12,
          natType: 'Symmetric',
        )
      : const Diagnostics(
          relay: '—',
          cipher: 'AES-256-GCM',
          latencyMs: 0,
          natType: 'Unknown',
        );

  Timer? _ticker;
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
  Future<Identity> identity() async =>
      Identity(id: _myId, deviceName: _demoMode ? 'My PC' : '');

  @override
  Future<String> oneTimePassword() async => _password;

  @override
  Future<String> regeneratePassword() async => _password = genPassword();

  @override
  Stream<List<Peer>> peers() => _peers.stream;

  @override
  Future<void> upsertPeer(Peer p) async {
    // Mock: no persistence. RealBridge will call main_set_peer_alias etc.
  }

  @override
  Future<void> forgetPeer(String id) async {
    // Mock: no persistence.
  }

  @override
  Stream<Diagnostics> diagnostics() => _diagnostics.stream;

  @override
  Stream<ConnectEvent> connectEvents() => _connectEvents.stream;

  @override
  Future<void> connect(String peerId) async {
    if (_demoMode) {
      // Demo: walk through all 4 stages successfully.
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
    } else {
      // Empty mode: report failure quickly. Without RealBridge the Rust
      // core isn't wired, so an actual handshake is impossible.
      final peer = Peer(
        id: peerId,
        name: peerId,
        os: PeerOS.windows,
        tag: '',
        lastSeen: 'now',
        status: PeerStatus.online,
      );
      await Future<void>.delayed(const Duration(milliseconds: 800));
      _connectEvents.add(ConnectEvent(
        peer: peer,
        stage: ConnectStage.failed,
        message: 'Rust core not wired yet — Phase 2.4 pending.',
      ));
    }
  }

  @override
  Future<void> cancelConnect() async {}

  @override
  Future<void> disconnect() async {}

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
    _ticker?.cancel();
    _peers.close();
    _diagnostics.close();
    _connectEvents.close();
    _transfers.close();
  }
}
