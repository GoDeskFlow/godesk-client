// Home screen — Your ID, OTP, Diagnostics, Remote-Control input, Address Book.
// Port of godesk-skeuo-home.jsx.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bridge/bridge.dart';
import '../bridge/provider.dart';
import '../data/peers.dart';
import 'invite_manager.dart';
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

/// Address-book ordering. Persisted under `godesk-peer-sort`.
enum PeerSort {
  recent,        // Source order (most-recently-seen first; default).
  name,          // Alphabetical by displayName.
  favoritesFirst // Favorites at the top, then alphabetical.
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.onConnect, super.key});
  // `mode` is the ConnectMode wire-value (e.g. 'full-control', 'rdp').
  // Keep it as an opaque string here so godesk_app.dart doesn't need to
  // import ConnectMode for typing the callback.
  final void Function(Peer peer, {String? mode}) onConnect;

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
  ConnectMode _mode = ConnectMode.fullControl;

  // Address-book sub-tab: 'saved' = persisted peer DB, 'lan' = mDNS sweep.
  String _abTab = 'saved';
  List<Peer> _lanPeers = const <Peer>[];
  StreamSubscription<List<Peer>>? _lanSub;

  // Address book sort order. Loaded from `godesk-peer-sort` on first build.
  PeerSort _sort = PeerSort.recent;
  bool _sortLoaded = false;

  Bridge get _bridge => BridgeProvider.of(context);

  /// Filter peers by [_searchInput] — matches displayName, tag, or id (case-insensitive).
  /// Then sort by [_sort].
  List<Peer> get _visiblePeers {
    final q = _searchInput.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? List<Peer>.of(_peers)
        : _peers.where((p) {
            final hay = '${p.displayName} ${p.tag} ${p.id}'.toLowerCase();
            return hay.contains(q);
          }).toList();
    return _applySort(filtered);
  }

  List<Peer> _applySort(List<Peer> src) {
    switch (_sort) {
      case PeerSort.recent:
        return src;
      case PeerSort.name:
        src.sort((a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        return src;
      case PeerSort.favoritesFirst:
        src.sort((a, b) {
          if (a.fav != b.fav) return a.fav ? -1 : 1;
          return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        });
        return src;
    }
  }

  Future<void> _loadSort() async {
    if (_sortLoaded) return;
    _sortLoaded = true;
    final raw = await _bridge.getOption('godesk-peer-sort');
    if (!mounted) return;
    final next = switch (raw) {
      'name' => PeerSort.name,
      'favoritesFirst' => PeerSort.favoritesFirst,
      _ => PeerSort.recent,
    };
    if (next != _sort) setState(() => _sort = next);
  }

  void _setSort(PeerSort s) {
    setState(() => _sort = s);
    _bridge.setOption('godesk-peer-sort', switch (s) {
      PeerSort.recent => '',
      PeerSort.name => 'name',
      PeerSort.favoritesFirst => 'favoritesFirst',
    });
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
    _lanSub ??= _bridge.lanPeers().listen((peers) {
      if (mounted) setState(() => _lanPeers = peers);
    });
    _loadRecentIds();
    _loadSort();
  }

  @override
  void dispose() {
    _peerInput.dispose();
    _searchInput.dispose();
    _diagSub?.cancel();
    _lanSub?.cancel();
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

  Future<void> _openInviteManager() async {
    if (_identity == null || _password.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => InviteManagerDialog(
        bridge: _bridge,
        id: _identity!.id,
        otp: _password,
      ),
    );
  }

  /// "+ ADD" button in the Saved tab header — manual peer entry without
  /// having to connect first. RuDesktop's "Добавить адрес" parity.
  Future<void> _addPeerDialog() async {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final idCtl = TextEditingController();
    final nameCtl = TextEditingController();
    final tagCtl = TextEditingController();
    PeerOS os = PeerOS.windows;

    String? error;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: t.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: t.border),
          ),
          title: Text('Add peer',
              style: GDtype.ui(size: 14, weight: FontWeight.w700, color: t.heading)),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _addPeerLabel(t, 'Remote ID *'),
                _lcdInput(t, idCtl, '123 456 789', mono: true, autofocus: true),
                const SizedBox(height: 10),
                _addPeerLabel(t, 'Display name'),
                _lcdInput(t, nameCtl, "e.g. Maria's MacBook"),
                const SizedBox(height: 10),
                _addPeerLabel(t, 'Tag'),
                _lcdInput(t, tagCtl, 'Personal'),
                const SizedBox(height: 10),
                _addPeerLabel(t, 'OS'),
                Row(
                  children: <Widget>[
                    for (final entry in <(PeerOS, String)>[
                      (PeerOS.windows, 'WIN'),
                      (PeerOS.macos, 'MAC'),
                      (PeerOS.linux, 'LINUX'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: TactileButton(
                          small: true,
                          variant: os == entry.$1
                              ? TactileVariant.primary
                              : TactileVariant.defaultStyle,
                          onPressed: () => setLocal(() => os = entry.$1),
                          child: Text(entry.$2),
                        ),
                      ),
                  ],
                ),
                if (error != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(error!,
                      style: GDtype.ui(size: 11, color: const Color(0xFFE03030))),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TactileButton(
              small: true,
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('CANCEL'),
            ),
            TactileButton(
              small: true,
              variant: TactileVariant.primary,
              onPressed: () {
                final id = idCtl.text.trim();
                if (id.length < 6) {
                  setLocal(() => error = 'ID is required (min 6 chars).');
                  return;
                }
                if (_peers.any((p) => p.id.replaceAll(' ', '') == id.replaceAll(' ', ''))) {
                  setLocal(() => error = 'A peer with this ID is already saved.');
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final id = idCtl.text.trim();
    final name = nameCtl.text.trim().isNotEmpty
        ? nameCtl.text.trim()
        : 'Peer $id';
    final tag = tagCtl.text.trim().isNotEmpty ? tagCtl.text.trim() : 'Untagged';

    await _bridge.upsertPeer(Peer(
      id: id,
      name: name,
      os: os,
      tag: tag,
      lastSeen: 'just now',
      status: PeerStatus.offline,
    ));
    idCtl.dispose();
    nameCtl.dispose();
    tagCtl.dispose();
  }

  Widget _addPeerLabel(GoDeskTheme t, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(s, style: GDtype.ui(size: 11, color: t.subtle)),
      );

  Widget _lcdInput(
    GoDeskTheme t,
    TextEditingController ctl,
    String hint, {
    bool mono = false,
    bool autofocus = false,
  }) =>
      LCDPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: TextField(
          controller: ctl,
          autofocus: autofocus,
          cursorColor: t.lcdInk,
          decoration: InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
            hintText: hint,
            hintStyle: lcdReadout(theme: t, size: 13).copyWith(color: t.lcdDim),
          ),
          style: lcdReadout(theme: t, size: 13),
        ),
      );

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
    // Push to "recent IDs" history so the dropdown next to CONNECT can
    // suggest it. Keep MRU order, dedup, cap at 8.
    _pushRecentId(formatted);
    widget.onConnect(peer, mode: _mode.wireValue);
  }

  static const int _maxRecentIds = 8;
  List<String> _recentIds = const <String>[];

  Future<void> _loadRecentIds() async {
    final raw = await _bridge.getOption('godesk-recent-ids');
    if (raw.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _recentIds = raw.split('\n').where((s) => s.isNotEmpty).toList();
    });
  }

  Future<void> _pushRecentId(String id) async {
    final next = <String>[id, ..._recentIds.where((e) => e != id)];
    if (next.length > _maxRecentIds) next.removeLast();
    setState(() => _recentIds = next);
    await _bridge.setOption('godesk-recent-ids', next.join('\n'));
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(_copiedId ? Icons.check : Icons.content_copy_outlined, size: 12),
                          const SizedBox(width: 4),
                          Text(_copiedId ? 'COPIED' : 'COPY ID'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TactileButton(
                      onPressed: _identity == null || _password.isEmpty ? null : _openInviteManager,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.link, size: 12),
                          SizedBox(width: 4),
                          Text('INVITE LINKS'),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(_showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 11),
                          const SizedBox(width: 4),
                          Text(_showPw ? 'HIDE' : 'SHOW'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TactileButton(
                      small: true,
                      onPressed: () => setState(() => _password = genPassword()),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.refresh, size: 11),
                          SizedBox(width: 4),
                          Text('NEW'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TactileButton(
                      small: true,
                      onPressed: _copyPw,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(_copiedPw ? Icons.check : Icons.content_copy_outlined, size: 11),
                          const SizedBox(width: 4),
                          Text(_copiedPw ? 'OK' : 'COPY'),
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
                  // Recent-IDs dropdown — RuDesktop "Последние сеансы" parity
                  // surfaced as a compact button on the connect input.
                  if (_recentIds.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      tooltip: 'Recent IDs',
                      offset: const Offset(0, 38),
                      onSelected: (id) {
                        _peerInput.value = TextEditingValue(
                          text: id,
                          selection: TextSelection.collapsed(offset: id.length),
                        );
                        setState(() {});
                        _attemptConnect();
                      },
                      itemBuilder: (ctx) => <PopupMenuEntry<String>>[
                        for (final id in _recentIds)
                          PopupMenuItem<String>(
                            value: id,
                            child: Text(id, style: GDtype.mono(size: 12)),
                          ),
                      ],
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[t.panelHi, t.panel],
                          ),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: t.border),
                        ),
                        child: Icon(Icons.history, size: 16, color: t.body),
                      ),
                    ),
                  ],
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
              // Six connection modes — three primary + three RuDesktop-style
              // advanced (TCP / RDP / Terminal). Wrap so they reflow on
              // narrow viewports instead of clipping.
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  _modeChip(t, 'View only', ConnectMode.viewOnly),
                  _modeChip(t, 'Full control', ConnectMode.fullControl),
                  _modeChip(t, 'File transfer', ConnectMode.fileTransfer),
                  _modeChip(t, 'TCP tunnel', ConnectMode.portForward),
                  _modeChip(t, 'RDP', ConnectMode.rdp),
                  _modeChip(t, 'Terminal', ConnectMode.terminal),
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
                      _abTabPill(t, label: 'SAVED', tab: 'saved'),
                      const SizedBox(width: 6),
                      _abTabPill(t, label: 'LAN', tab: 'lan'),
                      const Spacer(),
                      if (_abTab == 'lan')
                        TactileButton(
                          small: true,
                          onPressed: () => _bridge.triggerLanDiscovery(),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.refresh, size: 11),
                              SizedBox(width: 4),
                              Text('SCAN'),
                            ],
                          ),
                        )
                      else ...<Widget>[
                        TactileButton(
                          small: true,
                          onPressed: _addPeerDialog,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.add, size: 11),
                              SizedBox(width: 4),
                              Text('ADD'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _sortMenu(t),
                        const SizedBox(width: 6),
                        _entriesPlate(t),
                      ],
                    ],
                  ),
                  if (_abTab == 'saved' && _peers.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    _searchBar(t),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _abTab == 'lan' ? _buildLanList(t) : _buildPeerList(t),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortMenu(GoDeskTheme t) {
    final label = switch (_sort) {
      PeerSort.recent => 'RECENT',
      PeerSort.name => 'A → Z',
      PeerSort.favoritesFirst => 'FAVS',
    };
    return PopupMenuButton<PeerSort>(
      tooltip: 'Sort address book',
      onSelected: _setSort,
      offset: const Offset(0, 24),
      itemBuilder: (_) => <PopupMenuEntry<PeerSort>>[
        CheckedPopupMenuItem<PeerSort>(
          value: PeerSort.recent,
          checked: _sort == PeerSort.recent,
          child: const Text('Most recent'),
        ),
        CheckedPopupMenuItem<PeerSort>(
          value: PeerSort.name,
          checked: _sort == PeerSort.name,
          child: const Text('Name (A → Z)'),
        ),
        CheckedPopupMenuItem<PeerSort>(
          value: PeerSort.favoritesFirst,
          checked: _sort == PeerSort.favoritesFirst,
          child: const Text('Favorites first'),
        ),
      ],
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: t.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.swap_vert, size: 11, color: t.subtle),
            const SizedBox(width: 4),
            Text(
              label,
              style: GDtype.mono(
                  size: 9, weight: FontWeight.w700, color: t.subtle, letterSpacing: 0.5),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 12, color: t.subtle),
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

  Widget _abTabPill(GoDeskTheme t, {required String label, required String tab}) {
    final active = _abTab == tab;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _abTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[t.accent, t.accentDark],
                  )
                : null,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: active ? t.accentDark : t.border),
          ),
          child: Text(
            label,
            style: GDtype.wordmark(
              size: 9,
              color: active ? Colors.white : t.subtle,
              trackingEm: 0.08,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanList(GoDeskTheme t) {
    if (_lanPeers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.lan_outlined, size: 32, color: t.subtle.withValues(alpha: 0.5)),
              const SizedBox(height: 10),
              Text('No LAN peers found yet',
                  style: GDtype.ui(size: 12, weight: FontWeight.w600, color: t.body)),
              const SizedBox(height: 4),
              Text('Tap SCAN to broadcast a discovery probe.',
                  textAlign: TextAlign.center,
                  style: GDtype.ui(size: 10, color: t.subtle).copyWith(height: 1.4)),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _lanPeers.length,
      itemBuilder: (context, i) => _PeerRow(
        peer: _lanPeers[i],
        isLast: i == _lanPeers.length - 1,
        onTap: () => widget.onConnect(_lanPeers[i]),
        onEditAlias: () {}, // LAN peers aren't in the address book yet.
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
  viewOnly('view-only', 'View only'),
  fullControl('full-control', 'Full control'),
  fileTransfer('file-transfer', 'File transfer'),
  // Less-common modes mirroring RuDesktop's CONNECT-button dropdown.
  // FFI maps these onto sessionAddSync flags: isPortForward / isRdp /
  // isTerminal. Backend support already exists in upstream's flutter_ffi.rs.
  portForward('port-forward', 'TCP tunnel'),
  rdp('rdp', 'RDP'),
  terminal('terminal', 'Terminal');

  const ConnectMode(this.wireValue, this.label);
  final String wireValue;
  final String label;
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
              'No saved peers yet',
              style: GDtype.ui(size: 12, weight: FontWeight.w600, color: theme.body),
            ),
            const SizedBox(height: 4),
            Text(
              'Connect to a remote machine using its 9-digit ID and it will appear here.',
              textAlign: TextAlign.center,
              style: GDtype.ui(size: 10, color: theme.subtle).copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

