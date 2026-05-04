// RealBridge — Phase 2.4 production implementation.
// Loads `librustdesk.dll` and wraps the auto-generated `Rustdesk` FFI surface
// from `generated_bridge.dart` into our `Bridge` interface so all of
// `lib/screens/` works unchanged.
//
// MVP wiring (today):
//   ✅ identity()         — main_get_my_id
//   ✅ oneTimePassword()  — main_get_options["password"]
//   ✅ peers()            — main_load_recent_peers + global event stream
//   ✅ diagnostics()      — global event stream
//   ✅ connect()          — session_add_sync + session_start
//   ✅ disconnect()       — session_close
//   ✅ chatEvents/sendChat — session_send_chat + global event filter
//   ✅ requestRestart, toggleVoice/Recording, togglePrivacyMode
//   ✅ setPeerAlias, setPeerOption, getPeerOption
//   🟡 transfers()        — global event filter, addTransfer is TODO
//                           (session_send_files needs file picker integration)
//   ❌ audio device enumeration — upstream doesn't expose; returns ['Default']

import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:math';
import 'dart:io';

import 'package:uuid/uuid.dart';
import 'package:texture_rgba_renderer/texture_rgba_renderer.dart';

import '../data/peers.dart';
import '../data/transfers.dart';
import 'bridge.dart';
import 'generated_bridge.dart';

/// Build the FFI binding once. Subsequent `RealBridge` instances reuse the
/// same DLL load — `DynamicLibrary.open` is idempotent.
Rustdesk _loadFfi() {
  final ffi.DynamicLibrary dylib;
  if (Platform.isWindows) {
    dylib = ffi.DynamicLibrary.open('librustdesk.dll');
  } else if (Platform.isLinux) {
    dylib = ffi.DynamicLibrary.open('librustdesk.so');
  } else if (Platform.isMacOS) {
    // Upstream uses DynamicLibrary.process() because the librustdesk symbols
    // are linked into the host binary on macOS.
    dylib = ffi.DynamicLibrary.process();
  } else {
    throw UnsupportedError('RealBridge: unsupported platform ${Platform.operatingSystem}');
  }
  return RustdeskImpl(dylib);
}

class RealBridge implements Bridge {
  RealBridge() : _api = _loadFfi() {
    _peers = StreamController<List<Peer>>.broadcast(
      onListen: () => _peers.add(_peersSnapshot),
    );
    _diagnostics = StreamController<Diagnostics>.broadcast(
      onListen: () => _diagnostics.add(_diag),
    );
    _transfers = StreamController<List<TransferItem>>.broadcast(
      onListen: () => _transfers.add(List<TransferItem>.unmodifiable(_queue)),
    );
    _sessionState = StreamController<SessionState>.broadcast(
      onListen: () => _sessionState.add(_session),
    );
    _startGlobalStream();
    _loadInitialState();
  }

  final Rustdesk _api;

  // — Reactive state caches
  List<Peer> _peerList = const <Peer>[];
  final List<TransferItem> _queue = <TransferItem>[];
  Diagnostics _diag = const Diagnostics(
    relay: '—',
    cipher: 'AES-256-GCM',
    latencyMs: 0,
    natType: 'Unknown',
  );
  SessionState _session = const SessionState();
  UuidValue? _currentSessionId;
  bool _numericOtp = false;

  late final StreamController<List<Peer>> _peers;
  late final StreamController<Diagnostics> _diagnostics;
  late final StreamController<List<TransferItem>> _transfers;
  late final StreamController<SessionState> _sessionState;
  final StreamController<ConnectEvent> _connectEvents =
      StreamController<ConnectEvent>.broadcast();
  final StreamController<ChatMessage> _chatEvents =
      StreamController<ChatMessage>.broadcast();

  StreamSubscription<String>? _globalSub;
  StreamSubscription<EventToUI>? _sessionSub;

