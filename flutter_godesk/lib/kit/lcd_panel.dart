// LCDPanel — dark recessed display with scanlines and a glowing-text vibe.
// Direct port of `LCDPanel` from godesk-skeuo-kit.jsx.
//
// Visual recipe:
//   - Background: `theme.lcdBg` (very dark, palette-tinted).
//   - Inset shadow at top (recessed feel) — via _InsetPainter overlay.
//   - Bottom 1-px highlight (floor of the well) — same overlay.
//   - Repeating horizontal scanlines: 2px transparent / 1px dark, full
//     overlay, pointer-events:none equivalent.
//
// Glow on text content is the responsibility of the caller (use the helper
// `lcdTextStyle(...)` defined here).

import 'package:flutter/material.dart';

import '../theme/godesk_theme.dart';
import '../theme/typography.dart';
import '_internal/inset_painter.dart';

class LCDPanel extends StatelessWidget {
  const LCDPanel({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.borderRadius = 6,
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
        color: t.lcdBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: t.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 0.5),
        child: Stack(
          children: <Widget>[
            // Inset recess (top dark inner shadow + bottom highlight).
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: InsetShadowPainter(theme: t, borderRadius: borderRadius),
                ),
              ),
            ),
            // Scanlines overlay — repeating 2px transparent / 1px dark.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      tileMode: TileMode.repeated,
                      colors: <Color>[
                        Colors.transparent,
                        Colors.transparent,
                        Color(0x2E000000), // rgba(0,0,0,0.18)
                      ],
                      stops: <double>[0.0, 0.6667, 1.0], // 2px / 1px @ 3px tile
                    ),
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Convenience: text style for LCD readouts. Caller pairs the returned style
/// with the corresponding [Text] and the glow-shadow helper [lcdGlow].
TextStyle lcdReadout({
  required GoDeskTheme theme,
  double size = 14,
  FontWeight weight = FontWeight.w700,
}) =>
    GDtype.mono(
      size: size,
      weight: weight,
      color: theme.lcdInk,
      letterSpacing: 0.04 * size,
    ).copyWith(shadows: lcdGlow(theme));

/// Glow shadow for any text rendered inside an `LCDPanel`. Direct port of
/// `text-shadow: 0 0 6px {lcdInk}aa` from JSX.
List<Shadow> lcdGlow(GoDeskTheme theme) => <Shadow>[
      Shadow(
        color: theme.lcdInk.withValues(alpha: 2 / 3), // 0xaa = 170/255 ≈ 0.667
        blurRadius: 6,
      ),
    ];

/// Dim helper text inside an LCD (e.g. "> ID:").
TextStyle lcdDimLabel({required GoDeskTheme theme}) => GDtype.mono(
      size: 9,
      weight: FontWeight.w500,
      color: theme.lcdDim,
      letterSpacing: 0.9, // 0.1em at 9px
    );
