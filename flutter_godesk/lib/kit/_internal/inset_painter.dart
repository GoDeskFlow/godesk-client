// Inset shadow painter — Flutter has no `inset BoxShadow`, so we paint
// recessed inner shadows via CustomPainter. Used by `LCDPanel`, recessed
// segmented controls, and the pressed state of `TactileButton`.
//
// Approach: draw the dark inset by stamping a soft inner shadow inward from
// the top edge (most of the depth perception comes from a top-down inner
// shade). Optionally a 1-px bottom highlight reads as the floor of the well.

import 'package:flutter/material.dart';

import '../../theme/godesk_theme.dart';

class InsetShadowPainter extends CustomPainter {
  const InsetShadowPainter({
    required this.theme,
    this.borderRadius = 6,
    this.depth = 4,
  });

  final GoDeskTheme theme;
  final double borderRadius;
  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    canvas.save();
    canvas.clipRRect(rrect);

    // Top inner shadow (the strongest cue for "recessed").
    final shadeColor = theme.dark
        ? theme.bevelDarkBase.withValues(alpha: 0.5 * theme.intensity)
        : theme.bevelDarkBase.withValues(alpha: 0.35 * theme.intensity);
    final shadePaint = Paint()
      ..color = shadeColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, depth);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.translate(0, -depth),
        Radius.circular(borderRadius),
      ),
      shadePaint,
    );

    // Bottom 1-px highlight — the "floor of the well".
    final highlightAlpha = (theme.dark ? 0.06 : 0.95) * theme.intensity;
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: highlightAlpha)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(borderRadius * 0.5, size.height - 0.5),
      Offset(size.width - borderRadius * 0.5, size.height - 0.5),
      highlightPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(InsetShadowPainter oldDelegate) =>
      oldDelegate.theme.dark != theme.dark ||
      oldDelegate.theme.intensity != theme.intensity ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.depth != depth;
}
