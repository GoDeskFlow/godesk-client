// SessionScreen — full-bleed dark panel with floating toolbar over a fake
// remote desktop frame. Port of SkeuoSession from godesk-skeuo-app.jsx.
//
// Toolbar capabilities (RuDesktop parity, Tier-1 of feature-gap-rudesktop.md):
//   ▸ Chat overlay slid in from the right edge — text chat with the remote
//     operator (RuDesktop 2.9.385).
//   ▸ Reboot remote machine (RuDesktop home).
//   ▸ Privacy mode toggle — blanks the remote screen during the session
//     (RuDesktop "приватный режим", implicit).
//   ▸ Voice call toggle (RuDesktop 2.9.385).
//   ▸ Session recording (RuDesktop 2.9.385).
//
// Wired through `Bridge.sessionState()` + `Bridge.chatEvents()` so the
// RealBridge swap-in just needs to back the same methods with FFI calls.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../bridge/bridge.dart';
import '../bridge/provider.dart';
import '../data/peers.dart';
import '../kit/status_led.dart';
import '../kit/tactile_button.dart';
import '../theme/godesk_theme.dart';
import '../theme/typography.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    required this.peer,
    required this.onDisconnect,
    super.key,
  });

  final Peer peer;
  final VoidCallback onDisconnect;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  bool _chatOpen = false;
  int _unread = 0;
  final List<ChatMessage> _messages = <ChatMessage>[];
  StreamSubscription<ChatMessage>? _chatSub;
  StreamSubscription<String>? _noticeSub;
  SessionState _session = const SessionState();
  StreamSubscription<SessionState>? _stateSub;
  bool _wired = false;

  Bridge get _bridge => BridgeProvider.of(context);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_globalKeyHandler);
  }

  /// Session-level keyboard shortcuts intercepted before they reach
  /// `_RemoteFrame._onKey` (and thus before being forwarded to the
  /// remote machine). Currently maps `Ctrl+1..9` → switch display when
  /// the remote has multiple monitors.
  bool _globalKeyHandler(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (!ctrl || alt || shift) return false;
    final k = event.logicalKey;
    final digits = <LogicalKeyboardKey>[
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    final idx = digits.indexOf(k);
    if (idx < 0) return false;
    if (idx >= _session.displayCount) return false;
    if (_session.displayCount <= 1) return false;
    _bridge.switchDisplay(idx);
    return true; // Consume so the remote doesn't also receive Ctrl+N.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) return;
    _wired = true;
    _chatSub = _bridge.chatEvents().listen((m) {
      if (!mounted) return;
      setState(() {
        _messages.add(m);
        if (!_chatOpen && m.from == ChatSender.peer) _unread++;
      });
    });
    _stateSub = _bridge.sessionState().listen((s) {
      if (!mounted) return;
      setState(() => _session = s);
    });
    // Reflect the active peer in the OS window title so users with
    // multiple sessions can identify them in the taskbar.
    windowManager.setTitle('GoDesk · ${widget.peer.displayName}');
    _noticeSub = _bridge.systemNotices().listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 3500),
          content: Row(
            children: <Widget>[
              const Icon(Icons.info_outline, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(msg)),
            ],
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_globalKeyHandler);
    _chatSub?.cancel();
    _stateSub?.cancel();
    _noticeSub?.cancel();
    // Reset window title back to "GoDesk" once the session ends.
    windowManager.setTitle('GoDesk');
    super.dispose();
  }

  void _toggleChat() {
    setState(() {
      _chatOpen = !_chatOpen;
      if (_chatOpen) _unread = 0;
    });
  }

  bool _privacyOn(String key) => _session.privacyModes.contains(key);

  /// Press-then-release a sequence of keys. Mirrors RustDesk's
  /// `sendCAD()` / `sendKeyCombo()` helpers. Each entry is a
  /// (LogicalKeyboardKey, PhysicalKeyboardKey) pair so we can report
  /// both codes to the remote (matches the same wire shape as `_onKey`
  /// inside the Texture's KeyboardListener).
  Future<void> _sendCombo(List<(LogicalKeyboardKey, PhysicalKeyboardKey)> keys) async {
    for (final k in keys) {
      await _bridge.sendKey(
        name: k.$1.debugName ?? 'unknown',
        platformCode: k.$1.keyId,
        positionCode: k.$2.usbHidUsage,
        lockModes: 0,
        down: true,
      );
    }
    for (final k in keys.reversed) {
      await _bridge.sendKey(
        name: k.$1.debugName ?? 'unknown',
        platformCode: k.$1.keyId,
        positionCode: k.$2.usbHidUsage,
        lockModes: 0,
        down: false,
      );
    }
  }

  static const _ctrl = (LogicalKeyboardKey.controlLeft, PhysicalKeyboardKey.controlLeft);
  static const _alt = (LogicalKeyboardKey.altLeft, PhysicalKeyboardKey.altLeft);
  static const _meta = (LogicalKeyboardKey.metaLeft, PhysicalKeyboardKey.metaLeft);
  static const _shift = (LogicalKeyboardKey.shiftLeft, PhysicalKeyboardKey.shiftLeft);

  Future<void> _sendCtrlAltDel() => _sendCombo(<(LogicalKeyboardKey, PhysicalKeyboardKey)>[
        _ctrl,
        _alt,
        (LogicalKeyboardKey.delete, PhysicalKeyboardKey.delete),
      ]);

  Future<void> _sendWinKey() => _sendCombo(const <(LogicalKeyboardKey, PhysicalKeyboardKey)>[
        _meta,
      ]);

  Future<void> _sendWinL() => _sendCombo(<(LogicalKeyboardKey, PhysicalKeyboardKey)>[
        _meta,
        (LogicalKeyboardKey.keyL, PhysicalKeyboardKey.keyL),
      ]);

  Future<void> _sendAltTab() => _sendCombo(<(LogicalKeyboardKey, PhysicalKeyboardKey)>[
        _alt,
        (LogicalKeyboardKey.tab, PhysicalKeyboardKey.tab),
      ]);

  Future<void> _sendAltF4() => _sendCombo(<(LogicalKeyboardKey, PhysicalKeyboardKey)>[
        _alt,
        (LogicalKeyboardKey.f4, PhysicalKeyboardKey.f4),
      ]);

  Future<void> _sendCtrlShiftEsc() => _sendCombo(<(LogicalKeyboardKey, PhysicalKeyboardKey)>[
        _ctrl,
        _shift,
        (LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape),
      ]);

  Future<void> _sendPrintScreen() => _sendCombo(const <(LogicalKeyboardKey, PhysicalKeyboardKey)>[
        (LogicalKeyboardKey.printScreen, PhysicalKeyboardKey.printScreen),
      ]);

  Future<void> _confirmReboot() async {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: t.border),
        ),
        title: Text('Restart remote?',
            style: GDtype.ui(size: 14, weight: FontWeight.w700, color: t.heading)),
        content: Text(
          'Restart ${widget.peer.name}? The session will reconnect automatically when the remote comes back online.',
          style: GDtype.ui(size: 12, color: t.body),
        ),
        actions: <Widget>[
          TactileButton(
            small: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          TactileButton(
            small: true,
            variant: TactileVariant.danger,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('RESTART'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _bridge.requestRestart();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final bg = switch (widget.peer.os) {
      PeerOS.macos => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF1A3A5C), Color(0xFF4D2A5E), Color(0xFFD96A4C)],
          stops: <double>[0.0, 0.6, 1.0],
        ),
      PeerOS.windows => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0078D4), Color(0xFF1BA1E2), Color(0xFF00B294)],
        ),
      PeerOS.linux => const RadialGradient(
          center: Alignment(-0.4, -0.2),
          radius: 1.2,
          colors: <Color>[Color(0xFF2A3142), Color(0xFF0C0D12)],
        ),
    };
    final blanked = _privacyOn('blank-screen');
    final recording = _session.recording;
    final voice = _session.voiceActive;

    return Container(
      color: const Color(0xFF0A0A0A),
      child: Stack(
        children: <Widget>[
          // Remote screen — Texture widget showing the RGBA buffer Rust core
          // writes to, OR the gradient placeholder while we wait for the
          // first frame (Mock build / RealBridge before peer_info arrives).
          Positioned.fill(
            child: _session.hasFrame
                ? _RemoteFrame(
                    textureId: _session.textureId!,
                    width: _session.frameWidth,
                    height: _session.frameHeight,
                    fit: _session.fit,
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(gradient: bg),
                    child: const _SessionInner(),
                  ),
          ),
          // Privacy "blank screen" overlay — RuDesktop parity.
          if (blanked)
            const Positioned.fill(
              child: ColoredBox(color: Color(0xEE000000), child: _PrivacyBanner()),
            ),
          if (recording)
            const Positioned(top: 56, left: 16, child: _RecordingBadge()),
          // _RecordingBadge mounts/unmounts with `recording`, so its
          // own initState is the natural reset point for the duration
          // counter — no extra plumbing required here.
          if (voice)
            const Positioned(top: 56, right: 16, child: _VoiceBadge()),
          // Floating toolbar
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: t.chromeGradient,
                  border: Border.all(color: t.chromeBorder),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0x66000000), offset: Offset(0, 6), blurRadius: 20),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const StatusLED(color: LEDColors.online, pulse: true),
                          const SizedBox(width: 6),
                          Text(widget.peer.displayName,
                              style: GDtype.ui(size: 11, weight: FontWeight.w700, color: t.heading, letterSpacing: 0.44)),
                          const SizedBox(width: 6),
                          Text('· ${widget.peer.id}',
                              style: GDtype.mono(size: 10, color: t.heading.withValues(alpha: 0.55))),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 16, color: t.border),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: Icons.computer_outlined,
                      label: 'VIEW',
                      tooltip: 'Focus the remote desktop view',
                      onPressed: () {},
                    ),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: Icons.folder_outlined,
                      label: 'FILES',
                      tooltip: 'Open the file transfer panel',
                      onPressed: () {},
                    ),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: Icons.chat_bubble_outline,
                      label: 'CHAT',
                      active: _chatOpen,
                      badge: _unread,
                      tooltip: 'Toggle text chat with the remote operator',
                      onPressed: _toggleChat,
                    ),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: voice ? Icons.mic : Icons.mic_off,
                      label: 'VOICE',
                      active: voice,
                      tooltip: voice ? 'End voice call' : 'Start voice call',
                      onPressed: () => _bridge.toggleVoiceCall(),
                    ),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: recording ? Icons.fiber_manual_record : Icons.radio_button_unchecked,
                      label: recording ? 'REC' : 'RECORD',
                      active: recording,
                      activeColor: const Color(0xFFE03030),
                      tooltip: recording
                          ? 'Stop session recording'
                          : 'Record this session to disk',
                      onPressed: () => _bridge.toggleRecording(),
                    ),
                    const SizedBox(width: 4),
                    Container(width: 1, height: 16, color: t.border),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: blanked ? Icons.visibility_off : Icons.visibility_outlined,
                      label: 'PRIVACY',
                      active: blanked,
                      tooltip: blanked
                          ? 'Show remote screen again'
                          : 'Blank the remote screen for privacy',
                      onPressed: () => _bridge.togglePrivacyMode('blank-screen'),
                    ),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: switch (_session.fit) {
                        DisplayFit.original => Icons.fit_screen_outlined,
                        DisplayFit.fit => Icons.aspect_ratio_outlined,
                        DisplayFit.stretch => Icons.fullscreen,
                      },
                      label: switch (_session.fit) {
                        DisplayFit.original => '1:1',
                        DisplayFit.fit => 'FIT',
                        DisplayFit.stretch => 'FILL',
                      },
                      tooltip: switch (_session.fit) {
                        DisplayFit.fit => 'Fit (cycle to 1:1 native pixels)',
                        DisplayFit.original => '1:1 native (cycle to stretch fill)',
                        DisplayFit.stretch => 'Stretch fill (cycle to aspect-fit)',
                      },
                      onPressed: () {
                        // Cycle: fit → original → stretch → fit.
                        final next = switch (_session.fit) {
                          DisplayFit.fit => DisplayFit.original,
                          DisplayFit.original => DisplayFit.stretch,
                          DisplayFit.stretch => DisplayFit.fit,
                        };
                        _bridge.setDisplayFit(next);
                      },
                    ),
                    if (_session.displayCount > 1) ...<Widget>[
                      const SizedBox(width: 4),
                      // Display switcher — popup menu of 1..N indices for
                      // multi-monitor remote machines.
                      PopupMenuButton<int>(
                        tooltip: 'Switch remote display',
                        offset: const Offset(0, 28),
                        onSelected: _bridge.switchDisplay,
                        itemBuilder: (ctx) => <PopupMenuEntry<int>>[
                          for (var i = 0; i < _session.displayCount; i++)
                            PopupMenuItem<int>(
                              value: i,
                              child: Text('Display ${i + 1}'),
                            ),
                        ],
                        child: TactileButton(
                          small: true,
                          onPressed: null, // PopupMenuButton handles tap.
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.monitor, size: 12),
                              const SizedBox(width: 4),
                              Text('DISP ${_session.currentDisplay + 1}/${_session.displayCount}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      tooltip: 'Send a hotkey combo',
                      offset: const Offset(0, 28),
                      onSelected: (action) {
                        switch (action) {
                          case 'cad':
                            _sendCtrlAltDel();
                          case 'winl':
                            _sendWinL();
                          case 'win':
                            _sendWinKey();
                          case 'altf4':
                            _sendAltF4();
                          case 'alttab':
                            _sendAltTab();
                          case 'ctrlshiftesc':
                            _sendCtrlShiftEsc();
                          case 'prtsc':
                            _sendPrintScreen();
                        }
                      },
                      itemBuilder: (_) => const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(value: 'cad', child: Text('Ctrl + Alt + Del')),
                        PopupMenuItem<String>(value: 'winl', child: Text('Win + L (lock)')),
                        PopupMenuItem<String>(value: 'win', child: Text('Win key (Start menu)')),
                        PopupMenuDivider(),
                        PopupMenuItem<String>(value: 'alttab', child: Text('Alt + Tab')),
                        PopupMenuItem<String>(value: 'altf4', child: Text('Alt + F4')),
                        PopupMenuItem<String>(value: 'ctrlshiftesc', child: Text('Ctrl + Shift + Esc (Task Manager)')),
                        PopupMenuItem<String>(value: 'prtsc', child: Text('PrtSc')),
                      ],
                      child: TactileButton(
                        small: true,
                        onPressed: null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const <Widget>[
                            Icon(Icons.keyboard, size: 12),
                            SizedBox(width: 4),
                            Text('KEYS'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: Icons.lock_outline,
                      label: 'LOCK',
                      tooltip: 'Lock remote (Win + L)',
                      onPressed: _sendWinL,
                    ),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: Icons.restart_alt,
                      label: 'REBOOT',
                      tooltip: 'Restart the remote machine',
                      onPressed: _confirmReboot,
                    ),
                    const SizedBox(width: 4),
                    Container(width: 1, height: 16, color: t.border),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Disconnect from this peer',
                      waitDuration: const Duration(milliseconds: 350),
                      child: TactileButton(
                        small: true,
                        variant: TactileVariant.danger,
                        onPressed: widget.onDisconnect,
                        child: const Text('DISCONNECT'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Chat overlay panel — slides in from the right.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            top: 0,
            bottom: 0,
            right: _chatOpen ? 0 : -340,
            width: 340,
            child: _ChatPanel(
              messages: _messages,
              onClose: _toggleChat,
              onSend: (text) => _bridge.sendChat(text),
              theme: t,
              peerName: widget.peer.displayName,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the active session's RGBA frame coming from the Rust core via
/// `texture_rgba_renderer`. The Texture widget is GPU-backed so frame updates
/// are essentially free for Flutter — the Rust side writes pixels directly
/// into the native texture buffer Flutter created.
///
/// Wraps the Texture in a Listener (mouse) + Focus + KeyboardListener
/// (keyboard) so input events are forwarded to the Rust core. Coordinate
/// translation: Flutter's local pixel position is scaled to remote-screen
/// coordinates using the AspectRatio-fit child rect.
class _RemoteFrame extends StatefulWidget {
  const _RemoteFrame({
    required this.textureId,
    required this.width,
    required this.height,
    required this.fit,
  });

  final int textureId;
  final int width;
  final int height;
  final DisplayFit fit;

  @override
  State<_RemoteFrame> createState() => _RemoteFrameState();
}

class _RemoteFrameState extends State<_RemoteFrame> {
  final FocusNode _focus = FocusNode();
  final GlobalKey _frameKey = GlobalKey();

  Bridge get _bridge => BridgeProvider.of(context);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Map a pointer's local position (in widget space) to remote-screen
  /// pixel coordinates. The Texture widget can be fit / 1:1 / stretched
  /// based on `widget.fit`, so the math depends on which mode is active.
  /// Off-area pointer events (in fit / original modes) are dropped.
  (int, int)? _toRemote(Offset local, BoxConstraints constraints) {
    if (widget.width <= 0 || widget.height <= 0) return null;

    double childWidth, childHeight, dx0, dy0;
    switch (widget.fit) {
      case DisplayFit.stretch:
        // Texture fills the parent — no aspect preservation.
        childWidth = constraints.maxWidth;
        childHeight = constraints.maxHeight;
        dx0 = 0;
        dy0 = 0;
        break;
      case DisplayFit.original:
        // 1:1 native pixels, centred. May overflow viewport (scrollable
        // wrapper added later).
        childWidth = widget.width.toDouble();
        childHeight = widget.height.toDouble();
        dx0 = (constraints.maxWidth - childWidth) / 2;
        dy0 = (constraints.maxHeight - childHeight) / 2;
        break;
      case DisplayFit.fit:
        // Aspect-preserving, letterboxed/pillarboxed.
        final parentAspect = constraints.maxWidth / constraints.maxHeight;
        final remoteAspect = widget.width / widget.height;
        if (parentAspect > remoteAspect) {
          childHeight = constraints.maxHeight;
          childWidth = childHeight * remoteAspect;
          dx0 = (constraints.maxWidth - childWidth) / 2;
          dy0 = 0;
        } else {
          childWidth = constraints.maxWidth;
          childHeight = childWidth / remoteAspect;
          dx0 = 0;
          dy0 = (constraints.maxHeight - childHeight) / 2;
        }
        break;
    }

    final localX = local.dx - dx0;
    final localY = local.dy - dy0;
    if (localX < 0 || localX > childWidth || localY < 0 || localY > childHeight) {
      return null;
    }
    final rx = (localX * widget.width / childWidth).round().clamp(0, widget.width - 1);
    final ry = (localY * widget.height / childHeight).round().clamp(0, widget.height - 1);
    return (rx, ry);
  }

  /// Flutter pointer button mask → Rust core's expected `buttons` value.
  /// Flutter's PointerEvent.buttons is already a bitmask matching what
  /// the rdp/vnc protocols use (1=left, 2=right, 4=middle).
  int _flutterButtonsToProtocol(int flutter) => flutter;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    final down = event is KeyDownEvent;
    final logical = event.logicalKey;
    final physical = event.physicalKey;
    // The Rust core wants the LogicalKeyboardKey debug name (e.g. "keyA",
    // "controlLeft", "f1"). `LogicalKeyboardKey.keyLabel` is too lossy
    // (returns 'A' for keyA), so we synthesize from debugName.
    final name = logical.debugName ?? 'unknown';
    _bridge.sendKey(
      name: name,
      platformCode: logical.keyId,
      positionCode: physical.usbHidUsage,
      lockModes: 0,
      down: down,
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF000000),
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerHover: (e) {
                final r = _toRemote(e.localPosition, constraints);
                if (r != null) _bridge.sendMouseMove(r.$1, r.$2);
              },
              onPointerMove: (e) {
                final r = _toRemote(e.localPosition, constraints);
                if (r != null) _bridge.sendMouseMove(r.$1, r.$2);
              },
              onPointerDown: (e) {
                _focus.requestFocus();
                final r = _toRemote(e.localPosition, constraints);
                if (r != null) _bridge.sendMouseMove(r.$1, r.$2);
                _bridge.sendMouseButton(
                  down: true,
                  button: _flutterButtonsToProtocol(e.buttons),
                );
              },
              onPointerUp: (e) {
                _bridge.sendMouseButton(
                  down: false,
                  button: _flutterButtonsToProtocol(e.buttons | 1),
                );
              },
              onPointerSignal: (e) {
                if (e is PointerScrollEvent) {
                  // Flutter sends pixel deltas; Rust core expects line counts.
                  final lines = (e.scrollDelta.dy / 40).round();
                  if (lines != 0) _bridge.sendMouseWheel(-lines);
                }
              },
              child: switch (widget.fit) {
                DisplayFit.stretch => SizedBox.expand(
                    key: _frameKey,
                    child: Texture(textureId: widget.textureId),
                  ),
                DisplayFit.original => SizedBox.expand(
                    child: ClipRect(
                      child: OverflowBox(
                        minWidth: widget.width.toDouble(),
                        minHeight: widget.height.toDouble(),
                        maxWidth: widget.width.toDouble(),
                        maxHeight: widget.height.toDouble(),
                        child: SizedBox(
                          key: _frameKey,
                          width: widget.width.toDouble(),
                          height: widget.height.toDouble(),
                          child: Texture(textureId: widget.textureId),
                        ),
                      ),
                    ),
                  ),
                DisplayFit.fit => SizedBox.expand(
                    child: AspectRatio(
                      key: _frameKey,
                      aspectRatio: widget.width / widget.height,
                      child: Texture(textureId: widget.textureId),
                    ),
                  ),
              },
            ),
          );
        },
      ),
    );
  }
}

