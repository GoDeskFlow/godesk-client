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
import 'dart:convert';
import 'dart:math';

import '../data/invite_link.dart';
import '../data/peers.dart';
import '../data/transfers.dart';
import '../util/format.dart';
import 'bridge.dart';

const bool _demoMode = bool.fromEnvironment('GODESK_DEMO', defaultValue: false);

class MockBridge implements Bridge {
  MockBridge() {
    _queue = _demoMode ? initialQueue() : <TransferItem>[];
    _peerList = _demoMode ? List<Peer>.from(recentPeers) : <Peer>[];
    _peers = StreamController<List<Peer>>.broadcast(
      onListen: () => _peers.add(_peersSnapshot),
    );
    _diagnostics = StreamController<Diagnostics>.broadcast(
      onListen: () => _diagnostics.add(_diagnosticsSnapshot),
    );
    _transfers = StreamController<List<TransferItem>>.broadcast(
      onListen: () => _transfers.add(List<TransferItem>.unmodifiable(_queue)),
    );
    _sessionState = StreamController<SessionState>.broadcast(
      onListen: () => _sessionState.add(_session),
    );
    if (_demoMode) {
      _ticker = Timer.periodic(const Duration(milliseconds: 400), (_) => _tick());
    }
  }

  // Local-only ID, persisted in shared_preferences IF/when we wire it.
  // For empty mode we just generate a random one per launch — RealBridge
  // will later replace this with the actual RustDesk-managed ID.
  late final String _myId = _demoMode ? myId : _generateLocalId();
  late String _password = _demoMode ? initialPassword : _genCurrentPassword();
  late List<TransferItem> _queue;
  late List<Peer> _peerList;
  bool _numericOtp = false;

  // Per-peer key/value option store. RuDesktop calls this "пресеты подключения".
  final Map<String, Map<String, String>> _peerOptions = <String, Map<String, String>>{};

  // Active session state — null peerId means "no session".
  SessionState _session = const SessionState();

  String _genCurrentPassword() => _numericOtp ? genNumericPassword() : genPassword();

  static String _generateLocalId() {
    final r = Random();
    final n = List<int>.generate(9, (_) => r.nextInt(10)).join();
    return '${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6, 9)}';
  }

  /// Address book contents — empty by default, demo seed when GODESK_DEMO=true.
  List<Peer> get _peersSnapshot => List<Peer>.unmodifiable(_peerList);

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
  late final StreamController<SessionState> _sessionState;
  final StreamController<ChatMessage> _chatEvents = StreamController<ChatMessage>.broadcast();

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
  Future<String> regeneratePassword() async => _password = _genCurrentPassword();

  @override
  bool get numericOtp => _numericOtp;

  @override
  set numericOtp(bool v) {
    if (_numericOtp == v) return;
    _numericOtp = v;
    // Regenerate so the OTP currently shown on Home matches the new policy.
    _password = _genCurrentPassword();
  }

  @override
  Stream<List<Peer>> peers() => _peers.stream;

  @override
  Future<void> upsertPeer(Peer p) async {
    final i = _peerList.indexWhere((e) => e.id == p.id);
    if (i >= 0) {
      _peerList[i] = p;
    } else {
      _peerList = <Peer>[..._peerList, p];
    }
    _peers.add(_peersSnapshot);
  }

  @override
  Future<void> forgetPeer(String id) async {
    _peerList.removeWhere((p) => p.id == id);
    _peers.add(_peersSnapshot);
  }

  final StreamController<List<Peer>> _lanPeers =
      StreamController<List<Peer>>.broadcast(
    onListen: null, // populated lazily in lanPeers()
  );

  @override
  Stream<List<Peer>> lanPeers() => _lanPeers.stream;

  @override
  Future<void> triggerLanDiscovery() async {
    // Mock: nothing to discover on a fake LAN.
    _lanPeers.add(const <Peer>[]);
  }

  @override
  Future<void> setPeerAlias(String peerId, String? alias) async {
    final i = _peerList.indexWhere((p) => p.id == peerId);
    if (i < 0) return;
    _peerList[i] = _peerList[i].copyWith(alias: alias);
    _peers.add(_peersSnapshot);
  }

  @override
  Future<void> setPeerOption(String peerId, String key, String value) async {
    _peerOptions.putIfAbsent(peerId, () => <String, String>{})[key] = value;
  }

  @override
  Future<String?> getPeerOption(String peerId, String key) async {
    return _peerOptions[peerId]?[key];
  }

  @override
  Stream<Diagnostics> diagnostics() => _diagnostics.stream;

