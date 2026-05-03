// Skeuomorphic design tokens for GoDesk.
// Direct port of `branding/design-system/components/godesk-skeuo-kit.jsx`
// — `LIGHT`, `DARK`, `ACCENTS`, `LCDS` constant maps.
//
// Source of truth: branding/design-system/README.md (sections "Design Tokens",
// "Accents", "LCD palettes"). Do not edit values here without updating the
// reference design first.

import 'dart:ui' show Color;

/// Light theme base palette (no accent / LCD applied).
class GoDeskLight {
  static const bg = Color(0xFFE8E4DC);
  static const panel = Color(0xFFF5F1E8);
  static const panelHi = Color(0xFFFCFAF3);
  static const border = Color(0xFFBCB6A8);
  static const heading = Color(0xFF2A2620);
  static const body = Color(0xFF5A5246);
  static const subtle = Color(0xFF9A9080);
  static const chromeBorder = Color(0xFF9A9484);

  // chrome gradient: linear-gradient(180deg, #d8d2c2 0% -> #b8b1a0 100%)
  static const chromeTop = Color(0xFFD8D2C2);
  static const chromeBottom = Color(0xFFB8B1A0);

  // bevel multipliers (alpha is multiplied by `intensity` at theme-build time)
  static const bevelLightBase = Color(0xFFFFFFFF); // alpha 0.95 × intensity
  static const bevelDarkBase = Color(0xFF786E5A); // alpha 0.35 × intensity

  // brushed-metal stripe color for `MetalPanel`
  static const brushed = Color(0x40000000); // ~rgba(0,0,0,0.025) at low opacity
}

/// Dark theme base palette.
class GoDeskDark {
  static const bg = Color(0xFF1C1D22);
  static const panel = Color(0xFF2A2C33);
  static const panelHi = Color(0xFF33363E);
  static const border = Color(0xFF15161A);
  static const heading = Color(0xFFF0E8D8);
  static const body = Color(0xFFC2BBAB);
  static const subtle = Color(0xFF85806F);
  static const chromeBorder = Color(0xFF0A0B0D);

  static const chromeTop = Color(0xFF3A3C44);
  static const chromeBottom = Color(0xFF25272D);

  static const bevelLightBase = Color(0xFFFFFFFF); // alpha 0.06 × intensity
  static const bevelDarkBase = Color(0xFF000000); // alpha 0.50 × intensity

  static const brushed = Color(0x33FFFFFF);
}

/// Accent definition. `light` is used as the live `accent` in dark mode,
/// `dark` is used as live `accent` in light mode + always as `accentDark`.
/// `glow` is used for ambient halos around primary buttons / LEDs.
class AccentPalette {
  const AccentPalette({
    required this.name,
    required this.light,
    required this.dark,
    required this.glow,
  });
  final String name;
  final Color light;
  final Color dark;
  final Color glow;
}

const accents = <String, AccentPalette>{
  'orange': AccentPalette(
    name: 'orange',
    light: Color(0xFFE07820),
    dark: Color(0xFFB85E10),
    glow: Color(0xFFE07820),
  ),
  'red': AccentPalette(
    name: 'red',
    light: Color(0xFFD63031),
    dark: Color(0xFFA52828),
    glow: Color(0xFFFF5050),
  ),
  'tiffany': AccentPalette(
    name: 'tiffany',
    light: Color(0xFF1DA198),
    dark: Color(0xFF10746D),
    glow: Color(0xFF2DD4BF),
  ),
  'yellow': AccentPalette(
    name: 'yellow',
    light: Color(0xFFD99A00),
    dark: Color(0xFFA87800),
    glow: Color(0xFFFBBF24),
  ),
};

/// LCD palette used inside `LCDPanel` — ink is the glowing text color,
/// bg is the recessed dark background, dim is for unlit segments.
class LcdPalette {
  const LcdPalette({
    required this.name,
    required this.ink,
    required this.bg,
    required this.dim,
  });
  final String name;
  final Color ink;
  final Color bg;
  final Color dim;
}

const lcdPalettes = <String, LcdPalette>{
  'green': LcdPalette(
    name: 'green',
    ink: Color(0xFFA3FF9D),
    bg: Color(0xFF0D0F0C),
    dim: Color(0xFF1A3A1A),
  ),
  'amber': LcdPalette(
    name: 'amber',
    ink: Color(0xFFFFB84D),
    bg: Color(0xFF0D0A05),
    dim: Color(0xFF3D2A0C),
  ),
  'blue': LcdPalette(
    name: 'blue',
    ink: Color(0xFF7DD3FC),
    bg: Color(0xFF070A0D),
    dim: Color(0xFF0C2235),
  ),
  'red': LcdPalette(
    name: 'red',
    ink: Color(0xFFFF7D7D),
    bg: Color(0xFF0D0707),
    dim: Color(0xFF3A1010),
  ),
};

/// Status colors used across LEDs and gradient buttons.
class StatusColors {
  static const onlineLed = Color(0xFF22C55E);
  static const onlineButtonTop = Color(0xFF34D058);
  static const onlineButtonBottom = Color(0xFF22A843);
  static const warning = Color(0xFFF59E0B);
  static const dangerTop = Color(0xFFE25555);
  static const dangerBottom = Color(0xFFB03030);
}

/// Working defaults for a fresh install (per `TWEAK_DEFAULTS` in handoff).
class TweakDefaults {
  static const bool darkMode = true;
  static const String accent = 'orange';
  static const String lcd = 'green';
  static const double intensity = 1.0;
}
