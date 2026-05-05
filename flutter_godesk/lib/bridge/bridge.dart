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

import '../data/invite_link.dart';
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

/// Who sent a chat message in an active session.
enum ChatSender { self, peer }

class ChatMessage {
  const ChatMessage({required this.from, required this.text, required this.time});
  final ChatSender from;
  final String text;
  final DateTime time;
}

/// How the remote frame is sized inside the session viewport.
/// - [original]: 1:1 native pixels, scrollable if larger than viewport.
/// - [fit]: aspect-preserving fit (current default — letterbox/pillarbox).
/// - [stretch]: fill the viewport, breaks aspect ratio.
enum DisplayFit { fit, original, stretch }

/// Reactive state of the *active* remote session. `peerId == null` ⇒ no session.
class SessionState {
  const SessionState({
    this.peerId,
    this.voiceActive = false,
    this.recording = false,
    this.privacyModes = const <String>{},
    this.textureId,
    this.frameWidth = 0,
    this.frameHeight = 0,
    this.fit = DisplayFit.fit,
    this.displayCount = 1,
    this.currentDisplay = 0,
  });

  final String? peerId;
  final bool voiceActive;
  final bool recording;
  final Set<String> privacyModes;

  /// Flutter platform-side texture id for the primary display's RGBA frame.
  /// `null` while the texture is being set up; non-null once
  /// `texture_rgba_renderer.createTexture` returns and the Rust core's
  /// `session_register_pixelbuffer_texture` has been called with the native
  /// pointer. The session screen renders `Texture(textureId: ...)` when set.
  final int? textureId;

  /// Remote display dimensions in pixels — fed by the global event stream's
  /// `peer_info` event. SessionScreen uses these to size the Texture widget
  /// with the correct aspect ratio.
  final int frameWidth;
  final int frameHeight;
  final DisplayFit fit;

  /// Number of displays the remote machine reports. When > 1, the session
  /// toolbar surfaces a display-picker so the operator can switch.
  final int displayCount;

  /// Currently-selected remote display index (0-based).
  final int currentDisplay;

  bool get inSession => peerId != null;
  bool get hasFrame => textureId != null && textureId != -1;

  SessionState copyWith({
    String? peerId,
    bool? clearPeer,
    bool? voiceActive,
    bool? recording,
    Set<String>? privacyModes,
    int? textureId,
    bool? clearTexture,
    int? frameWidth,
    int? frameHeight,
    DisplayFit? fit,
    int? displayCount,
    int? currentDisplay,
  }) {
    return SessionState(
      peerId: (clearPeer ?? false) ? null : peerId ?? this.peerId,
      voiceActive: voiceActive ?? this.voiceActive,
      recording: recording ?? this.recording,
      privacyModes: privacyModes ?? this.privacyModes,
      textureId: (clearTexture ?? false) ? null : textureId ?? this.textureId,
      frameWidth: frameWidth ?? this.frameWidth,
      frameHeight: frameHeight ?? this.frameHeight,
      fit: fit ?? this.fit,
      displayCount: displayCount ?? this.displayCount,
      currentDisplay: currentDisplay ?? this.currentDisplay,
    );
  }
}

abstract class Bridge {
  // — Identity —
  Future<Identity> identity();
  Future<String> oneTimePassword();
  Future<String> regeneratePassword();

  /// Whether OTP generation should yield digits-only (easier to dictate).
  /// Defaults to false. RuDesktop 2.9.492 parity.
  bool get numericOtp;
  set numericOtp(bool v);

  // — Address book —
  Stream<List<Peer>> peers();
  Future<void> upsertPeer(Peer p);
  Future<void> forgetPeer(String id);
  Future<void> setPeerAlias(String peerId, String? alias);

  // — LAN discovery (RuDesktop "Найдено" tab parity) —
  /// Stream of peers found by the local mDNS/SSDP discovery sweep. Updates
  /// arrive whenever the Rust core publishes a new `load_lan_peers` event.
  Stream<List<Peer>> lanPeers();

  /// Fire-and-forget trigger to start a fresh LAN discovery sweep. The
  /// Rust core blasts an SSDP probe and listens for replies; results
  /// flow back via [lanPeers].
  Future<void> triggerLanDiscovery();

  /// Per-peer connection presets (image quality, mode, audio).
  /// Reads/writes are persisted opaquely; key/value strings only.
  Future<void> setPeerOption(String peerId, String key, String value);
  Future<String?> getPeerOption(String peerId, String key);

