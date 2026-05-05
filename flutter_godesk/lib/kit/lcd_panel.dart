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

class LCDPanel extends StatefulWidget {
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
  State<LCDPanel> createState() => _LCDPanelState();
}

class _LCDPanelState extends State<LCDPanel> {
  /// Local mouse position used by the parallax shine. Null when the
  /// cursor isn't over the panel — overlay fades out via AnimatedOpacity.
  Offset? _hoverLocal;
  Size _size = Size.zero;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return MouseRegion(
      onHover: (e) => setState(() => _hoverLocal = e.localPosition),
      onExit: (_) => setState(() => _hoverLocal = null),
      child: LayoutBuilder(builder: (context, c) {
        _size = Size(c.maxWidth, c.maxHeight);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: t.lcdBg,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: t.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius - 0.5),
            child: Stack(
              children: <Widget>[
                // Inset recess (top dark inner shadow + bottom highlight).
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: InsetShadowPainter(
                          theme: t, borderRadius: widget.borderRadius),
                    ),
                  ),
                ),
                // Parallax shine — a soft radial highlight that follows
                // the cursor. Subtle: 6% accent at the cursor, fades to
                // transparent within ~80px. Disappears smoothly on exit.
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _hoverLocal == null ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 220),
                      child: CustomPaint(
                        painter: _ShinePainter(
                          local: _hoverLocal ?? Offset.zero,
                          size: _size,
                          ink: t.lcdInk,
                        ),
                      ),
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
                          stops: <double>[0.0, 0.6667, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(padding: widget.padding, child: widget.child),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _ShinePainter extends CustomPainter {
  _ShinePainter({
    required this.local,
    required this.size,
    required this.ink,
  });
  final Offset local;
  final Size size;
  final Color ink;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (size.isEmpty) return;
    final radius = (size.width.clamp(0.0, 200.0)) * 0.5;
    final rect = Offset.zero & canvasSize;
    final shader = RadialGradient(
      colors: <Color>[
        ink.withValues(alpha: 0.06),
        Colors.transparent,
      ],
      radius: 0.45,
      center: Alignment(
        ((local.dx / (canvasSize.width == 0 ? 1 : canvasSize.width)) * 2 - 1)
            .clamp(-1.0, 1.0),
        ((local.dy / (canvasSize.height == 0 ? 1 : canvasSize.height)) * 2 - 1)
            .clamp(-1.0, 1.0),
      ),
    ).createShader(rect);
    final p = Paint()..shader = shader;
    canvas.drawRect(rect, p);
    // suppress unused-warning for `radius`; kept for future tuning.
    if (radius < 0) canvas.drawRect(rect, p);
  }

  @override
  bool shouldRepaint(_ShinePainter old) =>
      old.local != local || old.size != size;
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