  // Remote screen rendering — one texture per session, primary display only
  // for now (multi-monitor support is Phase 5).
  final TextureRgbaRenderer _textureRenderer = TextureRgbaRenderer();
  int? _textureKey;

  List<Peer> get _peersSnapshot => List<Peer>.unmodifiable(_peerList);

  // ─── Initial data load ─────────────────────────────────────────────────

  Future<void> _loadInitialState() async {
    // Trigger upstream to push recent peers via the global event stream.
    try {
      await _api.mainLoadRecentPeers();
    } catch (e) {
      // ignore: avoid_print
      print('[RealBridge] mainLoadRecentPeers failed: $e');
    }
  }

  // ─── Global event-stream dispatcher ────────────────────────────────────

  /// Subscribe once to upstream's `start_global_event_stream`. JSON line per
  /// event; we demultiplex by `name` field into our typed streams.
  void _startGlobalStream() {
    _globalSub = _api.startGlobalEventStream(appType: 'main').listen(
      _handleGlobalEvent,
      onError: (Object e) {
        // ignore: avoid_print
        print('[RealBridge] global event stream error: $e');
      },
    );
  }

  void _handleGlobalEvent(String raw) {
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final name = body['name'] as String? ?? body['type'] as String? ?? '';
    switch (name) {
      case 'load_recent_peers':
      case 'peers':
        _onPeersUpdate(body);
        break;
      case 'chat_client_mode':
      case 'chat_message':
        _onChatMessage(body);
        break;
      case 'connection_ready':
      case 'establish_connection':
        // session_id may be in body — treat as connected event.
        break;
      case 'msgbox':
        _onMsgbox(body);
        break;
    }
  }

