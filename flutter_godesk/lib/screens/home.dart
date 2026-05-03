// Home screen — Your ID, OTP, Diagnostics, Remote-Control input, Address Book.
// Port of godesk-skeuo-home.jsx.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bridge/bridge.dart';
import '../bridge/provider.dart';
import '../data/peers.dart';
import '../kit/_internal/inset_painter.dart';
import '../kit/lcd_panel.dart';
import '../kit/metal_panel.dart';
import '../kit/section_label.dart';
import '../kit/status_led.dart';
import '../kit/tactile_button.dart';
import '../theme/godesk_theme.dart';
import '../theme/typography.dart';
import '../util/format.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.onConnect, super.key});
  final ValueChanged<Peer> onConnect;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _peerInput = TextEditingController();
  String _password = '';
  Identity? _identity;
  List<Peer> _peers = const <Peer>[];
  Diagnostics? _diagnostics;
  StreamSubscription<Diagnostics>? _diagSub;
  bool _showPw = false;
  bool _copiedId = false;
  bool _copiedPw = false;

  Bridge get _bridge => BridgeProvider.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bridge.identity().then((id) {
      if (mounted) setState(() => _identity = id);
    });
    _bridge.oneTimePassword().then((p) {
      if (mounted) setState(() => _password = p);
    });
    _diagSub ??= _bridge.diagnostics().listen((d) {
      if (mounted) setState(() => _diagnostics = d);
    });
  }

  @override
  void dispose() {
    _peerInput.dispose();
    _diagSub?.cancel();
    super.dispose();
  }

  void _copyId() {
    if (_identity == null) return;
    Clipboard.setData(ClipboardData(text: _identity!.id));
    setState(() => _copiedId = true);
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copiedId = false);
    });
  }

  void _copyPw() {
    Clipboard.setData(ClipboardData(text: _password));
    setState(() => _copiedPw = true);
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copiedPw = false);
    });
  }

  void _attemptConnect() {
    final raw = _peerInput.text.replaceAll(RegExp(r'\D'), '');
    if (raw.isEmpty) return;
    final formatted = formatId(_peerInput.text);
    final peer = _peers.cast<Peer?>().firstWhere(
          (p) => p!.id == formatted,
          orElse: () => Peer(
            id: formatted,
            name: formatted,
            os: PeerOS.windows,
            tag: 'Manual',
            lastSeen: 'now',
            status: PeerStatus.online,
          ),
        )!;
    widget.onConnect(peer);
  }



  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return StreamBuilder<List<Peer>>(
      stream: _bridge.peers(),
      builder: (context, snap) {
        if (snap.hasData) _peers = snap.data!;
        return _bg(t);
      },
    );
  }

  Widget _bg(GoDeskTheme t) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: t.dark
              ? const <Color>[Color(0xFF1C1D22), Color(0xFF16171B)]
              : const <Color>[Color(0xFFE8E4DC), Color(0xFFD8D3C8)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(width: 320, child: _leftColumn(t)),
            const SizedBox(width: 14),
            Expanded(child: _rightColumn(t)),
          ],
        ),
      ),
    );
  }

  Widget _leftColumn(GoDeskTheme t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Your ID
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const SectionLabel('Your ID'),
                  const Spacer(),
                  const StatusLED(color: LEDColors.online, pulse: true),
                  const SizedBox(width: 5),
                  Text('ONLINE',
                      style: GDtype.ui(size: 9, weight: FontWeight.w700, color: t.subtle, letterSpacing: 0.9)),
                ],
              ),
              const SizedBox(height: 10),
              LCDPanel(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('> ID:', style: lcdDimLabel(theme: t)),
                    const SizedBox(height: 4),
                    Text(_identity?.id ?? '— — —', style: lcdReadout(theme: t, size: 26)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TactileButton(
                  variant: _copiedId ? TactileVariant.defaultStyle : TactileVariant.primary,
                  onPressed: _copyId,
                  child: Text(_copiedId ? 'COPIED' : 'COPY ID'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // OTP
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const SectionLabel('One-time password'),
                  const Spacer(),
                  Icon(Icons.lock_outline, size: 11, color: t.subtle),
                ],
              ),
              const SizedBox(height: 10),
              LCDPanel(
                child: Text(
                  _showPw ? _password : '•••-•••-••',
                  style: lcdReadout(theme: t, size: 18),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TactileButton(
                      small: true,
                      onPressed: () => setState(() => _showPw = !_showPw),
                      child: Text(_showPw ? 'HIDE' : 'SHOW'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TactileButton(
                      small: true,
                      onPressed: () => setState(() => _password = genPassword()),
                      child: const Text('NEW'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TactileButton(
                      small: true,
                      onPressed: _copyPw,
                      child: Text(_copiedPw ? 'OK' : 'COPY'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Diagnostics
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Diagnostics'),
              const SizedBox(height: 8),
              ..._diagRows(t),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _diagRows(GoDeskTheme t) {
    final d = _diagnostics;
    final rows = <(String, String, bool)>[
      ('Relay', d?.relay ?? '—', d?.relay != null && d!.relay != '—'),
      ('Encryption', d?.cipher ?? 'AES-256-GCM', true),
      ('Latency', (d?.latencyMs ?? 0) > 0 ? '${d!.latencyMs} ms' : '—', (d?.latencyMs ?? 0) > 0),
      ('NAT', d?.natType ?? 'Unknown', d?.natType == 'Open' || d?.natType == 'Cone'),
    ];
    return <Widget>[
      for (var i = 0; i < rows.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            border: i < rows.length - 1
                ? Border(bottom: BorderSide(color: t.border, style: BorderStyle.solid, width: 0.5))
                : null,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(rows[i].$1,
                    style: GDtype.ui(size: 11, color: t.body, weight: FontWeight.w500)),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(rows[i].$2,
                    style: GDtype.mono(size: 10, color: t.heading)),
              ),
              StatusLED(
                color: rows[i].$3 ? LEDColors.online : LEDColors.warning,
                blink: !rows[i].$3,
                pulse: rows[i].$3,
              ),
            ],
          ),
        ),
    ];
  }

  Widget _rightColumn(GoDeskTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Remote Control
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Remote Control'),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: LCDPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: TextField(
                        controller: _peerInput,
                        onChanged: (v) {
                          final formatted = formatId(v);
                          if (formatted != v) {
                            _peerInput.value = TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(offset: formatted.length),
                            );
                          }
                          setState(() {});
                        },
                        onSubmitted: (_) => _attemptConnect(),
                        cursorColor: t.lcdInk,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintText: 'ENTER REMOTE ID',
                          hintStyle: lcdReadout(theme: t, size: 18).copyWith(
                            shadows: const <Shadow>[],
                            color: t.lcdDim,
                          ),
                        ),
                        style: lcdReadout(theme: t, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 130,
                    child: TactileButton(
                      variant: TactileVariant.primary,
                      onPressed: _peerInput.text.isEmpty ? null : _attemptConnect,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text('CONNECT'),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  _modeChip(t, 'View only', false),
                  const SizedBox(width: 6),
                  _modeChip(t, 'Full control', true),
                  const SizedBox(width: 6),
                  _modeChip(t, 'File transfer', false),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Address Book — flex remainder
        Expanded(child: _addressBook(t)),
      ],
    );
  }

  Widget _modeChip(GoDeskTheme t, String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: active
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[t.accent.withValues(alpha: 0.2), t.accent.withValues(alpha: 0.1)],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[t.panelHi, t.panel],
              ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: active ? t.accentDark : t.border),
      ),
      child: Text(
        label.toUpperCase(),
        style: GDtype.wordmark(
          size: 10,
          color: active ? t.accentDark : t.body,
          trackingEm: 0.06,
        ),
      ),
    );
  }

  Widget _addressBook(GoDeskTheme t) {
    return Container(
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15 * t.intensity),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9.5),
        child: Column(
          children: <Widget>[
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: t.dark
                      ? <Color>[t.panelHi, t.panel]
                      : <Color>[const Color(0xFFFCFAF3), const Color(0xFFF0EBDE)],
                ),
                border: Border(bottom: BorderSide(color: t.border)),
              ),
              child: Row(
                children: <Widget>[
                  const SectionLabel('Address Book'),
                  const Spacer(),
                  _entriesPlate(t),
                ],
              ),
            ),
            Expanded(
              child: _peers.isEmpty
                  ? _AddressBookEmpty(theme: t)
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _peers.length,
                      itemBuilder: (context, i) => _PeerRow(
                        peer: _peers[i],
                        isLast: i == _peers.length - 1,
                        onTap: () => widget.onConnect(_peers[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entriesPlate(GoDeskTheme t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: t.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2.5),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: InsetShadowPainter(theme: t, borderRadius: 3, depth: 2),
                ),
              ),
            ),
            Text(
              '${_peers.length} ENTRIES',
              style: GDtype.mono(size: 9, weight: FontWeight.w700, color: t.subtle, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeerRow extends StatefulWidget {
  const _PeerRow({required this.peer, required this.isLast, required this.onTap});
  final Peer peer;
  final bool isLast;
  final VoidCallback onTap;

  @override
  State<_PeerRow> createState() => _PeerRowState();
}

class _PeerRowState extends State<_PeerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? t.accent.withValues(alpha: t.dark ? 0.13 : 0.06)
                : Colors.transparent,
            border: widget.isLast
                ? null
                : Border(bottom: BorderSide(color: t.border, width: 0.5)),
          ),
          child: Row(
            children: <Widget>[
              _OSTile(peer: widget.peer),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(widget.peer.name,
                        style: GDtype.ui(size: 12, weight: FontWeight.w700, color: t.heading)),
                    const SizedBox(height: 1),
                    Text(widget.peer.id,
                        style: GDtype.mono(size: 10, color: t.subtle)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _TagPlate(tag: widget.peer.tag),
              const SizedBox(width: 10),
              SizedBox(
                width: 80,
                child: Text(
                  widget.peer.lastSeen,
                  textAlign: TextAlign.right,
                  style: GDtype.mono(size: 10, color: t.subtle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OSTile extends StatelessWidget {
  const _OSTile({required this.peer});
  final Peer peer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final iconData = switch (peer.os) {
      PeerOS.windows => Icons.window_outlined,
      PeerOS.macos => Icons.apple,
      PeerOS.linux => Icons.terminal_outlined,
    };
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[t.panelHi, t.panel],
            ),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: t.border),
          ),
          child: Icon(iconData, size: 14, color: t.heading),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: peer.isOnline ? LEDColors.online : LEDColors.offline,
              border: Border.all(color: t.panel, width: 1.5),
              boxShadow: peer.isOnline
                  ? <BoxShadow>[
                      const BoxShadow(color: LEDColors.online, blurRadius: 4),
                    ]
                  : const <BoxShadow>[],
            ),
          ),
        ),
      ],
    );
  }
}

class _TagPlate extends StatelessWidget {
  const _TagPlate({required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: t.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2.5),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: InsetShadowPainter(theme: t, borderRadius: 3, depth: 2),
                ),
              ),
            ),
            Text(
              tag.toUpperCase(),
              style: GDtype.ui(size: 9, weight: FontWeight.w700, color: t.subtle, letterSpacing: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressBookEmpty extends StatelessWidget {
  const _AddressBookEmpty({required this.theme});
  final GoDeskTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.contact_phone_outlined, size: 32, color: theme.subtle.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            Text(
              "No saved peers yet",
              style: GDtype.ui(size: 12, weight: FontWeight.w600, color: theme.body),
            ),
            const SizedBox(height: 4),
            Text(
              "Connect to a remote machine using its 9-digit ID and it will appear here.",
              textAlign: TextAlign.center,
              style: GDtype.ui(size: 10, color: theme.subtle).copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

