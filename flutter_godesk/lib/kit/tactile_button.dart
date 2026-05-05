// TactileButton — beveled push-button with tactile press feedback.
// Direct port of `TactileButton` from godesk-skeuo-kit.jsx.
//
// Press cycle:
//   - mouse-down: shifts down 1px + outset bevel swaps to inset bevel +
//     drop shadow shrinks (transition 60 ms).
//   - mouse-up / leave / touch-end: returns to released state.
//
// Three color modes:
//   - default:  panel-grey gradient
//   - primary:  accent → accentDark gradient + ambient `accentGlow` halo
//   - danger:   red → dark red gradient

import 'package:flutter/material.dart';

import '../theme/godesk_theme.dart';
import '../theme/typography.dart';
import '../util/a11y.dart';
import '_internal/inset_painter.dart';

enum TactileVariant { defaultStyle, primary, danger }

class TactileButton extends StatefulWidget {
  const TactileButton({
    required this.child,
    this.onPressed,
    this.variant = TactileVariant.defaultStyle,
    this.small = false,
    this.minWidth,
    this.padding,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final TactileVariant variant;
  final bool small;
  final double? minWidth;
  final EdgeInsetsGeometry? padding;

  bool get _disabled => onPressed == null;

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool v) {
    if (widget._disabled) return;
    setState(() => _pressed = v);
  }

  void _setHovered(bool v) {
    if (widget._disabled) return;
    if (_hovered == v) return;
    setState(() => _hovered = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final small = widget.small;
    final disabled = widget._disabled;
    final isPrimary = widget.variant == TactileVariant.primary && !disabled;
    final isDanger = widget.variant == TactileVariant.danger && !disabled;

    final height = small ? 26.0 : 32.0;
    final radius = small ? 5.0 : 6.0;
    final padding = widget.padding ??
        EdgeInsets.symmetric(horizontal: small ? 10 : 14);

    final bg = isPrimary
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[t.accent, t.accentDark],
          )
        : isDanger
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFFE25555), Color(0xFFB03030)],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[t.panelHi, t.panel],
              );

    final fg = disabled
        ? t.subtle
        : (isPrimary || isDanger)
            ? Colors.white
            : t.heading;
    final borderColor = isPrimary
        ? t.accentDark
        : isDanger
            ? const Color(0xFFA02525)
            : t.border;

    final textShadows = (isPrimary || isDanger)
        ? <Shadow>[
            const Shadow(
              color: Color(0x40000000), // rgba(0,0,0,0.25)
              offset: Offset(0, 1),
            ),
          ]
        : <Shadow>[
            Shadow(
              color: t.dark
                  ? const Color(0x66000000) // rgba(0,0,0,0.4)
                  : const Color(0x99FFFFFF), // rgba(255,255,255,0.6)
              offset: const Offset(0, 1),
            ),
          ];

    final glow = isPrimary && !_pressed
        ? <BoxShadow>[
            BoxShadow(
              // Hover bumps the halo a bit for primary buttons.
              color: t.accentGlow
                  .withValues(alpha: (_hovered && !disabled) ? 0.5 : 1 / 3),
              blurRadius: (_hovered && !disabled) ? 16 : 12,
            ),
          ]
        : const <BoxShadow>[];

    // Hover state lifts the drop shadow a tiny bit (1px → 3px) and bumps
    // glow opacity for primary buttons so the cursor target gets clear
    // visual feedback. Disabled buttons stay flat.
    final hoverActive = _hovered && !_pressed && !disabled;
    final dropShadow = _pressed
        ? const <BoxShadow>[]
        : <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(
                alpha: ((isPrimary || isDanger) ? 0.18 : 0.12) *
                    t.intensity *
                    (hoverActive ? 1.4 : 1.0),
              ),
              offset: Offset(0, (isPrimary || isDanger)
                  ? (hoverActive ? 4 : 2)
                  : (hoverActive ? 3 : 1)),
              blurRadius: (isPrimary || isDanger)
                  ? (hoverActive ? 8 : 4)
                  : (hoverActive ? 5 : 2),
            ),
          ];

    final reduced = reducedMotion(context);
    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 120),
          transform: (_pressed && !reduced)
              ? Matrix4.translationValues(0, 1, 0)
              : (hoverActive && !reduced)
                  ? Matrix4.translationValues(0, -1, 0)
                  : Matrix4.identity(),
          constraints: BoxConstraints(
            minHeight: height,
            maxHeight: height,
            minWidth: widget.minWidth ?? 0,
          ),
          decoration: BoxDecoration(
            gradient: bg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor),
            boxShadow: <BoxShadow>[...glow, ...dropShadow],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - 0.5),
            child: Stack(
              children: <Widget>[
                if (_pressed)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: InsetShadowPainter(theme: t, borderRadius: radius),
                      ),
                    ),
                  )
                else ...<Widget>[
                  // 1px top highlight bevel
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: (isPrimary || isDanger)
                          ? Colors.white.withValues(alpha: 0.3)
                          : t.bevelLightBase.withValues(
                              alpha: ((t.dark ? 0.06 : 0.95) * t.intensity).clamp(0.0, 1.0),
                            ),
                    ),
                  ),
                  // 1px bottom shade bevel
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: (isPrimary || isDanger)
                          ? Colors.black.withValues(alpha: 0.2)
                          : t.bevelDarkBase.withValues(
                              alpha: ((t.dark ? 0.5 : 0.35) * t.intensity).clamp(0.0, 1.0),
                            ),
                    ),
                  ),
                ],
                Padding(
                  padding: padding,
                  child: Center(
                    child: DefaultTextStyle.merge(
                      style: GDtype.wordmark(
                        size: small ? 10 : 12,
                        color: fg,
                        trackingEm: 0.06,
                      ).copyWith(shadows: textShadows),
                      child: IconTheme.merge(
                        data: IconThemeData(color: fg, size: small ? 12 : 14),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
