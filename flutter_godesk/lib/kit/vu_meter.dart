// VUMeter — 110 × 80 analog meter.
// Direct port of `VUMeter` from godesk-skeuo-files.jsx.
//
// Visual recipe:
//   - Recessed LCD-bg background.
//   - SVG arc with tick marks (10 ticks, denser on the right).
//   - Red warning-zone arc on the right third.
//   - Needle sweeps −45° ↔ +45° based on value (0..1).
//   - Drop-shadow on needle for glow.
//   - Springy easing on transition: cubic-bezier(0.34, 1.56, 0.64, 1).
//   - Caption under the meter (label + numeric readout).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/godesk_theme.dart';
import '../theme/typography.dart';

class VUMeter extends StatelessWidget {
  const VUMeter({
    required this.value,
    required this.label,
    this.color,
    super.key,
  });

  /// 0.0 .. 1.0
  final double value;
  final String label;

  /// Optional needle color. Defaults to `theme.accent`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final clamped = value.clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 110,
          height: 80,
          decoration: BoxDecoration(
            color: t.lcdBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: t.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(0, 2),
                blurRadius: 4,
                spreadRadius: -1,
              ),
            ],
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: clamped),
            duration: const Duration(milliseconds: 400),
            // cubic-bezier(0.34, 1.56, 0.64, 1) ≈ Curves.elasticOut at small amplitude
            curve: const Cubic(0.34, 1.56, 0.64, 1),
            builder: (context, v, _) => CustomPaint(
              painter: _VUPainter(
                value: v,
                ink: t.lcdInk,
                dim: t.lcdDim,
                needle: color ?? t.accent,
                warning: const Color(0xFFE25555),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: GDtype.sectionLabel(color: t.subtle),
        ),
      ],
    );
  }
}

class _VUPainter extends CustomPainter {
  const _VUPainter({
    required this.value,
    required this.ink,
    required this.dim,
    required this.needle,
    required this.warning,
  });

  final double value;
  final Color ink;
  final Color dim;
  final Color needle;
  final Color warning;

  @override
  void paint(Canvas canvas, Size size) {
    // JSX reference (godesk-skeuo-files.jsx) places the SVG with viewBox
    // 100×56 inside a 110×80 container at top:6. The needle and the pivot
    // circle both anchor at viewBox (50, 50) — so in container pixels the
    // pivot lives at (~width/2, ~56) and the needle radius is 36.
    //
    // Earlier port placed the pivot at (width/2, height+10) — i.e. 10 px
    // BELOW the visible box bottom — while drawing the pivot dot at
    // (width/2, height-4) inside the box. That left a 14 px gap between
    // the visible base of the needle and the dot the user expects it to
    // emerge from. Aligning both to the same point fixes it.
    final pivot = Offset(size.width / 2, size.height * 0.7);
    const radius = 42.0;

    // Arc (whole sweep) — dim color.
    final arcRect = Rect.fromCircle(center: pivot, radius: radius);
    final arcPaint = Paint()
      ..color = dim
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawArc(arcRect, math.pi + math.pi / 4, math.pi / 2, false, arcPaint);

    // Warning zone — right third of the sweep.
    final warnPaint = Paint()
      ..color = warning.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      arcRect,
      math.pi + math.pi / 4 + math.pi / 3,
      math.pi / 6,
      false,
      warnPaint,
    );

    // Tick marks just outside the arc.
    final tickPaint = Paint()
      ..color = dim
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var i = 0; i <= 10; i++) {
      final t = i / 10.0;
      final a = math.pi + math.pi / 4 + (math.pi / 2) * t;
      final p1 = pivot + Offset(math.cos(a), math.sin(a)) * radius;
      final p2 = pivot + Offset(math.cos(a), math.sin(a)) * (radius + 3);
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Needle with glow — starts AT pivot, length ~36.
    final na = math.pi + math.pi / 4 + (math.pi / 2) * value;
    final nEnd = pivot + Offset(math.cos(na), math.sin(na)) * 36.0;
    final glowPaint = Paint()
      ..color = needle.withValues(alpha: 0.6)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(pivot, nEnd, glowPaint);
    final needlePaint = Paint()
      ..color = needle
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pivot, nEnd, needlePaint);

    // Pivot dot — same coordinate as needle origin.
    canvas.drawCircle(pivot, 3, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_VUPainter old) => old.value != value || old.needle != needle;
}