class _SessionInner extends StatelessWidget {
  const _SessionInner();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.computer_outlined, size: 56, color: Color(0xD9FFFFFF)),
          SizedBox(height: 12),
          Text(
            'Remote desktop active',
            style: TextStyle(
              color: Color(0xD9FFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.56,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '1920 × 1080 · 60 fps · 24 ms',
            style: TextStyle(
              color: Color(0xB3FFFFFF),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.visibility_off, size: 48, color: Color(0xCCFFFFFF)),
          SizedBox(height: 12),
          Text(
            'PRIVACY MODE',
            style: TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "Remote screen is blanked for the operator's privacy.\nUnaffected: keyboard / mouse / file transfer.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _RecordingBadge extends StatefulWidget {
  const _RecordingBadge();
  @override
  State<_RecordingBadge> createState() => _RecordingBadgeState();
}

class _RecordingBadgeState extends State<_RecordingBadge>
    with SingleTickerProviderStateMixin {
  late final DateTime _start;
  Timer? _ticker;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _start = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final dur = DateTime.now().difference(_start);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1A1A),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE03030)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Opacity(
              opacity: 0.4 + 0.6 * _pulse.value,
              child: const Icon(Icons.fiber_manual_record,
                  size: 10, color: Color(0xFFE03030)),
            ),
          ),
          const SizedBox(width: 5),
          const Text('REC',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4)),
          const SizedBox(width: 6),
          Text(_format(dur),
              style: const TextStyle(
                color: Color(0xFFFFB0B0),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }
}