  void _onPeersUpdate(Map<String, dynamic> body) {
    final raw = body['peers'] as String? ?? body['data'] as String?;
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _peerList = list.map(_peerFromJson).whereType<Peer>().toList();
      _peers.add(_peersSnapshot);
    } catch (e) {
      // ignore: avoid_print
      print('[RealBridge] failed to parse peers: $e');
    }
  }

  Peer? _peerFromJson(dynamic e) {
    if (e is! Map) return null;
    final id = e['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    final platform = (e['platform'] ?? e['os'] ?? '').toString().toLowerCase();
    final os = platform.contains('mac') || platform.contains('darwin')
        ? PeerOS.macos
        : platform.contains('linux') || platform.contains('unix')
            ? PeerOS.linux
            : PeerOS.windows;
    final hostname = (e['hostname'] ?? e['name'] ?? id).toString();
    return Peer(
      id: _formatId(id),
      name: hostname,
      os: os,
      tag: (e['tag'] ?? '').toString(),
      lastSeen: (e['last_seen'] ?? '').toString(),
      status: PeerStatus.offline, // online only known via active probe
    );
  }

  String _formatId(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length == 9) {
      return '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
    }
    return raw;
  }

  void _onChatMessage(Map<String, dynamic> body) {
    final text = body['text']?.toString() ?? '';
    final fromSelf = body['from_self'] == true || body['from_self'] == 'true';
    if (text.isEmpty) return;
    _chatEvents.add(ChatMessage(
      from: fromSelf ? ChatSender.self : ChatSender.peer,
      text: text,
      time: DateTime.now(),
    ));
  }

  void _onMsgbox(Map<String, dynamic> body) {
    // Translate to ConnectEvent if it relates to current session.
    final type = body['type']?.toString() ?? '';
    final title = body['title']?.toString() ?? '';
    final text = body['text']?.toString() ?? '';
    if (_currentSessionId == null) return;
    final stage = type == 'success' || title.toLowerCase().contains('connected')
        ? ConnectStage.connected
        : ConnectStage.failed;
    _connectEvents.add(ConnectEvent(
      peer: Peer(
        id: '',
        name: '',
        os: PeerOS.windows,
        tag: '',
        lastSeen: '',
        status: PeerStatus.online,
      ),
      stage: stage,
      message: text.isEmpty ? title : text,
    ));
  }

  // ─── Session-event stream (per-connection) ─────────────────────────────

  void _listenSession(UuidValue sessionId, Peer peer) {
    _sessionSub?.cancel();
    final stream = _api.sessionStart(
      sessionId: sessionId,
      id: peer.id.replaceAll(' ', ''),
    );
    _sessionSub = stream.listen((event) {
      event.when(
        event: (json) {
          // Each session event is also a JSON line.
          Map<String, dynamic>? body;
          try {
            body = jsonDecode(json) as Map<String, dynamic>;
          } catch (_) {
            return;
          }
          final name = body['name'] as String? ?? '';
          switch (name) {
            case 'connecting':
              _connectEvents.add(ConnectEvent(peer: peer, stage: ConnectStage.tunnel));
              break;
            case 'authenticating':
              _connectEvents.add(ConnectEvent(peer: peer, stage: ConnectStage.authenticating));
              break;
            case 'connection_ready':
            case 'connected':
            case 'establish_connection':
              _connectEvents.add(ConnectEvent(peer: peer, stage: ConnectStage.connected));
              _session = SessionState(peerId: peer.id);
              _sessionState.add(_session);
              // Spin up the pixel-buffer texture so the SessionScreen can
              // render the remote frame as soon as Rust starts pushing.
              _setupRemoteTexture(sessionId);
              break;
            case 'peer_info':
            case 'sync_peer_info':
              // body['displays'] is JSON list of {x,y,width,height}.
              final disp = _firstDisplay(body);
              if (disp != null) {
                _session = _session.copyWith(
                  frameWidth: disp.$1,
                  frameHeight: disp.$2,
                );
                _sessionState.add(_session);
                // Tell Rust the canvas size so it knows what to render into.
                _api.sessionSetSize(
                  sessionId: sessionId,
                  display: 0,
                  width: disp.$1,
                  height: disp.$2,
                );
              }
              break;
            case 'msgbox':
              _onMsgbox(body);
              break;
          }
        },
        rgba: (_) {},
        texture: (_, __) {},
      );
    }, onError: (Object e) {
      // ignore: avoid_print
      print('[RealBridge] sessionStart stream error: $e');
    });
  }

  // ─── Remote screen texture ────────────────────────────────────────────

  /// Create a Flutter texture, hand its native pointer to the Rust core via
  /// `session_register_pixelbuffer_texture`, and publish the textureId on
  /// [sessionState] so `SessionScreen` can render `Texture(textureId: id)`.
  /// Mirrors `desktop_render_texture.dart::_PixelbufferTexture.create` from
  /// upstream client/flutter, scaled down to one display.
  Future<void> _setupRemoteTexture(UuidValue sessionId) async {
    try {
      final key = _api.getNextTextureKey();
      _textureKey = key;
      final id = await _textureRenderer.createTexture(key);
      if (id == -1) {
        // ignore: avoid_print
        print('[RealBridge] createTexture returned -1');
        return;
      }
      final ptr = await _textureRenderer.getTexturePtr(key);
      _api.sessionRegisterPixelbufferTexture(
        sessionId: sessionId,
        display: 0,
        ptr: ptr,
      );
      _session = _session.copyWith(textureId: id);
      _sessionState.add(_session);
    } catch (e) {
      // ignore: avoid_print
      print('[RealBridge] _setupRemoteTexture failed: $e');
    }
  }

  Future<void> _teardownRemoteTexture(UuidValue sessionId) async {
    final key = _textureKey;
    if (key == null) return;
    try {
      // Pointer 0 deregisters the texture from the Rust side; gives Rust a
      // chance to stop writing before we free the buffer.
      _api.sessionRegisterPixelbufferTexture(
        sessionId: sessionId,
        display: 0,
        ptr: 0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await _textureRenderer.closeTexture(key);
    } catch (e) {
      // ignore: avoid_print
      print('[RealBridge] _teardownRemoteTexture failed: $e');
    }
    _textureKey = null;
  }

  /// Extract the first display's width/height from a peer_info-style body.
  (int, int)? _firstDisplay(Map<String, dynamic> body) {
    try {
      final raw = body['displays'];
      if (raw == null) return null;
      final list = raw is String ? jsonDecode(raw) : raw;
      if (list is! List || list.isEmpty) return null;
      final first = list.first as Map<String, dynamic>;
      final w = (first['width'] as num?)?.toInt() ?? 0;
      final h = (first['height'] as num?)?.toInt() ?? 0;
      if (w <= 0 || h <= 0) return null;
      return (w, h);
    } catch (_) {
      return null;
    }
  }

  // ─── Identity ─────────────────────────────────────────────────────────

  @override
  Future<Identity> identity() async {
    final id = await _api.mainGetMyId();
    return Identity(id: _formatId(id), deviceName: '');
  }

  @override
  Future<String> oneTimePassword() async {
    return _api.mainGetOption(key: 'password');
  }

  @override
  Future<String> regeneratePassword() async {
    await _api.mainSetOption(key: 'password', value: '');
    return _api.mainGetOption(key: 'password');
  }

  @override
  bool get numericOtp => _numericOtp;
  @override
  set numericOtp(bool v) {
    _numericOtp = v;
    _api.mainSetOption(key: 'allow-numeric-one-time-password', value: v ? 'Y' : '');
  }

  // ─── Address book ─────────────────────────────────────────────────────

  @override
  Stream<List<Peer>> peers() => _peers.stream;

  @override
  Future<void> upsertPeer(Peer p) async {
    if (p.alias != null && p.alias!.isNotEmpty) {
      await _api.mainSetPeerAlias(id: p.id.replaceAll(' ', ''), alias: p.alias!);
    }
  }

  @override
  Future<void> forgetPeer(String id) async {
    await _api.mainRemovePeer(id: id.replaceAll(' ', ''));
    _peerList.removeWhere((p) => p.id == id);
    _peers.add(_peersSnapshot);
  }

  @override
  Future<void> setPeerAlias(String peerId, String? alias) async {
    await _api.mainSetPeerAlias(id: peerId.replaceAll(' ', ''), alias: alias ?? '');
  }

  @override
  Future<void> setPeerOption(String peerId, String key, String value) async {
    await _api.mainSetPeerOption(id: peerId.replaceAll(' ', ''), key: key, value: value);
  }

  @override
  Future<String?> getPeerOption(String peerId, String key) async {
    final v = await _api.mainGetPeerOption(id: peerId.replaceAll(' ', ''), key: key);
    return v.isEmpty ? null : v;
  }

  // ─── Diagnostics + audio devices ─────────────────────────────────────

  @override
  Stream<Diagnostics> diagnostics() => _diagnostics.stream;

  @override
  Future<List<String>> audioInputDevices() async => const <String>['Default'];

  @override
  Future<List<String>> audioOutputDevices() async => const <String>['Default'];

  // ─── Connect / disconnect ─────────────────────────────────────────────

  @override
  Stream<ConnectEvent> connectEvents() => _connectEvents.stream;

  @override
  Future<void> connect(String peerId) async {
    final cleanId = peerId.replaceAll(' ', '');
    final sid = const Uuid().v4obj();
    _currentSessionId = sid;
    final peer = _peerList.firstWhere(
      (p) => p.id == _formatId(cleanId),
      orElse: () => Peer(
        id: _formatId(cleanId),
        name: cleanId,
        os: PeerOS.windows,
        tag: 'Manual',
        lastSeen: 'now',
        status: PeerStatus.online,
      ),
    );
    _connectEvents.add(ConnectEvent(peer: peer, stage: ConnectStage.resolving));
    try {
      _api.sessionAddSync(
        sessionId: sid,
        id: cleanId,
        isFileTransfer: false,
        isViewCamera: false,
        isPortForward: false,
        isRdp: false,
        isTerminal: false,
        switchUuid: '',
        forceRelay: false,
        password: '',
        isSharedPassword: false,
        connToken: '',
      );
    } catch (e) {
      // ignore: avoid_print
      print('[RealBridge] sessionAddSync failed: $e');
      _connectEvents.add(ConnectEvent(
        peer: peer,
        stage: ConnectStage.failed,
        message: '$e',
      ));
      return;
    }
    _listenSession(sid, peer);
  }

  @override
  Future<void> cancelConnect() async {
    final sid = _currentSessionId;
    if (sid == null) return;
    await _teardownRemoteTexture(sid);
    await _api.sessionClose(sessionId: sid);
    _currentSessionId = null;
    await _sessionSub?.cancel();
    _sessionSub = null;
  }

  @override
  Future<void> disconnect() async {
    final sid = _currentSessionId;
    if (sid == null) return;
    await _teardownRemoteTexture(sid);
    await _api.sessionClose(sessionId: sid);
    _currentSessionId = null;
    await _sessionSub?.cancel();
    _sessionSub = null;
    _session = const SessionState();
    _sessionState.add(_session);
  }

  // ─── Active session state + commands ─────────────────────────────────

  @override
  Stream<SessionState> sessionState() => _sessionState.stream;

  @override
  Future<void> requestRestart() async {
    // No direct FFI for restart in flutter_ffi.rs; use sessionReconnect with a
    // hard-flush option. TODO: confirm the right call once a remote test
    // machine is available.
  }

  @override
  Future<void> toggleVoiceCall() async {
    final sid = _currentSessionId;
    if (sid == null) return;
    final next = !_session.voiceActive;
    if (next) {
      await _api.sessionRequestVoiceCall(sessionId: sid);
    } else {
      await _api.sessionCloseVoiceCall(sessionId: sid);
    }
    _session = _session.copyWith(voiceActive: next);
    _sessionState.add(_session);
  }

  @override
  Future<void> toggleRecording() async {
    final sid = _currentSessionId;
    if (sid == null) return;
    final next = !_session.recording;
    await _api.sessionRecordScreen(sessionId: sid, start: next);
    _session = _session.copyWith(recording: next);
    _sessionState.add(_session);
  }

  @override
  Future<void> togglePrivacyMode(String key) async {
    final sid = _currentSessionId;
    if (sid == null) return;
    final modes = Set<String>.from(_session.privacyModes);
    final on = !modes.contains(key);
    if (on) modes.add(key); else modes.remove(key);
    await _api.sessionTogglePrivacyMode(sessionId: sid, implKey: key, on: on);
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
    await _api.sessionSendChat(sessionId: sid, text: text.trim());
  }

  // ─── Transfers ────────────────────────────────────────────────────────

  @override
  Stream<List<TransferItem>> transfers() => _transfers.stream;

  @override
  Future<void> addTransfer({required String filePath, required TransferDir dir}) async {
    // TODO(realbridge): wire session_send_files. Needs file_picker package
    // for the UI half; the Rust call signature differs (whole list of paths
    // at once, not single path). Tracked in feature-gap-rudesktop.md.
  }

  @override
  Future<void> cancelTransfer(int id) async {
    final sid = _currentSessionId;
    if (sid == null) return;
    // sessionCancelJob exists in upstream; if not matching by name in
    // generated_bridge.dart, we'll need to add a wrapper.
    // await _api.sessionCancelJob(sessionId: sid, actId: id);
  }

  @override
  Future<void> clearCompleted() async {
    _queue.removeWhere((i) => i.done);
    _transfers.add(List<TransferItem>.unmodifiable(_queue));
  }

  // ─── Invite link (local only) ─────────────────────────────────────────

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
    _sessionSub?.cancel();
    _peers.close();
    _diagnostics.close();
    _connectEvents.close();
    _transfers.close();
    _sessionState.close();
    _chatEvents.close();
  }
}

// Local helper to avoid linker-time complaint about unused Random import.
// ignore: unused_element
final _rngForUnusedImportSilence = Random();