  // — Diagnostics —
  Stream<Diagnostics> diagnostics();

  // — Audio device enumeration (RuDesktop 2.9.385 parity) —
  Future<List<String>> audioInputDevices();
  Future<List<String>> audioOutputDevices();

  // — Connect / disconnect —
  Stream<ConnectEvent> connectEvents();
  /// Optional [mode] selects RustDesk session args. Wire values:
  /// `view-only` / `full-control` / `file-transfer` / `port-forward` /
  /// `rdp` / `terminal`. Default behavior matches `full-control`.
  Future<void> connect(String peerId, {String? mode});
  Future<void> cancelConnect();
  Future<void> disconnect();

  // — Active session state + commands —
  Stream<SessionState> sessionState();
  Future<void> requestRestart();
  Future<void> toggleVoiceCall();
  Future<void> toggleRecording();
  Future<void> togglePrivacyMode(String key);
  Future<void> setDisplayFit(DisplayFit fit);
  /// Switch the active remote display (multi-monitor peers only).
  Future<void> switchDisplay(int index);

  // — In-session text chat —
  Stream<ChatMessage> chatEvents();
  Future<void> sendChat(String text);

  /// Stream of transient system notices the UI should surface as toasts —
  /// UAC required on remote, permission denied, peer reconnected, etc.
  /// Bodies are pre-formatted, ready to drop into a SnackBar.
  Stream<String> systemNotices();

  // — Remote input (mouse + keyboard) —
  /// Cursor moved to absolute remote-screen coordinates `(x, y)`.
  Future<void> sendMouseMove(int x, int y);

  /// Mouse button event. `button` is the Flutter pointer button mask
  /// (1 = primary/left, 2 = secondary/right, 4 = middle, 8 = back, 16 = forward).
  Future<void> sendMouseButton({required bool down, required int button});

  /// Vertical wheel delta — positive values scroll down on the remote.
  Future<void> sendMouseWheel(int deltaY);

  /// Raw keyboard event passthrough. `name` is `LogicalKeyboardKey.keyLabel`
  /// or similar identifier; `platformCode` is the Win32 VK / X11 keysym etc;
  /// `lockModes` carries CapsLock/NumLock state as a bitmask.
  Future<void> sendKey({
    required String name,
    required int platformCode,
    required int positionCode,
    required int lockModes,
    required bool down,
  });

  // — Transfers —
  Stream<List<TransferItem>> transfers();
  Future<void> addTransfer({required String filePath, required TransferDir dir});
  Future<void> cancelTransfer(int id);
  Future<void> clearCompleted();

  /// Re-enqueue a previously-failed transfer. The implementation may
  /// reset progress to 0 and clear the failed flag, or actually re-issue
  /// the underlying RustDesk file-transfer call. Mock just resets the
  /// item; RealBridge re-issues `session_send_files`.
  Future<void> retryTransfer(int id);

  /// Dismiss a failed transfer from the queue without retrying. Distinct
  /// from cancelTransfer (which targets active transfers and writes
  /// `failed=true` so the user still sees the failure).
  Future<void> dismissFailed(int id);

  /// Re-arrange the queue by moving the item with [movingId] to right
  /// before [beforeId]. When [beforeId] is null, the item is moved to the
  /// end. Working in ID-space keeps the API resilient to whatever the UI
  /// (or another consumer) is currently sorting by.
  Future<void> reorderTransfer({required int movingId, int? beforeId});

  // — Invite links (RuDesktop 2.9.448 parity) —
  /// Build a shareable URL like `https://godeskflow.com/c/<base64(id|otp)>`.
  /// Receiver clicking should open GoDesk and prefill the connect form.
  String inviteLink({required String id, required String otp});

  /// List of all generated invite links, persisted across launches.
  Future<List<InviteLink>> listInviteLinks();

  /// Append a new invite link to the persisted list.
  Future<void> addInviteLink(InviteLink link);

  /// Remove an invite link by id.
  Future<void> removeInviteLink(String id);

  // — Persisted settings ───────────────────────────────────────────────
  /// Read a global option by key. Returns empty string if unset (matches
  /// upstream `main_get_option` semantics so callers don't need null
  /// handling).
  Future<String> getOption(String key);

  /// Write a global option. Empty `value` clears it. RustDesk persists
  /// these in its `options.json` config file.
  Future<void> setOption(String key, String value);

  void dispose();
}
