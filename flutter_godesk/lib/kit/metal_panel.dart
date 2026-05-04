// MetalPanel — brushed-metal raised card. Outset bevel + brushed striping.
// Direct port of `MetalPanel` from godesk-skeuo-kit.jsx.
//
// Visual recipe:
//   - Background: solid `theme.panel`.
//   - Top 1-px highlight + bottom 1-px lowlight (the bevel) → drawn via
//     a thin gradient border.
//   - Outer drop shadow: theme-intensity scaled.
//   - Brushed-metal vertical stripes: repeating 1px-on / 3px-off at 60% alpha.

import 'package:flutter/material.dart';

import '../theme/bevels.dart';
import '../theme/godesk_theme.dart';
import 'brushed_overlay.dart';

class MetalPanel extends StatelessWidget {
  const MetalPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 10,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: t.border),
        boxShadow: outsetDropShadow(intensity: t.intensity, lift: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 0.5),
        child: Stack(
          children: <Widget>[
            // Brushed-metal vertical stripes overlay — true 1-px-on / 3-px-off
            // pattern (CSS `repeating-linear-gradient(90deg, brushed 0 1px,
            // transparent 1px 4px)`). Earlier port used a single gradient with
            // tileMode:repeated which Flutter stretches across the full panel
            // width — texture vanished. CustomPainter draws actual stripes.
            const Positioned.fill(child: BrushedOverlay()),
            // Top 1px highlight (the outset top edge of the bevel).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                color: bevelLight(dark: t.dark, intensity: t.intensity),
              ),
            ),
            // Bottom 1px lowlight (the outset bottom edge of the bevel).
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                color: bevelDark(dark: t.dark, intensity: t.intensity),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}
