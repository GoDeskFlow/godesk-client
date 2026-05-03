// Home screen — Your ID, OTP, Diagnostics, Remote-Control input, Address Book.
// Port of godesk-skeuo-home.jsx.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bridge/bridge.dart';
import '../bridge/provider.dart';
import '../data/peers.dart';
import '../kit/_internal/inset_painter.dart';
import '../kit/dashed_divider.dart';
import '../kit/lcd_panel.dart';
import '../kit/metal_panel.dart';
import '../kit/os_glyph.dart';
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
  final TextEditingController _searchInput = TextEditingController();
  String _password = '';
  Identity? _identity;
  List<Peer> _peers = const <Peer>[];
  Diagnostics? _diagnostics;
  StreamSubscription<Diagnostics>? _diagSub;
  bool _showPw = false;
  bool _copiedId = false;
  bool _copiedPw = false;
  bool _copiedInvite = false;
  ConnectMode _mode = ConnectMode.fullControl;

  Bridge get _bridge => BridgeProvider.of(context);

  /// Filter peers by [_searchInput] — matches displayName, tag, or id (case-insensitive).
  List<Peer> get _visiblePeers {
    final q = _searchInput.text.trim().toLowerCase();
    if (q.isEmpty) return _peers;
    return _peers.where((p) {
      final hay = '${p.displayName} ${p.tag} ${p.id}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

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
    _searchInput.dispose();
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

  void _copyInvite() {
    if (_identity == null || _password.isEmpty) return;
    final link = _bridge.inviteLink(id: _identity!.id, otp: _password);
    Clipboard.setData(ClipboardData(text: link));
    setState(() => _copiedInvite = true);
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copiedInvite = false);
    });
  }

  Future<void> _editAlias(Peer peer) async {
    final controller = TextEditingController(text: peer.alias ?? '');
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: t.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: t.border),
          ),
          title: Text(
            'Rename peer',
            style: GDtype.ui(size: 14, weight: FontWeight.w700, color: t.heading),
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Original: ${peer.name}  ·  ${peer.id}',
                  style: GDtype.mono(size: 11, color: t.subtle),
                ),
                const SizedBox(height: 10),
                LCDPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    cursorColor: t.lcdInk,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: 'Display name…',
                      hintStyle: lcdReadout(theme: t, size: 13).copyWith(color: t.lcdDim),
                    ),
                    style: lcdReadout(theme: t, size: 13),
                    onSubmitted: (v) => Navigator.of(ctx).pop(v),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TactileButton(
              small: true,
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('CANCEL'),
            ),
            if ((peer.alias ?? '').isNotEmpty)
              TactileButton(
                small: true,
                variant: TactileVariant.danger,
                onPressed: () => Navigator.of(ctx).pop(''),
                child: const Text('CLEAR'),
              ),
            TactileButton(
              small: true,
              variant: TactileVariant.primary,
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null) return;
    final trimmed = result.trim();
    await _bridge.setPeerAlias(peer.id, trimmed.isEmpty ? null : trimmed);
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
    // Persist the chosen mode as a per-peer option so RealBridge can read it
    // when launching the session.
    _bridge.setPeerOption(peer.id, 'mode', _mode.wireValue);
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
              Row(
                children: <Widget>[
                  Expanded(
                    child: TactileButton(
                      variant: _copiedId ? TactileVariant.defaultStyle : TactileVariant.primary,
                      onPressed: _copyId,
                      child: Text(_copiedId ? 'COPIED' : 'COPY ID'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TactileButton(
                      onPressed: _identity == null || _password.isEmpty ? null : _copyInvite,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(Icons.link, size: 12),
                          const SizedBox(width: 4),
                          Text(_copiedInvite ? 'LINK COPIED' : 'INVITE LINK'),
                        ],
                      ),
                    ),
                  ),
                ],
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
      for (var i = 0; i < rows.length; i++) ...<Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
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
        if (i < rows.length - 1) const DashedDivider(height: 1),
      ],
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
                  _modeChip(t, 'View only', ConnectMode.viewOnly),
                  const SizedBox(width: 6),
                  _modeChip(t, 'Full control', ConnectMode.fullControl),
                  const SizedBox(width: 6),
                  _modeChip(t, 'File transfer', ConnectMode.fileTransfer),
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

  Widget _modeChip(GoDeskTheme t, String label, ConnectMode mode) {
    final active = _mode == mode;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _mode = mode),
        child: Container(
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
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const SectionLabel('Address Book'),
                      const Spacer(),
                      _entriesPlate(t),
                    ],
                  ),
                  if (_peers.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    _searchBar(t),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _buildPeerList(t),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entriesPlate(GoDeskTheme t) {
    final visible = _visiblePeers.length;
    final total = _peers.length;
    final filtered = _searchInput.text.trim().isNotEmpty && visible != total;
    final label = filtered ? '$visible / $total ENTRIES' : '$total ENTRIES';
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
              label,
              style: GDtype.mono(size: 9, weight: FontWeight.w700, color: t.subtle, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(GoDeskTheme t) {
    final hasQuery = _searchInput.text.isNotEmpty;
    return LCDPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: SizedBox(
        height: 26,
        child: Row(
          children: <Widget>[
            Icon(Icons.search, size: 13, color: t.lcdDim),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _searchInput,
                onChanged: (_) => setState(() {}),
                cursorColor: t.lcdInk,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: 'Search by name, tag, or ID',
                  hintStyle: lcdReadout(theme: t, size: 11).copyWith(color: t.lcdDim),
                ),
                style: lcdReadout(theme: t, size: 11),
              ),
            ),
            if (hasQuery)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _searchInput.clear();
                    setState(() {});
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.close, size: 13, color: t.lcdDim),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeerList(GoDeskTheme t) {
    if (_peers.isEmpty) return _AddressBookEmpty(theme: t);
    final visible = _visiblePeers;
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No peers match "${_searchInput.text}".',
            style: GDtype.ui(size: 11, color: t.subtle),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: visible.length,
      itemBuilder: (context, i) => _PeerRow(
        peer: visible[i],
        isLast: i == visible.length - 1,
        onTap: () => widget.onConnect(visible[i]),
        onEditAlias: () => _editAlias(visible[i]),
      ),
    );
  }
}

class _PeerRow extends StatefulWidget {
  const _PeerRow({
    required this.peer,
    required this.isLast,
    required this.onTap,
    required this.onEditAlias,
  });
  final Peer peer;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onEditAlias;

  @override
  State<_PeerRow> createState() => _PeerRowState();
}

class _PeerRowState extends State<_PeerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final hasAlias = widget.peer.alias != null && widget.peer.alias!.trim().isNotEmpty;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Stack(
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: _hovered
                  ? t.accent.withValues(alpha: t.dark ? 0.13 : 0.06)
                  : Colors.transparent,
              child: Row(
                children: <Widget>[
                  _OSTile(peer: widget.peer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(widget.peer.displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: GDtype.ui(size: 12, weight: FontWeight.w700, color: t.heading)),
                            ),
                            if (hasAlias) ...<Widget>[
                              const SizedBox(width: 6),
                              Icon(Icons.edit, size: 10, color: t.subtle),
                            ],
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          hasAlias ? '${widget.peer.name} · ${widget.peer.id}' : widget.peer.id,
                          style: GDtype.mono(size: 10, color: t.subtle),
                          overflow: TextOverflow.ellipsis,
                        ),
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
          // Dashed divider — drawn at the bottom of the row, on top of the
          // tap layer so it remains visible while the row is hovered.
          if (!widget.isLast)
            const Positioned(
              left: 14, right: 14, bottom: 0,
              child: IgnorePointer(child: DashedDivider(height: 1)),
            ),
          // Edit-pencil overlay — appears on hover, sits ABOVE the row's tap
          // layer so its own GestureDetector wins. Placed at right margin
          // (overlapping lastSeen text) instead of stealing a layout column.
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _hovered ? 1 : 0,
              child: Center(
                child: IgnorePointer(
                  ignoring: !_hovered,
                  child: Tooltip(
                    message: 'Rename peer',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onEditAlias,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[t.panelHi, t.panel],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: t.border),
                          ),
                          child: Icon(Icons.edit_outlined, size: 12, color: t.body),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
          child: Center(child: OsGlyph(os: peer.os, size: 14, color: t.heading)),
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

/// Connect-time intent — what the user wants to do with the remote.
/// Maps to RustDesk session-arg conn-type. Persisted per-peer via
/// `bridge.setPeerOption(id, 'mode', wireValue)` so the next connect to
/// the same peer remembers the choice (RuDesktop 2.9.385 parity).
enum ConnectMode {
  viewOnly('view-only'),
  fullControl('full-control'),
  fileTransfer('file-transfer');

  const ConnectMode(this.wireValue);
  final String wireValue;
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

