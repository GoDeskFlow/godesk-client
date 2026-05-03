// Custom OS glyphs — direct port of `IconWindows`, `IconApple`, `IconLinux`
// from `branding/design-system/components/godesk-icons.jsx`.
//
// First port used Material's `Icons.window_outlined`, `Icons.apple`, and
// `Icons.terminal_outlined` for peer-row OS markers — none of which match the
// reference visually:
//   - `Icons.window_outlined` is a generic single-window glyph, NOT the
//     four-tile Windows logo.
//   - `Icons.terminal_outlined` is `>_` shell prompt — there is no Linux
//     glyph in Material at all, so the reference's Tux silhouette didn't
//     translate.
//   - `Icons.apple` is closer but stroke weight + proportions differ.
//
// User feedback: "иконки словно не прогрузились". This module fixes that by
// painting the same Lucide-style stroke shapes the design canvas uses.

import 'package:flutter/material.dart';

import '../data/peers.dart';

class OsGlyph extends StatelessWidget {
  const OsGlyph({super.key, required this.os, required this.size, required this.color});

  final PeerOS os;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _OsGlyphPainter(os: os, color: color)),
    );
  }
}

class _OsGlyphPainter extends CustomPainter {
  const _OsGlyphPainter({required this.os, required this.color});
  final PeerOS os;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width; // assume square
    // viewBox is 24×24 in the JSX reference; map proportionally to our box.
    final scale = s / 24.0;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (os) {
      case PeerOS.windows:
        // Four-tile Windows logo: 4 outlined squares in a 2×2 grid.
        // JSX: <rect x="3" y="3" w=8 h=8>, x=13/y=3, x=3/y=13, x=13/y=13.
        final tiles = <Rect>[
          Rect.fromLTWH(3 * scale, 3 * scale, 8 * scale, 8 * scale),
          Rect.fromLTWH(13 * scale, 3 * scale, 8 * scale, 8 * scale),
          Rect.fromLTWH(3 * scale, 13 * scale, 8 * scale, 8 * scale),
          Rect.fromLTWH(13 * scale, 13 * scale, 8 * scale, 8 * scale),
        ];
        for (final r in tiles) {
          canvas.drawRect(r, stroke);
        }
        break;
      case PeerOS.macos:
        // Apple silhouette — same as Lucide. Two paths: bite at top + body.
        // JSX path: M12 2c0 0-1 2-1 4s1 4 1 4
        //          M16 8a4 4 0 0 0-4-4 4 4 0 0 0-4 4c-3 0-5 2-5 6 0 5 4 8 5 8s2-1 4-1 3 1 4 1 5-3 5-8c0-4-2-6-5-6z
        // The original shape is filled in our reference (Lucide uses fill).
        // We render with light stroke for stylistic coherence.
        final stem = Path()
          ..moveTo(12 * scale, 2 * scale)
          ..relativeCubicTo(0, 0, -1 * scale, 2 * scale, -1 * scale, 4 * scale)
          ..relativeCubicTo(0, 2 * scale, 1 * scale, 4 * scale, 1 * scale, 4 * scale);
        final body = Path()
          ..moveTo(16 * scale, 8 * scale)
          ..arcToPoint(Offset(12 * scale, 4 * scale),
              radius: Radius.circular(4 * scale), clockwise: false)
          ..arcToPoint(Offset(8 * scale, 8 * scale),
              radius: Radius.circular(4 * scale), clockwise: false)
          ..relativeCubicTo(-3 * scale, 0, -5 * scale, 2 * scale, -5 * scale, 6 * scale)
          ..relativeCubicTo(0, 5 * scale, 4 * scale, 8 * scale, 5 * scale, 8 * scale)
          ..relativeCubicTo(1 * scale, 0, 2 * scale, -1 * scale, 4 * scale, -1 * scale)
          ..relativeCubicTo(2 * scale, 0, 3 * scale, 1 * scale, 4 * scale, 1 * scale)
          ..relativeCubicTo(1 * scale, 0, 5 * scale, -3 * scale, 5 * scale, -8 * scale)
          ..relativeCubicTo(0, -4 * scale, -2 * scale, -6 * scale, -5 * scale, -6 * scale)
          ..close();
        canvas.drawPath(stem, stroke);
        canvas.drawPath(body, stroke);
        break;
      case PeerOS.linux:
        // Tux-ish: a head circle + body curve + two small feet.
        // JSX: <circle cx=12 cy=9 r=4 />,
        //      <path d="M8 13c0 4 2 7 4 7s4-3 4-7" />,
        //      <path d="M6 19c-1 1-2 1-3 0M21 19c-1 1-2 1-3 0" />
        canvas.drawCircle(Offset(12 * scale, 9 * scale), 4 * scale, stroke);
        final body = Path()
          ..moveTo(8 * scale, 13 * scale)
          ..relativeCubicTo(0, 4 * scale, 2 * scale, 7 * scale, 4 * scale, 7 * scale)
          ..relativeCubicTo(2 * scale, 0, 4 * scale, -3 * scale, 4 * scale, -7 * scale);
        canvas.drawPath(body, stroke);
        final leftFoot = Path()
          ..moveTo(6 * scale, 19 * scale)
          ..relativeCubicTo(-1 * scale, 1 * scale, -2 * scale, 1 * scale, -3 * scale, 0);
        final rightFoot = Path()
          ..moveTo(21 * scale, 19 * scale)
          ..relativeCubicTo(-1 * scale, 1 * scale, -2 * scale, 1 * scale, -3 * scale, 0);
        canvas.drawPath(leftFoot, stroke);
        canvas.drawPath(rightFoot, stroke);
        // Tiny eye dot to mimic Tux (not in reference but reads as "Linux"
        // at small sizes more clearly).
        canvas.drawCircle(Offset(11 * scale, 8.5 * scale), 0.6 * scale, fill);
        break;
    }
  }

  @override
  bool shouldRepaint(_OsGlyphPainter old) => old.os != os || old.color != color;
}
