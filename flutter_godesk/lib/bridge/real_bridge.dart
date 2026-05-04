// RealBridge — Phase 2.4 production implementation. Wraps the upstream
// `flutter_rust_bridge`-generated FFI (`generated_bridge.dart`) and translates
// its surface into our `Bridge` interface so all `lib/screens/` code keeps
// working unchanged.
//
// THIS FILE IS A SKELETON. It compiles against the current `Bridge` interface
// but every method body is a `TODO(realbridge)` block that will become a real
// FFI call once `flutter_rust_bridge_codegen` produces `generated_bridge.dart`
// from `client/src/flutter_ffi.rs`. See [ffi_mapping.md](./ffi_mapping.md)
// for the per-method correspondence and [codegen_runbook.md](./codegen_runbook.md)
// for the build steps.
//
// To swap-in once generated_bridge.dart exists:
//   1. `flutter_rust_bridge_codegen --rust-input client/src/flutter_ffi.rs
//      --dart-output client/flutter_godesk/lib/bridge/generated_bridge.dart`.
//   2. Uncomment the `import 'generated_bridge.dart';` line below.
//   3. Replace each `TODO(realbridge)` body with the matching FFI call.
//   4. In `main.dart`:
//        final Bridge bridge = const bool.fromEnvironment('GODESK_REAL_BRIDGE')
//            ? RealBridge() : MockBridge();
//      Build with `flutter build windows --release --dart-define=GODESK_REAL_BRIDGE=true`.

import 'dart:async';
import 'dart:convert';

// import 'generated_bridge.dart';  // <- enabled after codegen runs.
import '../data/peers.dart';
import '../data/transfers.dart';
import 'bridge.dart';

/// Shape of one event emitted by upstream `start_global_event_stream`.
/// Every async result, every state change, every transfer progress tick
/// flows through here as a JSON line. RealBridge subscribes once and
/// demultiplexes by `type` into typed StreamControllers below.
class _GlobalEvent {
  const _GlobalEvent({required this.type, required this.body});
  final String type;
  final Map<String, dynamic> body;

  static _GlobalEvent? tryParse(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final t = m['type'];
      if (t is! String) return null;
      return _GlobalEvent(type: t, body: m);
    } catch (_) {
      return null;
    }
  }
}

class RealBridge implements Bridge {
  RealBridge() {
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
    _startGlobalStream();
  }

  // — Reactive state (cached snapshots; pushed to streams on every update)
  List<Peer> _peerList = const <Peer>[];
  final List<TransferItem> _queue = <TransferItem>[];
  // ignore: prefer_final_fields  // mutated by _handleGlobalEvent once wired.
  Diagnostics _diag = const Diagnostics(
    relay: '—',
    cipher: 'AES-256-GCM',
    latencyMs: 0,
    natType: 'Unknown',
  );
  SessionState _session = const SessionState();
  String? _currentSessionId;

  late final StreamController<List<Peer>> _peers;
  late final StreamController<Diagnostics> _diagnostics;
  late final StreamController<List<TransferItem>> _transfers;
  late final StreamController<SessionState> _sessionState;
  final StreamController<ConnectEvent> _connectEvents =
      StreamController<ConnectEvent>.broadcast();
  final StreamController<ChatMessage> _chatEvents =
      StreamController<ChatMessage>.broadcast();

  StreamSubscription<String>? _globalSub;

  List<Peer> get _peersSnapshot => List<Peer>.unmodifiable(_peerList);
  Diagnostics get _diagnosticsSnapshot => _diag;

  /// Subscribe to upstream's `start_global_event_stream` once. Every typed
  /// stream we expose is fed by demultiplexing this single source.
  void _startGlobalStream() {
    // TODO(realbridge): once generated_bridge.dart is in place, replace
    // this stub with:
    //
    //   _globalSub = api
    //       .startGlobalEventStream(appType: 'main')
    //       .listen(_handleGlobalEvent);
    //
    // The Stream<String> returned by `startGlobalEventStream` yields
    // line-delimited JSON. Each line maps to one of the cases in
    // `_handleGlobalEvent`.
  }

