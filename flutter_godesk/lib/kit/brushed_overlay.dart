// BrushedOverlay — vertical brushed-metal striping.
//
// Ports CSS `repeating-linear-gradient(90deg, ${brushed} 0 1px, transparent 1px 4px)`
// from godesk-skeuo-kit.jsx (MetalPanel + chrome). The previous Dart port
// tried to do this with `LinearGradient(tileMode: repeated)` and stops at
// `[0, 0.0625, 0.25]`, expecting a 4 px tile to emerge. Flutter's
// LinearGradient stretches stops across the FULL container width — so
// instead of 1 px stripes we got one fat band per panel and the brushed
// look disappeared entirely. CustomPainter draws true 1-px-on / 3-px-off
// lines that don't depend on container width.

import 'package:flutter/material.dart';

import '../theme/godesk_theme.dart';

class BrushedOverlay extends StatelessWidget {
  const BrushedOverlay({super.key, this.opacity = 0.6, this.tile = 4});

  /// Multiplied with the theme stripe color. Reference uses `0.6`.
  final double opacity;

  /// Period of the stripe pattern in logical pixels: 1 line + (tile-1) gap.
  final double tile;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return IgnorePointer(
      child: CustomPaint(
        painter: _BrushedPainter(color: t.brushed, opacity: opacity, tile: tile),
        size: Size.infinite,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BrushedPainter extends CustomPainter {
  const _BrushedPainter({required this.color, required this.opacity, required this.tile});
  final Color color;
  final double opacity;
  final double tile;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: color.a * opacity)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    // Half-pixel offset so the 1-px line snaps to a device-pixel column.
    var x = 0.5;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      x += tile;
    }
  }

  @override
  bool shouldRepaint(_BrushedPainter old) =>
      old.color != color || old.opacity != opacity || old.tile != tile;
}
