// Files screen — VU meters, transfer queue, completed list.
// Port of godesk-skeuo-files.jsx.

import 'package:flutter/material.dart';

import '../bridge/bridge.dart';
import '../bridge/provider.dart';
import '../data/transfers.dart';
import '../kit/_internal/inset_painter.dart';
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

  Bridge get _bridge => BridgeProvider.of(context);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return StreamBuilder<List<TransferItem>>(
      stream: _bridge.transfers(),
      initialData: const <TransferItem>[],
      builder: (context, snap) {
        final queue = snap.data ?? const <TransferItem>[];
        final active = queue.where((q) => !q.done && !q.queued).toList();
        final sendSpeed = active.where((q) => q.dir == TransferDir.send).fold<int>(0, (s, q) => s + q.speed);
        final recvSpeed = active.where((q) => q.dir == TransferDir.receive).fold<int>(0, (s, q) => s + q.speed);
        final totalSpeed = sendSpeed + recvSpeed;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 280,
                  child: SingleChildScrollView(
                    child: _leftColumn(t, sendSpeed, recvSpeed, totalSpeed),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: _rightColumn(t, queue)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _leftColumn(GoDeskTheme t, int sendSpeed, int recvSpeed, int totalSpeed) {
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
              LCDPanel(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('> PEER', style: lcdDimLabel(theme: t)),
                    const SizedBox(height: 2),
                    Text('build-runner-03', style: lcdReadout(theme: t, size: 12)),
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
                children: const <Widget>[
                  _ConnFlag(label: 'Encrypted', on: true),
                  _ConnFlag(label: 'Direct P2P', on: true),
                  _ConnFlag(label: 'Compressed', on: true),
                  _ConnFlag(label: 'Resume', on: false),
                ],
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
              TactileButton(
                variant: TactileVariant.primary,
                onPressed: () {},
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
                onPressed: () {},
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
                onPressed: () {},
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
                        const StatusLED(color: LEDColors.online, pulse: true, size: 6),
                        const SizedBox(width: 5),
                        Text('TRANSFERRING',
                            style: GDtype.ui(size: 9, weight: FontWeight.w700, color: t.subtle, letterSpacing: 0.9)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: queue.length,
                      itemBuilder: (context, i) => _TransferRow(
                        item: queue[i],
                        isLast: i == queue.length - 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const SectionLabel('Recent'),
                  const Spacer(),
                  Text('${completedItems.length} files',
                      style: GDtype.mono(size: 10, color: t.subtle)),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < completedItems.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    border: i < completedItems.length - 1
                        ? Border(bottom: BorderSide(color: t.border, width: 0.5))
                        : null,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.check, size: 11, color: Color(0xFF22A843)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(completedItems[i].name,
                            style: GDtype.mono(size: 11, weight: FontWeight.w600, color: t.heading)),
                      ),
                      const SizedBox(width: 8),
                      Text(formatBytes(completedItems[i].size),
                          style: GDtype.mono(size: 10, color: t.subtle)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: Text(completedItems[i].time,
                            textAlign: TextAlign.right,
                            style: GDtype.ui(size: 10, color: t.subtle)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
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
  const _TransferRow({required this.item, required this.isLast});
  final TransferItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final pct = item.progress.clamp(0.0, 1.0);
    final isReceive = item.dir == TransferDir.receive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: t.border, width: 0.5)),
      ),
      child: Row(
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
            _CancelChip(),
          ],
        ],
      ),
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
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return Container(
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
    );
  }
}