  // ignore: unused_element  // Wired by _startGlobalStream once codegen lands.
  void _handleGlobalEvent(String raw) {
    final ev = _GlobalEvent.tryParse(raw);
    if (ev == null) return;
    switch (ev.type) {
      case 'peer':
        // body: { id, name, online, tag, lastSeen, ... }
        // TODO(realbridge): merge into _peerList, push _peers.add(...)
        break;
      case 'connecting':
      case 'connected':
      case 'authenticating':
      case 'tunnel':
      case 'msgbox':
        // TODO(realbridge): translate to ConnectEvent + push.
        // 'msgbox' with a "type: 'connection-error'" → ConnectStage.failed.
        // 'connected' → also flips _session.peerId, push sessionState.
        break;
      case 'chat_message':
        // body: { from: 'self'|'peer', text, time }
        // TODO(realbridge): _chatEvents.add(ChatMessage(...))
        break;
      case 'job_progress':
      case 'file_dir':
        // TODO(realbridge): merge transfer state, push _transfers.
        break;
      case 'stats':
        // body: { latency_ms, relay, nat_type, cipher }
        // TODO(realbridge): _diag = Diagnostics(...); _diagnostics.add.
        break;
    }
  }

  // ─── Identity ─────────────────────────────────────────────────────────

  @override
  Future<Identity> identity() async {
    // TODO(realbridge): final id = await api.mainGetMyId();
    //                   final name = (await _options())['name'] ?? '';
    //                   return Identity(id: _formatId(id), deviceName: name);
    throw UnimplementedError('RealBridge.identity — wire after codegen');
  }

  @override
  Future<String> oneTimePassword() async {
    // TODO(realbridge): pull from main_get_options() password field.
    throw UnimplementedError('RealBridge.oneTimePassword');
  }

  @override
  Future<String> regeneratePassword() async {
    // TODO(realbridge): main_set_option("password", "") triggers Rust to
    // regenerate; then return main_get_options()["password"].
    throw UnimplementedError('RealBridge.regeneratePassword');
  }

  bool _numericOtp = false;

  @override
  bool get numericOtp => _numericOtp;

  @override
  set numericOtp(bool v) {
    _numericOtp = v;
    // TODO(realbridge): map to main_set_option(<exact-key>, "Y" | "").
  }

  // ─── Address book ─────────────────────────────────────────────────────

  @override
  Stream<List<Peer>> peers() => _peers.stream;

  @override
  Future<void> upsertPeer(Peer p) async {
    // TODO(realbridge): mainSetPeerAlias + mainSetPeerOption batched.
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
    // TODO(realbridge): mainRemovePeer(id).
    _peerList.removeWhere((p) => p.id == id);
    _peers.add(_peersSnapshot);
  }

  @override
  Future<void> setPeerAlias(String peerId, String? alias) async {
    // TODO(realbridge): mainSetPeerAlias(id: peerId, alias: alias ?? '').
  }

  @override
  Future<void> setPeerOption(String peerId, String key, String value) async {
    // TODO(realbridge): mainSetPeerOption(id: peerId, key: key, value: value).
  }

  @override
  Future<String?> getPeerOption(String peerId, String key) async {
    // TODO(realbridge): final v = await api.mainGetPeerOption(id: peerId, key: key);
    //                   return v.isEmpty ? null : v;
    return null;
  }

  // ─── Diagnostics ──────────────────────────────────────────────────────

  @override
  Stream<Diagnostics> diagnostics() => _diagnostics.stream;

  // ─── Audio device enumeration ─────────────────────────────────────────

  @override
  Future<List<String>> audioInputDevices() async {
    // TODO(realbridge): main_get_sound_inputs() — verify exact name.
    return const <String>['Default'];
  }

  @override
  Future<List<String>> audioOutputDevices() async {
    // TODO(realbridge): if upstream doesn't expose this, fall back to a
    // platform-channel call to Win audio API. For first wire-up: stub.
    return const <String>['Default'];
  }

  // ─── Connect / disconnect ─────────────────────────────────────────────

  @override
  Stream<ConnectEvent> connectEvents() => _connectEvents.stream;