  @override
  Future<List<String>> audioInputDevices() async {
    if (!_demoMode) return const <String>[];
    return const <String>[
      'Default',
      'Realtek HD Audio · Microphone Array',
      'USB Audio · Blue Yeti',
    ];
  }

  @override
  Future<List<String>> audioOutputDevices() async {
    if (!_demoMode) return const <String>[];
    return const <String>[
      'Default',
      'Realtek HD Audio · Speakers',
      'USB Audio · Blue Yeti Output',
      'AirPods Pro',
    ];
  }

  @override
  Stream<ConnectEvent> connectEvents() => _connectEvents.stream;

  @override
  Future<void> connect(String peerId, {String? mode}) async {
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
      // Demo session goes "active" once we hit `connected`.
      _session = SessionState(peerId: peer.id);
      _sessionState.add(_session);
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
  Future<void> disconnect() async {
    _session = const SessionState();
    _sessionState.add(_session);
  }

  @override
  Stream<SessionState> sessionState() => _sessionState.stream;

  @override
  Future<void> requestRestart() async {
    if (!_demoMode || !_session.inSession) return;
    // Demo: pretend the remote went away for a moment and came back.
    _chatEvents.add(ChatMessage(
      from: ChatSender.peer,
      text: 'System: remote will reboot in 5s.',
      time: DateTime.now(),
    ));
  }

  @override
  Future<void> toggleVoiceCall() async {
    _session = _session.copyWith(voiceActive: !_session.voiceActive);
    _sessionState.add(_session);
  }

  @override
  Future<void> toggleRecording() async {
    _session = _session.copyWith(recording: !_session.recording);
    _sessionState.add(_session);
  }

  @override
  Future<void> setDisplayFit(DisplayFit fit) async {
    _session = _session.copyWith(fit: fit);
    _sessionState.add(_session);
  }

  @override
  Future<void> togglePrivacyMode(String key) async {
    final current = Set<String>.from(_session.privacyModes);
    if (current.contains(key)) {
      current.remove(key);
    } else {
      current.add(key);
    }
    _session = _session.copyWith(privacyModes: current);
    _sessionState.add(_session);
  }

  @override
  Stream<ChatMessage> chatEvents() => _chatEvents.stream;

  @override
  Future<void> sendChat(String text) async {
    if (text.trim().isEmpty) return;
    _chatEvents.add(ChatMessage(
      from: ChatSender.self,
      text: text.trim(),
      time: DateTime.now(),
    ));
    if (_demoMode) {
      // Demo: echo a canned reply 800ms later so the chat doesn't feel dead.
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (_chatEvents.isClosed) return;
        _chatEvents.add(ChatMessage(
          from: ChatSender.peer,
          text: '👍 (mock peer reply)',
          time: DateTime.now(),
        ));
      });
    }
  }

  @override
  Stream<List<TransferItem>> transfers() => _transfers.stream;

  @override
  Future<void> addTransfer({required String filePath, required TransferDir dir}) async {
    final name = filePath.split(RegExp(r'[\\/]')).last;
    _queue.add(TransferItem(
      id: _queue.length + 1,
      name: name,
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
  Future<void> sendMouseMove(int x, int y) async {
    // Mock: no remote, just swallow.
  }

  @override
  Future<void> sendMouseButton({required bool down, required int button}) async {}

  @override
  Future<void> sendMouseWheel(int deltaY) async {}

  @override
  Future<void> sendKey({
    required String name,
    required int platformCode,
    required int positionCode,
    required int lockModes,
    required bool down,
  }) async {}

  final Map<String, String> _options = <String, String>{};
  final List<InviteLink> _invites = <InviteLink>[];

  @override
  Future<List<InviteLink>> listInviteLinks() async =>
      List<InviteLink>.unmodifiable(_invites);

  @override
  Future<void> addInviteLink(InviteLink link) async => _invites.add(link);

  @override
  Future<void> removeInviteLink(String id) async =>
      _invites.removeWhere((l) => l.id == id);

  @override
  Future<String> getOption(String key) async => _options[key] ?? '';

  @override
  Future<void> setOption(String key, String value) async {
    if (value.isEmpty) {
      _options.remove(key);
    } else {
      _options[key] = value;
    }
  }

  @override
  String inviteLink({required String id, required String otp}) {
    final raw = '${id.replaceAll(' ', '')}|$otp';
    final encoded = base64Url.encode(utf8.encode(raw)).replaceAll('=', '');
    return 'https://godeskflow.com/c/$encoded';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _lanPeers.close();
    _peers.close();
    _diagnostics.close();
    _connectEvents.close();
    _transfers.close();
    _sessionState.close();
    _chatEvents.close();
  }
}
