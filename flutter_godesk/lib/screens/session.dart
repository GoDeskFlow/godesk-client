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

import 'package:flutter/material.dart';

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
  SessionState _session = const SessionState();
  StreamSubscription<SessionState>? _stateSub;
  bool _wired = false;

  Bridge get _bridge => BridgeProvider.of(context);

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
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  void _toggleChat() {
    setState(() {
      _chatOpen = !_chatOpen;
      if (_chatOpen) _unread = 0;
    });
  }

  bool _privacyOn(String key) => _session.privacyModes.contains(key);

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
          Positioned.fill(
            child: DecoratedBox(
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
                      onPressed: () {},
                    ),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: Icons.folder_outlined,
                      label: 'FILES',
                      onPressed: () {},
                    ),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: Icons.chat_bubble_outline,
                      label: 'CHAT',
                      active: _chatOpen,
                      badge: _unread,
                      onPressed: _toggleChat,
                    ),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: voice ? Icons.mic : Icons.mic_off,
                      label: 'VOICE',
                      active: voice,
                      onPressed: () => _bridge.toggleVoiceCall(),
                    ),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: recording ? Icons.fiber_manual_record : Icons.radio_button_unchecked,
                      label: recording ? 'REC' : 'RECORD',
                      active: recording,
                      activeColor: const Color(0xFFE03030),
                      onPressed: () => _bridge.toggleRecording(),
                    ),
                    const SizedBox(width: 4),
                    Container(width: 1, height: 16, color: t.border),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: blanked ? Icons.visibility_off : Icons.visibility_outlined,
                      label: 'PRIVACY',
                      active: blanked,
                      onPressed: () => _bridge.togglePrivacyMode('blank-screen'),
                    ),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: Icons.lock_outline,
                      label: 'LOCK',
                      onPressed: () {},
                    ),
                    const SizedBox(width: 4),
                    _ToolbarButton(
                      icon: Icons.restart_alt,
                      label: 'REBOOT',
                      onPressed: _confirmReboot,
                    ),
                    const SizedBox(width: 4),
                    Container(width: 1, height: 16, color: t.border),
                    const SizedBox(width: 4),
                    TactileButton(
                      small: true,
                      variant: TactileVariant.danger,
                      onPressed: widget.onDisconnect,
                      child: const Text('DISCONNECT'),
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

class _RecordingBadge extends StatelessWidget {
  const _RecordingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1A1A),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE03030)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.fiber_manual_record, size: 10, color: Color(0xFFE03030)),
          SizedBox(width: 5),
          Text('REC', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
        ],
      ),
    );
  }
}

class _VoiceBadge extends StatelessWidget {
  const _VoiceBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1A1A),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF22A843)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.mic, size: 10, color: Color(0xFF22A843)),
          SizedBox(width: 5),
          Text('VOICE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
        ],
      ),
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
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;
  final Color? activeColor;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final btn = TactileButton(
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
