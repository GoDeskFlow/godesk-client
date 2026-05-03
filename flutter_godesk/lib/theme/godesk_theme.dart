// GoDeskTheme — ThemeExtension carrying the live skeuo tokens.
// Direct port of `makeSkeuoTheme({dark, accentName, lcdName, intensity})`
// from `branding/design-system/components/godesk-skeuo-kit.jsx`.
//
// Usage:
//   final theme = makeSkeuoTheme(dark: true, accentName: 'orange',
//                                lcdName: 'green', intensity: 1.0);
//   MaterialApp(
//     theme: ThemeData(extensions: [theme], ...),
//   );
//
//   // Inside any widget:
//   final t = Theme.of(context).extension<GoDeskTheme>()!;
//   Container(color: t.panel)

import 'package:flutter/material.dart';

import 'tokens.dart';

@immutable
class GoDeskTheme extends ThemeExtension<GoDeskTheme> {
  const GoDeskTheme({
    required this.dark,
    required this.intensity,
    // base palette
    required this.bg,
    required this.panel,
    required this.panelHi,
    required this.border,
    required this.heading,
    required this.body,
    required this.subtle,
    // chrome
    required this.chromeTop,
    required this.chromeBottom,
    required this.chromeBorder,
    required this.brushed,
    // bevels (base colors; intensity-scaled by widgets via bevelLight/bevelDark)
    required this.bevelLightBase,
    required this.bevelDarkBase,
    // live accent (chooses light vs dark variant based on theme mode)
    required this.accent,
    required this.accentDark,
    required this.accentGlow,
    // live LCD palette
    required this.lcdInk,
    required this.lcdBg,
    required this.lcdDim,
  });

  final bool dark;
  final double intensity;

  final Color bg;
  final Color panel;
  final Color panelHi;
  final Color border;
  final Color heading;
  final Color body;
  final Color subtle;

  final Color chromeTop;
  final Color chromeBottom;
  final Color chromeBorder;
  final Color brushed;

  final Color bevelLightBase;
  final Color bevelDarkBase;

  final Color accent;
  final Color accentDark;
  final Color accentGlow;

  final Color lcdInk;
  final Color lcdBg;
  final Color lcdDim;

