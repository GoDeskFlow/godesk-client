// Files screen — VU meters, transfer queue, completed list.
// Port of godesk-skeuo-files.jsx.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bridge/bridge.dart';
import '../bridge/provider.dart';
import '../data/transfers.dart';
import '../kit/_internal/inset_painter.dart';
import '../kit/dashed_divider.dart';
import '../kit/lcd_panel.dart';
import '../kit/metal_panel.dart';
import '../kit/section_label.dart';
import '../kit/status_led.dart';
import '../kit/tactile_button.dart';
import '../kit/vu_meter.dart';
import '../theme/godesk_theme.dart';
import '../theme/typography.dart';
import '../util/format.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  static const int _peakSpeed = 25000000;

  /// Currently-selected transfer id — driven by tap on a row, used by the
  /// `Delete` hotkey to know which transfer to cancel. RuDesktop 2.7.982 parity.
  int? _selectedId;

  final FocusNode _focus = FocusNode();

  Bridge get _bridge => BridgeProvider.of(context);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Open the OS file picker (or directory picker if [folder] is true) and
  /// hand each chosen path to the bridge. Picker package is added in pubspec
  /// alongside RealBridge wiring; for now the click feedback is a snackbar
  /// Opens an OS file/dir picker, then queues each selected path through the
  /// bridge. Pre-flight check: needs an active session, otherwise just
  /// surfaces a hint via SnackBar instead of silently failing.
  Future<void> _addFiles({required bool folder}) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final inSession = (await _bridge.sessionState().first).inSession;
    if (!inSession) {
      messenger?.showSnackBar(const SnackBar(
        duration: Duration(milliseconds: 2200),
        content: Text('Connect to a peer first — file transfer needs an active session.'),
      ));
      return;
    }
    if (folder) {
      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null) return;
      await _bridge.addTransfer(filePath: path, dir: TransferDir.send);
    } else {
      final res = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (res == null) return;
      for (final f in res.files) {
        if (f.path != null) {
          await _bridge.addTransfer(filePath: f.path!, dir: TransferDir.send);
        }
      }
    }
  }

  /// Folder-first sort within each segment (active → queued → done), then by id
  /// for stable order. RuDesktop 2.8.1532 parity.
  List<TransferItem> _sortQueue(List<TransferItem> q) {
    int segment(TransferItem i) {
      if (i.done) return 2;
      if (i.queued) return 1;
      return 0;
    }
    final out = List<TransferItem>.from(q);
    out.sort((a, b) {
      final s = segment(a) - segment(b);
      if (s != 0) return s;
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.id - b.id;
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return StreamBuilder<List<TransferItem>>(
      stream: _bridge.transfers(),
      initialData: const <TransferItem>[],
      builder: (context, snap) {
        final queue = _sortQueue(snap.data ?? const <TransferItem>[]);
        final active = queue.where((q) => !q.done && !q.queued).toList();
        final sendSpeed = active.where((q) => q.dir == TransferDir.send).fold<int>(0, (s, q) => s + q.speed);
        final recvSpeed = active.where((q) => q.dir == TransferDir.receive).fold<int>(0, (s, q) => s + q.speed);
        final totalSpeed = sendSpeed + recvSpeed;
        return Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.delete): _CancelTransferIntent(),
            SingleActivator(LogicalKeyboardKey.backspace, meta: true): _CancelTransferIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _CancelTransferIntent: CallbackAction<_CancelTransferIntent>(
                onInvoke: (_) {
                  final id = _selectedId;
                  if (id == null) return null;
                  final item = queue.cast<TransferItem?>().firstWhere(
                        (q) => q?.id == id,
                        orElse: () => null,
                      );
                  if (item == null || item.done) return null;
                  _bridge.cancelTransfer(id);
                  setState(() => _selectedId = null);
                  return null;
                },
              ),
            },
            child: Focus(
              focusNode: _focus,
              autofocus: true,
              child: DecoratedBox(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 280,
                        child: SingleChildScrollView(
                          child: _leftColumn(t, sendSpeed, recvSpeed, totalSpeed, queue),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: _rightColumn(t, queue)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _leftColumn(GoDeskTheme t, int sendSpeed, int recvSpeed, int totalSpeed, List<TransferItem> queue) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Throughput'),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  VUMeter(value: sendSpeed / _peakSpeed, label: '↑ TX'),
                  VUMeter(value: recvSpeed / _peakSpeed, label: '↓ RX', color: t.lcdInk),
                ],
              ),
              const SizedBox(height: 10),
              LCDPanel(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: <Widget>[
                    Text('TOTAL', style: lcdDimLabel(theme: t)),
                    const Spacer(),
                    Text('${formatBytes(totalSpeed)}/s',
                        style: lcdReadout(theme: t, size: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Connection'),
              const SizedBox(height: 10),
              StreamBuilder<SessionState>(
                stream: _bridge.sessionState(),
                initialData: const SessionState(),
                builder: (context, snap) {
                  final inSession = snap.data?.inSession ?? false;
                  final peerLabel = snap.data?.peerId ?? '—';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      LCDPanel(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('> PEER', style: lcdDimLabel(theme: t)),
                            const SizedBox(height: 2),
                            Text(
                              inSession ? peerLabel : 'No active session',
                              style: lcdReadout(theme: t, size: 12)
                                  .copyWith(color: inSession ? null : t.lcdDim),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 4.4,
                        children: <Widget>[
                          _ConnFlag(label: 'Encrypted', on: inSession),
                          _ConnFlag(label: 'Direct P2P', on: inSession),
                          _ConnFlag(label: 'Compressed', on: inSession),
                          const _ConnFlag(label: 'Resume', on: false),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Align(
                alignment: Alignment.centerLeft,
                child: SectionLabel('Actions'),
              ),
              const SizedBox(height: 10),
              // Actions are always clickable — the previous "disabled outside
              // a session" UX was opaque (greyed-out icons looked like broken
              // glyphs and clicks did nothing). The buttons now always give
              // feedback: a snackbar explains the picker wires up alongside
              // RealBridge in Phase 2.4. CLEAR COMPLETED stays conditional —
              // there's no honest action to take when nothing's done.
              TactileButton(
                variant: TactileVariant.primary,
                onPressed: () => _addFiles(folder: false),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.add, size: 12),
                    SizedBox(width: 4),
                    Text('ADD FILES'),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TactileButton(
                onPressed: () => _addFiles(folder: true),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.folder_outlined, size: 12),
                    SizedBox(width: 4),
                    Text('ADD FOLDER'),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TactileButton(
                small: true,
                onPressed: queue.any((q) => q.done) ? () => _bridge.clearCompleted() : null,
                child: const Text('CLEAR COMPLETED'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rightColumn(GoDeskTheme t, List<TransferItem> queue) {
    final activeCount = queue.where((q) => !q.done).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Transfer queue panel
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: t.panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9.5),
              child: Column(
                children: <Widget>[
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
                        const SectionLabel('Transfer Queue'),
                        const SizedBox(width: 12),
                        _activePlate(t, activeCount),
                        const Spacer(),
                        StatusLED(
                          color: activeCount > 0 ? LEDColors.online : LEDColors.offline,
                          pulse: activeCount > 0,
                          size: 6,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          activeCount > 0 ? 'TRANSFERRING' : 'IDLE',
                          style: GDtype.ui(size: 9, weight: FontWeight.w700, color: t.subtle, letterSpacing: 0.9),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: queue.isEmpty
                        ? _TransferQueueEmpty(theme: t)
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: queue.length,
                            itemBuilder: (context, i) => _TransferRow(
                              item: queue[i],
                              isLast: i == queue.length - 1,
                              selected: _selectedId == queue[i].id,
                              onTap: () {
                                setState(() => _selectedId = queue[i].id);
                                _focus.requestFocus();
                              },
                              onCancel: () => _bridge.cancelTransfer(queue[i].id),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // RECENT — completed transfers from THIS session. completedItems is
        // demo-only (mock GODESK_DEMO data); production builds show empty
        // state until a real transfer completes. Without RealBridge there's
        // no persistent history yet; once it's wired, this list reads from
        // bridge.completedTransfers().
        _RecentPanel(theme: t, items: const <CompletedItem>[]),
      ],
    );
  }

  Widget _activePlate(GoDeskTheme t, int n) {
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
              '$n ACTIVE',
              style: GDtype.mono(size: 9, weight: FontWeight.w700, color: t.subtle, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnFlag extends StatelessWidget {
  const _ConnFlag({required this.label, required this.on});
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: t.dark ? const Color(0x33000000) : const Color(0x0A000000),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: <Widget>[
          StatusLED(color: on ? LEDColors.online : LEDColors.offline, size: 6, pulse: on),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: GDtype.ui(size: 10, weight: FontWeight.w600, color: on ? t.heading : t.subtle),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.item,
    required this.isLast,
    this.selected = false,
    this.onTap,
    this.onCancel,
  });
  final TransferItem item;
  final bool isLast;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: selected ? t.accent.withValues(alpha: t.dark ? 0.15 : 0.08) : null,
              child: _rowBody(t),
            ),
            if (!isLast)
              const Positioned(
                left: 14, right: 14, bottom: 0,
                child: IgnorePointer(child: DashedDivider(height: 1)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rowBody(GoDeskTheme t) {
    final pct = item.progress.clamp(0.0, 1.0);
    final isReceive = item.dir == TransferDir.receive;
    return Row(
            children: <Widget>[
              // direction tile
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: item.done
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Color(0xFF34D058), Color(0xFF22A843)],
                        )
                      : item.queued
                          ? LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[t.panelHi, t.panel],
                            )
                          : LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[t.accent, t.accentDark],
                            ),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: item.done
                        ? const Color(0xFF22A843)
                        : item.queued
                            ? t.border
                            : t.accentDark,
                  ),
                ),
                child: Icon(
                  item.done
                      ? Icons.check
                      : item.isFolder
                          ? Icons.folder_outlined
                          : isReceive
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                  size: 14,
                  color: item.queued ? t.subtle : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                            style: GDtype.mono(size: 12, weight: FontWeight.w600, color: t.heading),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _ExtChip(item: item, theme: t),
                        const SizedBox(width: 8),
                        Text(formatBytes(item.size),
                            style: GDtype.mono(size: 10, color: t.subtle)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _ProgressBar(pct: pct, done: item.done, theme: t),
                    const SizedBox(height: 4),
                    _statusLine(t, item),
                  ],
                ),
              ),
              if (!item.done) ...<Widget>[
                const SizedBox(width: 12),
                _CancelChip(onTap: onCancel),
              ],
            ],
    );
  }

  Widget _statusLine(GoDeskTheme t, TransferItem item) {
    if (item.done) {
      return Text('✓ COMPLETE',
          style: GDtype.mono(size: 10, weight: FontWeight.w700, color: const Color(0xFF22A843)));
    }
    if (item.queued) {
      return Text('QUEUED', style: GDtype.mono(size: 10, color: t.subtle));
    }
    return Text(
      '${formatBytes(item.sent)} / ${formatBytes(item.size)}  ·  ${formatBytes(item.speed)}/s  ·  ${item.eta}s left',
      style: GDtype.mono(size: 10, color: t.subtle),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.pct, required this.done, required this.theme});
  final double pct;
  final bool done;
  final GoDeskTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: theme.lcdBg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: theme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2.5),
        child: Stack(
          children: <Widget>[
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  gradient: done
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Color(0xFF34D058), Color(0xFF22A843)],
                        )
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[theme.lcdInk, theme.lcdInk.withValues(alpha: 2 / 3)],
                        ),
                  boxShadow: done
                      ? const <BoxShadow>[]
                      : <BoxShadow>[
                          BoxShadow(
                            color: theme.lcdInk.withValues(alpha: 2 / 3),
                            blurRadius: 6,
                          ),
                        ],
                ),
              ),
            ),
            // segment ticks
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      tileMode: TileMode.repeated,
                      colors: <Color>[
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.2),
                      ],
                      stops: const <double>[0.0, 0.8, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelChip extends StatelessWidget {
  const _CancelChip({this.onTap});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Tooltip(
          message: 'Cancel transfer (Del)',
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
            child: Icon(Icons.close, size: 12, color: t.body),
          ),
        ),
      ),
    );
  }
}

/// Small monospace chip showing the file extension (or "DIR" for folders).
/// Renders nothing for extensionless files.
class _ExtChip extends StatelessWidget {
  const _ExtChip({required this.item, required this.theme});
  final TransferItem item;
  final GoDeskTheme theme;

  @override
  Widget build(BuildContext context) {
    final label = item.isFolder ? 'DIR' : item.extension.toUpperCase();
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: theme.border),
      ),
      child: Text(
        label,
        style: GDtype.mono(
          size: 9,
          weight: FontWeight.w700,
          color: theme.subtle,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Hotkey intent — `Delete` cancels the currently-selected active transfer.
class _CancelTransferIntent extends Intent {
  const _CancelTransferIntent();
}

/// "Recent" — completed transfers panel. Empty state explains the lack of
/// data instead of showing demo files in production.
class _RecentPanel extends StatelessWidget {
  const _RecentPanel({required this.theme, required this.items});
  final GoDeskTheme theme;
  final List<CompletedItem> items;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return MetalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const SectionLabel('Recent'),
              const Spacer(),
              Text(
                items.isEmpty ? 'no history' : '${items.length} files',
                style: GDtype.mono(size: 10, color: t.subtle),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Completed transfers will appear here.',
                style: GDtype.ui(size: 10, color: t.subtle),
              ),
            )
          else
            for (var i = 0; i < items.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  border: i < items.length - 1
                      ? Border(bottom: BorderSide(color: t.border, width: 0.5))
                      : null,
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.check, size: 11, color: Color(0xFF22A843)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(items[i].name,
                          style: GDtype.mono(size: 11, weight: FontWeight.w600, color: t.heading)),
                    ),
                    const SizedBox(width: 8),
                    Text(formatBytes(items[i].size),
                        style: GDtype.mono(size: 10, color: t.subtle)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: Text(items[i].time,
                          textAlign: TextAlign.right,
                          style: GDtype.ui(size: 10, color: t.subtle)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _TransferQueueEmpty extends StatelessWidget {
  const _TransferQueueEmpty({required this.theme});
  final GoDeskTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.folder_open_outlined, size: 32, color: theme.subtle.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            Text(
              'No active transfers',
              style: GDtype.ui(size: 12, weight: FontWeight.w600, color: theme.body),
            ),
            const SizedBox(height: 4),
            Text(
              'Drag files into the window during an active session, or use ADD FILES on the left.',
              textAlign: TextAlign.center,
              style: GDtype.ui(size: 10, color: theme.subtle).copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
