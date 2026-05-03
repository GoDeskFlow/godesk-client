// 1px dashed horizontal divider — direct port of CSS
//   `borderBottom: 1px dashed ${t.border}`
// from godesk-skeuo-home.jsx + godesk-skeuo-files.jsx.
//
// Flutter's BoxDecoration.border doesn't support dashed strokes natively, so
// the reference's "lighter" look (peer rows, diagnostics, transfer queue)
// fell back to solid lines in the first port. This widget paints the dashed
// stripe via CustomPaint at row baseline.

import 'package:flutter/material.dart';

import '../theme/godesk_theme.dart';

class DashedDivider extends StatelessWidget {
  const DashedDivider({
    super.key,
    this.dashWidth = 3,
    this.gapWidth = 3,
    this.thickness = 0.5,
    this.color,
    this.height = 1,
  });

  final double dashWidth;
  final double gapWidth;
  final double thickness;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedLinePainter(
          color: color ?? t.border,
          dashWidth: dashWidth,
          gapWidth: gapWidth,
          thickness: thickness,
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({
    required this.color,
    required this.dashWidth,
    required this.gapWidth,
    required this.thickness,
  });
  final Color color;
  final double dashWidth;
  final double gapWidth;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      final end = (x + dashWidth).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) =>
      old.color != color ||
      old.dashWidth != dashWidth ||
      old.gapWidth != gapWidth ||
      old.thickness != thickness;
}
