// SkeuoLogo — small 16-px brand mark used in title bar.
// Direct port of `SkeuoLogo` from godesk-skeuo-chrome.jsx.
//
// Rounded square with accent gradient + top highlight + white play-triangle.

import 'package:flutter/material.dart';

import '../theme/godesk_theme.dart';

class SkeuoLogo extends StatelessWidget {
  const SkeuoLogo({this.size = 16, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(accent: t.accent, accentDark: t.accentDark),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.accent, required this.accentDark});
  final Color accent;
  final Color accentDark;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    final rect = Rect.fromLTWH(2 * scale, 2 * scale, 20 * scale, 20 * scale);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(4 * scale));

    // Accent gradient body.
    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[accent, accentDark],
      ).createShader(rect);
    canvas.drawRRect(rrect, body);

    // Outline.
    final outline = Paint()
      ..color = accentDark
      ..strokeWidth = 0.5 * scale
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, outline);

    // Top highlight strip.
    final hi = Paint()..color = Colors.white.withValues(alpha: 0.4);
    final hiRect = Rect.fromLTWH(2.5 * scale, 2.5 * scale, 19 * scale, 2 * scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(hiRect, Radius.circular(1.5 * scale)),
      hi,
    );

    // White play-triangle.
    final tri = Path()
      ..moveTo(9 * scale, 8 * scale)
      ..lineTo(15 * scale, 12 * scale)
      ..lineTo(9 * scale, 16 * scale)
      ..close();
    canvas.drawPath(tri, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.accent != accent || old.accentDark != accentDark;
}