class _VoiceBadge extends StatefulWidget {
  const _VoiceBadge();
  @override
  State<_VoiceBadge> createState() => _VoiceBadgeState();
}

class _VoiceBadgeState extends State<_VoiceBadge>
    with TickerProviderStateMixin {
  /// Two animation controllers driving twin LEDs — local mic + remote
  /// mic. We don't have real audio levels yet; until the bridge surfaces
  /// them, both LEDs pulse on slightly out-of-phase periodic rhythms so
  /// the badge looks alive instead of static.
  late final AnimationController _self;
  late final AnimationController _peer;

  @override
  void initState() {
    super.initState();
    _self = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..repeat(reverse: true);
    _peer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 580),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _self.dispose();
    _peer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1A1A),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF22A843)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedBuilder(
            animation: _self,
            builder: (_, __) => _MicLED(level: _self.value, label: 'YOU'),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 10, color: const Color(0x22FFFFFF)),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _peer,
            builder: (_, __) => _MicLED(level: _peer.value, label: 'PEER'),
          ),
        ],
      ),
    );
  }
}

class _MicLED extends StatelessWidget {
  const _MicLED({required this.level, required this.label});
  final double level; // 0..1
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: const Color(0xFF22A843),
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF22A843).withValues(alpha: 0.3 + 0.5 * level),
                blurRadius: 4 + 4 * level,
                spreadRadius: 0.5 + level,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.activeColor,
    this.badge = 0,
    this.tooltip,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;
  final Color? activeColor;
  final int badge;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final raw = TactileButton(
      small: true,
      variant: active
          ? (activeColor != null ? TactileVariant.danger : TactileVariant.primary)
          : TactileVariant.defaultStyle,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
    final btn = tooltip != null
        ? Tooltip(
            message: tooltip!,
            waitDuration: const Duration(milliseconds: 350),
            child: raw,
          )
        : raw;
    if (badge <= 0) return btn;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        btn,
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            width: 14,
            height: 14,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFE03030),
              shape: BoxShape.circle,
            ),
            child: Text(
              badge > 9 ? '9+' : '$badge',
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatPanel extends StatefulWidget {
  const _ChatPanel({
    required this.messages,
    required this.onClose,
    required this.onSend,
    required this.theme,
    required this.peerName,
  });

  final List<ChatMessage> messages;
  final VoidCallback onClose;
  final ValueChanged<String> onSend;
  final GoDeskTheme theme;
  final String peerName;

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant _ChatPanel old) {
    super.didUpdateWidget(old);
    if (widget.messages.length != old.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: t.panel,
          border: Border(left: BorderSide(color: t.border)),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x55000000), offset: Offset(-4, 0), blurRadius: 20),
          ],
        ),
        child: Column(
          children: <Widget>[
            // Header
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: t.chromeGradient,
                border: Border(bottom: BorderSide(color: t.chromeBorder)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.chat_bubble_outline, size: 14, color: t.heading),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'CHAT · ${widget.peerName.toUpperCase()}',
                      overflow: TextOverflow.ellipsis,
                      style: GDtype.wordmark(size: 11, color: t.heading, trackingEm: 0.06),
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onClose,
                      child: Icon(Icons.close, size: 16, color: t.body),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(Icons.forum_outlined, size: 28, color: t.subtle.withValues(alpha: 0.5)),
                            const SizedBox(height: 10),
                            Text('No messages yet',
                                style: GDtype.ui(size: 11, weight: FontWeight.w600, color: t.body)),
                            const SizedBox(height: 4),
                            Text('Type below to chat with the remote operator.',
                                textAlign: TextAlign.center,
                                style: GDtype.ui(size: 10, color: t.subtle).copyWith(height: 1.4)),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(10),
                      itemCount: widget.messages.length,
                      itemBuilder: (context, i) => _ChatBubble(message: widget.messages[i], theme: t),
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.border)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: t.bg,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: t.border),
                      ),
                      child: TextField(
                        controller: _input,
                        onSubmitted: (_) => _submit(),
                        cursorColor: t.heading,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintText: 'Message…',
                          hintStyle: GDtype.ui(size: 12, color: t.subtle),
                        ),
                        style: GDtype.ui(size: 12, color: t.heading),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TactileButton(
                    small: true,
                    variant: TactileVariant.primary,
                    onPressed: _submit,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.send, size: 12),
                        SizedBox(width: 4),
                        Text('SEND'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.theme});
  final ChatMessage message;
  final GoDeskTheme theme;

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final isSelf = message.from == ChatSender.self;
    final t = theme;
    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        constraints: const BoxConstraints(maxWidth: 240),
        decoration: BoxDecoration(
          gradient: isSelf
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[t.accent, t.accentDark],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[t.panelHi, t.panel],
                ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelf ? t.accentDark : t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message.text,
              style: GDtype.ui(
                size: 12,
                color: isSelf ? Colors.white : t.heading,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(message.time),
              style: GDtype.mono(
                size: 9,
                color: (isSelf ? Colors.white : t.subtle).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
