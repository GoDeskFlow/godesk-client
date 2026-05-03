// Bevel recipes — direct port of `bevelOut(t, lift)` and `bevelIn(t)`
// from `branding/design-system/components/godesk-skeuo-kit.jsx`.
//
// In Flutter, multi-layered insets become a `List<BoxShadow>`:
//   - inset bevels become BoxShadow with negative blur + spread = 0 (Flutter
//     does not have native `inset`; we approximate with offset shadows that
//     read as inner highlights/lows).
//   - outer drop shadow becomes a regular outset BoxShadow.
//
// Note: Flutter does not support inset BoxShadow. The handoff calls for
// `inset 0 1px 0 bevelLight` (top highlight) and `inset 0 -1px 0 bevelDark`
// (bottom shade). We achieve the visual via:
//   - top highlight: a 1px-tall light gradient stop drawn inside the
//     decoration via `Border` / a custom `LinearGradient` overlay.
//   - bottom shade: same approach, dark gradient at the bottom edge.
//
// For pure shadow stacks (outset drop shadow only), we use BoxShadow normally.

import 'package:flutter/painting.dart';

import 'tokens.dart';

/// Outset (raised) drop shadow alone. The 1px highlight/lowlight bevels are
/// painted as part of the panel's gradient/border by each widget; this
/// function returns ONLY the outer drop shadow component.
///
/// Equivalent of the third line of the JSX `bevelOut(t, lift)`:
///   `0 ${lift}px ${lift*2}px rgba(0,0,0, 0.15 × intensity)`
List<BoxShadow> outsetDropShadow({
  required double intensity,
  double lift = 1.0,
}) {
  final alpha = (0.15 * intensity).clamp(0.0, 1.0);
  return <BoxShadow>[
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: alpha),
      offset: Offset(0, lift),
      blurRadius: lift * 2,
    ),
  ];
}

/// Returns the top-edge highlight color for an outset bevel — a 1-px tall
/// light line drawn inside the decoration by widgets via gradient or border.
Color bevelLight({required bool dark, required double intensity}) {
  final base = dark ? GoDeskDark.bevelLightBase : GoDeskLight.bevelLightBase;
  final alpha = (dark ? 0.06 : 0.95) * intensity;
  return base.withValues(alpha: alpha.clamp(0.0, 1.0));
}

/// Returns the bottom-edge shade color for an outset bevel.
Color bevelDark({required bool dark, required double intensity}) {
  final base = dark ? GoDeskDark.bevelDarkBase : GoDeskLight.bevelDarkBase;
  final alpha = (dark ? 0.50 : 0.35) * intensity;
  return base.withValues(alpha: alpha.clamp(0.0, 1.0));
}

/// Inset (recessed) effect — used by `LCDPanel`, recessed segmented controls,
/// pressed `TactileButton` state. Returns BoxShadow approximation: a darker
/// inner shadow that reads as recess. Pair with a 1-px bottom highlight via
/// gradient at widget level.
///
/// Equivalent of JSX `bevelIn(t)`:
///   inset 0 2px 4px {bevelDark}
///   inset 0 -1px 0 {bevelLight}
///
/// Flutter has no inset BoxShadow, so we use a soft dark shadow at small
/// negative offset which reads visually as recessed. The 1-px bottom
/// highlight is drawn separately by the widget's gradient.
List<BoxShadow> insetShadowApprox({required bool dark, required double intensity}) {
  final shade = bevelDark(dark: dark, intensity: intensity);
  return <BoxShadow>[
    BoxShadow(
      color: shade,
      offset: const Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -1,
    ),
  ];
}

/// Outer window drop shadow — for the main 920×620 frame and any modals.
/// JSX: `0 0 0 1px rgba(0,0,0,0.3), 0 24px 60px rgba(0,0,0,0.3)`
List<BoxShadow> windowShadow() => const <BoxShadow>[
      BoxShadow(
        color: Color(0x4D000000), // rgba(0,0,0,0.3) hairline
        spreadRadius: 1,
      ),
      BoxShadow(
        color: Color(0x4D000000),
        offset: Offset(0, 24),
        blurRadius: 60,
      ),
    ];
