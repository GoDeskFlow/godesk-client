// Knob — 64 × 64 rotary knob.
// Direct port of `Knob` from godesk-skeuo-screens.jsx.
//
// Mark rotates from −135° to +135° around (value/100). Five tick marks at
// 0/25/50/75/100. Click increments value by 10 (mod 110); a real
// implementation supports drag — added here as a vertical-drag that maps
// 100 px of upward drag = full sweep.
//
// LCD readout for the value sits next to the knob (handled by caller).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/godesk_theme.dart';

class Knob extends StatefulWidget {
  const Knob({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 0..100
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<Knob> createState() => _KnobState();
}

class _KnobState extends State<Knob> {
  double? _dragStartValue;
  double? _dragStartY;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final angle = (-135 + (widget.value / 100) * 270) * math.pi / 180;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            widget.onChanged(((widget.value + 10) % 110).clamp(0.0, 100.0)),
        onVerticalDragStart: (d) {
          _dragStartValue = widget.value;
          _dragStartY = d.globalPosition.dy;
        },
        onVerticalDragUpdate: (d) {
          if (_dragStartValue == null || _dragStartY == null) return;
          final delta = (_dragStartY! - d.globalPosition.dy);
          final v = (_dragStartValue! + delta).clamp(0.0, 100.0);
          widget.onChanged(v);
        },
        onVerticalDragEnd: (_) {
          _dragStartValue = null;
          _dragStartY = null;
        },
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Body (radial gradient + tick marks, painted statically).
              Positioned.fill(
                child: CustomPaint(painter: _KnobPainter(theme: t)),
              ),
              // Mark — single rotation via AnimatedRotation. The painter draws
              // the mark in its un-rotated position (anchored to the top of the
              // 64×64 box) and AnimatedRotation spins it around the box centre.
              // Earlier port double-rotated (Transform.rotate + canvas.rotate),
              // which threw the mark off the dial.
              Positioned.fill(
                child: AnimatedRotation(
                  turns: angle / (2 * math.pi),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: CustomPaint(
                    painter: _MarkPainter(
                      color: t.accent,
                      glow: t.accentGlow,
                    ),
                  ),
                ),
              ),
              // Center recess dot — sits ON TOP of the mark so the mark
              // appears to emerge from the recess.
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[t.bg, t.panel],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                      spreadRadius: -1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  const _KnobPainter({required this.theme});
  final GoDeskTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Body — radial gradient (darker rim, lit top-left).
    final body = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4), // ~ "circle at 35% 30%"
        radius: 0.85,
        colors: <Color>[
          theme.panelHi,
          theme.panel,
          theme.dark ? const Color(0xFF1A1C20) : const Color(0xFFA8A298),
        ],
        stops: const <double>[0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r - 0.5, body);

    // Outer rim border.
    final border = Paint()
      ..color = theme.border
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(c, r - 0.5, border);

    // Drop shadow under the knob (faint).
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(c.translate(0, 4), r - 1, shadow);

    // Tick marks at 0, 25, 50, 75, 100.
    final tick = Paint()
      ..color = theme.subtle
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final v in <int>[0, 25, 50, 75, 100]) {
      final a = (-135 + (v / 100) * 270 - 90) * math.pi / 180;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * 30;
      final p2 = c + Offset(math.cos(a), math.sin(a)) * 33;
      canvas.drawLine(p1, p2, tick);
    }
  }

  @override
  bool shouldRepaint(_KnobPainter old) => old.theme.dark != theme.dark;
}

/// Static mark painter — draws the indicator stripe at the TOP of the
/// 64×64 box. Rotation is provided by the parent `AnimatedRotation`, which
/// rotates around the box centre — so the mark sweeps cleanly along the
/// dial's outer edge. JSX equivalent: a 3×16 stripe at top:4 with
/// transformOrigin "50% 28px" (i.e. the parent box centre).
class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.color, required this.glow});
  final Color color;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    // Mark anchored to the top of the box: 3px wide, 16px tall, top inset 4px.
    final markRect = Rect.fromLTWH(size.width / 2 - 1.5, 4, 3, 16);
    final rrect = RRect.fromRectAndRadius(markRect, const Radius.circular(1.5));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = glow.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(rrect, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color || old.glow != glow;
}
