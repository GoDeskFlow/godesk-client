// ConnectingOverlay — fake remote desktop connection flow.
// Port of godesk-connecting.jsx.

import 'dart:async';

import 'package:flutter/material.dart';

import '../bridge/bridge.dart';
import '../bridge/provider.dart';
import '../theme/godesk_theme.dart';
import '../theme/typography.dart';
import '../util/a11y.dart';

class ConnectingOverlay extends StatefulWidget {
  const ConnectingOverlay({
    required this.peerId,
    required this.onCancel,
    required this.onComplete,
    this.mode,
    super.key,
  });

  final String peerId;
  final VoidCallback onCancel;
  final VoidCallback onComplete;
  final String? mode;

  @override
  State<ConnectingOverlay> createState() => _ConnectingOverlayState();
}

class _ConnectingOverlayState extends State<ConnectingOverlay>
    with TickerProviderStateMixin {
  static const _stages = <String>[
    'Resolving relay…',
    'Establishing P2P tunnel…',
    'Verifying identity…',
    'Connected',
  ];
  int _stage = 0;
  StreamSubscription<ConnectEvent>? _sub;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= BridgeProvider.of(context).connectEvents().listen(_onEvent);
    // Trigger the bridge to start the connect flow once.
    if (!_started) {
      _started = true;
      BridgeProvider.of(context).connect(widget.peerId, mode: widget.mode);
    }
  }

  bool _started = false;

  void _onEvent(ConnectEvent e) {
    if (!mounted) return;
    final newStage = switch (e.stage) {
      ConnectStage.resolving => 0,
      ConnectStage.tunnel => 1,
      ConnectStage.authenticating => 2,
      ConnectStage.connected => 3,
      ConnectStage.failed => _stage,
    };
    setState(() => _stage = newStage);
    if (e.stage == ConnectStage.connected) {
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted) widget.onComplete();
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final reduced = reducedMotion(context);
    if (reduced && _pulse.isAnimating) _pulse.stop();
    return Container(
      color: t.bg.withValues(alpha: 0.94),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Pulsing radar.
            SizedBox(
              width: 110,
              height: 110,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  if (reduced) {
                    return _StaticRadarCenter(color: t.accent);
                  }
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      _PulseRing(progress: _pulse.value, color: t.accent, baseRadius: 30),
                      _PulseRing(progress: ((_pulse.value + 0.3) % 1.0), color: t.accent, baseRadius: 18),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: t.accent,
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(color: t.accent.withValues(alpha: 1 / 3), blurRadius: 24, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: const Icon(Icons.computer_outlined, size: 28, color: Colors.white),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text('CONNECTING TO',
                style: GDtype.ui(size: 13, weight: FontWeight.w500, color: t.subtle, letterSpacing: 0.65)),
            const SizedBox(height: 8),
            Text(widget.peerId,
                style: GDtype.mono(size: 22, weight: FontWeight.w600, color: t.heading, letterSpacing: 0.44)),
            const SizedBox(height: 24),
            SizedBox(
              width: 280,
              child: Column(
                children: <Widget>[
                  for (var i = 0; i < _stages.length; i++)
                    Opacity(
                      opacity: i > _stage ? 0.35 : 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: <Widget>[
                            _StageDot(theme: t, state: _dotState(i)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _stages[i],
                                style: GDtype.ui(
                                  size: 13,
                                  color: i <= _stage ? t.heading : t.subtle,
                                  weight: i == _stage ? FontWeight.w500 : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onCancel,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: t.border),
                  ),
                  child: Text(
                    'Cancel',
                    style: GDtype.ui(size: 13, weight: FontWeight.w500, color: t.subtle),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _DotState _dotState(int i) {
    if (i < _stage) return _DotState.done;
    if (i == _stage) return _DotState.current;
    return _DotState.pending;
  }
}

enum _DotState { pending, current, done }

class _StageDot extends StatelessWidget {
  const _StageDot({required this.theme, required this.state});
  final GoDeskTheme theme;
  final _DotState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: state == _DotState.done ? theme.accent : Colors.transparent,
        border: Border.all(
          color: state == _DotState.pending ? theme.border : theme.accent,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: state == _DotState.done
          ? const Icon(Icons.check, size: 10, color: Colors.white)
          : state == _DotState.current
              ? Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
    );
  }
}

class _StaticRadarCenter extends StatelessWidget {
  const _StaticRadarCenter({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(color: color.withValues(alpha: 1 / 3), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: const Icon(Icons.computer_outlined, size: 28, color: Colors.white),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({
    required this.progress,
    required this.color,
    required this.baseRadius,
  });
  final double progress;
  final Color color;
  final double baseRadius;

  @override
  Widget build(BuildContext context) {
    final scale = 1.0 + progress * 0.6; // 1 → 1.6
    final opacity = (1 - progress) * 0.5;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: baseRadius * 2,
        height: baseRadius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: opacity), width: 2),
        ),
      ),
    );
  }
}
