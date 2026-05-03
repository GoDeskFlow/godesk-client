// Toggle — 44 × 24 hardware-style switch with springy thumb.
// Direct port of `Toggle` from godesk-skeuo-screens.jsx.
//
// Off state: recessed LCD-bg slot.
// On  state: accent-gradient + ambient glow + thumb shifted 21 px right.
// Thumb: soft white→grey gradient.
// Thumb transition: 180 ms cubic-bezier(0.34, 1.56, 0.64, 1) — springy.

import 'package:flutter/material.dart';

import '../theme/godesk_theme.dart';
import '../util/a11y.dart';

class GoDeskToggle extends StatelessWidget {
  const GoDeskToggle({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final reduced = reducedMotion(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 180),
          width: 44,
          height: 24,
          decoration: BoxDecoration(
            gradient: value
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[t.accent, t.accentDark],
                  )
                : null,
            color: value ? null : t.lcdBg,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: value ? t.accentDark : t.border),
            boxShadow: value
                ? <BoxShadow>[
                    BoxShadow(
                      color: t.accentGlow.withValues(alpha: 1 / 3),
                      blurRadius: 8,
                    ),
                  ]
                : <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      spreadRadius: -1,
                    ),
                  ],
          ),
          child: Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: reduced ? Duration.zero : const Duration(milliseconds: 180),
                curve: reduced ? Curves.linear : Curves.elasticOut,
                top: 1,
                left: value ? 21 : 1,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: value
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[Colors.white, Color(0xFFDDDDDD)],
                          )
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[t.panelHi, t.panel],
                          ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