  /// Brushed-metal repeating stripe gradient for `MetalPanel` overlay.
  /// JSX: `repeating-linear-gradient(90deg, {brushed} 0 1px, transparent 1px 4px)`
  Gradient get brushedStripes => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        tileMode: TileMode.repeated,
        colors: <Color>[brushed, Colors.transparent, Colors.transparent],
        stops: const <double>[0.0, 0.0625, 0.25], // 1px stripe, 3px gap @ 16px tile
      );

  /// Title-bar / footer chrome gradient.
  /// JSX: `linear-gradient(180deg, top 0%, bottom 100%)`
  Gradient get chromeGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[chromeTop, chromeBottom],
      );

  @override
  GoDeskTheme copyWith({
    bool? dark,
    double? intensity,
    Color? bg,
    Color? panel,
    Color? panelHi,
    Color? border,
    Color? heading,
    Color? body,
    Color? subtle,
    Color? chromeTop,
    Color? chromeBottom,
    Color? chromeBorder,
    Color? brushed,
    Color? bevelLightBase,
    Color? bevelDarkBase,
    Color? accent,
    Color? accentDark,
    Color? accentGlow,
    Color? lcdInk,
    Color? lcdBg,
    Color? lcdDim,
  }) {
    return GoDeskTheme(
      dark: dark ?? this.dark,
      intensity: intensity ?? this.intensity,
      bg: bg ?? this.bg,
      panel: panel ?? this.panel,
      panelHi: panelHi ?? this.panelHi,
      border: border ?? this.border,
      heading: heading ?? this.heading,
      body: body ?? this.body,
      subtle: subtle ?? this.subtle,
      chromeTop: chromeTop ?? this.chromeTop,
      chromeBottom: chromeBottom ?? this.chromeBottom,
      chromeBorder: chromeBorder ?? this.chromeBorder,
      brushed: brushed ?? this.brushed,
      bevelLightBase: bevelLightBase ?? this.bevelLightBase,
      bevelDarkBase: bevelDarkBase ?? this.bevelDarkBase,
      accent: accent ?? this.accent,
      accentDark: accentDark ?? this.accentDark,
      accentGlow: accentGlow ?? this.accentGlow,
      lcdInk: lcdInk ?? this.lcdInk,
      lcdBg: lcdBg ?? this.lcdBg,
      lcdDim: lcdDim ?? this.lcdDim,
    );
  }

  @override
  GoDeskTheme lerp(ThemeExtension<GoDeskTheme>? other, double t) {
    if (other is! GoDeskTheme) return this;
    return GoDeskTheme(
      dark: t < 0.5 ? dark : other.dark,
      intensity: lerpDouble(intensity, other.intensity, t),
      bg: Color.lerp(bg, other.bg, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelHi: Color.lerp(panelHi, other.panelHi, t)!,
      border: Color.lerp(border, other.border, t)!,
      heading: Color.lerp(heading, other.heading, t)!,
      body: Color.lerp(body, other.body, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      chromeTop: Color.lerp(chromeTop, other.chromeTop, t)!,
      chromeBottom: Color.lerp(chromeBottom, other.chromeBottom, t)!,
      chromeBorder: Color.lerp(chromeBorder, other.chromeBorder, t)!,
      brushed: Color.lerp(brushed, other.brushed, t)!,
      bevelLightBase: Color.lerp(bevelLightBase, other.bevelLightBase, t)!,
      bevelDarkBase: Color.lerp(bevelDarkBase, other.bevelDarkBase, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      lcdInk: Color.lerp(lcdInk, other.lcdInk, t)!,
      lcdBg: Color.lerp(lcdBg, other.lcdBg, t)!,
      lcdDim: Color.lerp(lcdDim, other.lcdDim, t)!,
    );
  }
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

/// Build a live theme from the four user-tweakable inputs. Mirrors the JSX
/// `makeSkeuoTheme({dark, accentName, lcdName, intensity})`.
///
/// Per handoff:
///   - in dark mode, `accent` = palette's `light` variant (more saturated for contrast)
///   - in light mode, `accent` = palette's `dark` variant
///   - `accentDark` is always palette's `dark` variant
GoDeskTheme makeSkeuoTheme({
  required bool dark,
  required String accentName,
  required String lcdName,
  required double intensity,
}) {
  final accentPalette = accents[accentName] ?? accents[TweakDefaults.accent]!;
  final lcd = lcdPalettes[lcdName] ?? lcdPalettes[TweakDefaults.lcd]!;

  if (dark) {
    return GoDeskTheme(
      dark: true,
      intensity: intensity,
      bg: GoDeskDark.bg,
      panel: GoDeskDark.panel,
      panelHi: GoDeskDark.panelHi,
      border: GoDeskDark.border,
      heading: GoDeskDark.heading,
      body: GoDeskDark.body,
      subtle: GoDeskDark.subtle,
      chromeTop: GoDeskDark.chromeTop,
      chromeBottom: GoDeskDark.chromeBottom,
      chromeBorder: GoDeskDark.chromeBorder,
      brushed: GoDeskDark.brushed,
      bevelLightBase: GoDeskDark.bevelLightBase,
      bevelDarkBase: GoDeskDark.bevelDarkBase,
      accent: accentPalette.light,
      accentDark: accentPalette.dark,
      accentGlow: accentPalette.glow,
      lcdInk: lcd.ink,
      lcdBg: lcd.bg,
      lcdDim: lcd.dim,
    );
  }

  return GoDeskTheme(
    dark: false,
    intensity: intensity,
    bg: GoDeskLight.bg,
    panel: GoDeskLight.panel,
    panelHi: GoDeskLight.panelHi,
    border: GoDeskLight.border,
    heading: GoDeskLight.heading,
    body: GoDeskLight.body,
    subtle: GoDeskLight.subtle,
    chromeTop: GoDeskLight.chromeTop,
    chromeBottom: GoDeskLight.chromeBottom,
    chromeBorder: GoDeskLight.chromeBorder,
    brushed: GoDeskLight.brushed,
    bevelLightBase: GoDeskLight.bevelLightBase,
    bevelDarkBase: GoDeskLight.bevelDarkBase,
    accent: accentPalette.dark,
    accentDark: accentPalette.dark,
    accentGlow: accentPalette.glow,
    lcdInk: lcd.ink,
    lcdBg: lcd.bg,
    lcdDim: lcd.dim,
  );
}