  @override
  Future<void> connect(String peerId) async {
    // TODO(realbridge):
    //   final sid = await api.sessionAddSync(id: peerId, isFileTransfer: false, ...);
    //   _currentSessionId = sid;
    //   await api.sessionStart(sessionId: sid, id: peerId);
    // Connect events thereafter arrive via _handleGlobalEvent.
  }

  @override
  Future<void> cancelConnect() async {
    final sid = _currentSessionId;
    if (sid == null) return;
    // TODO(realbridge): api.sessionClose(sessionId: sid);
    _currentSessionId = null;
  }

  @override
  Future<void> disconnect() async {
    final sid = _currentSessionId;
    if (sid == null) return;
    // TODO(realbridge): api.sessionClose(sessionId: sid);
    _currentSessionId = null;
    _session = const SessionState();
    _sessionState.add(_session);
  }

  // ─── Active session state + commands ─────────────────────────────────

  @override
  Stream<SessionState> sessionState() => _sessionState.stream;

  @override
  Future<void> requestRestart() async {
    final sid = _currentSessionId;
    if (sid == null) return;
    // TODO(realbridge): api.sessionRestartRemoteDevice(sessionId: sid).
  }

  @override
  Future<void> toggleVoiceCall() async {
    final sid = _currentSessionId;
    if (sid == null) return;
    final next = !_session.voiceActive;
    // TODO(realbridge): next
    //   ? api.sessionRequestVoiceCall(sessionId: sid)
    //   : api.sessionCloseVoiceCall(sessionId: sid);
    _session = _session.copyWith(voiceActive: next);
    _sessionState.add(_session);
  }

  @override
  Future<void> toggleRecording() async {
    final sid = _currentSessionId;
    if (sid == null) return;
    final next = !_session.recording;
    // TODO(realbridge): api.sessionRecordScreen(sessionId: sid, start: next).
    _session = _session.copyWith(recording: next);
    _sessionState.add(_session);
  }

  @override
  Future<void> togglePrivacyMode(String key) async {
    final sid = _currentSessionId;
    if (sid == null) return;
    final modes = Set<String>.from(_session.privacyModes);
    final on = !modes.contains(key);
    if (on) {
      modes.add(key);
    } else {
      modes.remove(key);
    }
    // TODO(realbridge): api.sessionTogglePrivacyMode(
    //   sessionId: sid, implKey: key, on: on,
    // );
    _session = _session.copyWith(privacyModes: modes);
    _sessionState.add(_session);
  }

  // ─── In-session text chat ─────────────────────────────────────────────

  @override
  Stream<ChatMessage> chatEvents() => _chatEvents.stream;

  @override
  Future<void> sendChat(String text) async {
    final sid = _currentSessionId;
    if (sid == null || text.trim().isEmpty) return;
    // TODO(realbridge): api.sessionSendChat(sessionId: sid, text: text.trim());
    // Echo will arrive via _handleGlobalEvent → 'chat_message' typed as 'self'.
  }

  // ─── Transfers ────────────────────────────────────────────────────────

  @override
  Stream<List<TransferItem>> transfers() => _transfers.stream;

  @override
  Future<void> addTransfer({required String filePath, required TransferDir dir}) async {
    final sid = _currentSessionId;
    if (sid == null) return;
    // TODO(realbridge): api.sessionAddJob(...) — exact signature TBD.
  }

  @override
  Future<void> cancelTransfer(int id) async {
    final sid = _currentSessionId;
    if (sid == null) return;
    // TODO(realbridge): api.sessionCancelJob(sessionId: sid, actId: id).
  }

  @override
  Future<void> clearCompleted() async {
    _queue.removeWhere((i) => i.done);
    _transfers.add(List<TransferItem>.unmodifiable(_queue));
  }

  // ─── Invite link ──────────────────────────────────────────────────────

  @override
  String inviteLink({required String id, required String otp}) {
    final raw = '${id.replaceAll(' ', '')}|$otp';
    final encoded = base64Url.encode(utf8.encode(raw)).replaceAll('=', '');
    return 'https://godeskflow.com/c/$encoded';
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────

  @override
  void dispose() {
    _globalSub?.cancel();
    _peers.close();
    _diagnostics.close();
    _connectEvents.close();
    _transfers.close();
    _sessionState.close();
    _chatEvents.close();
  }
}
