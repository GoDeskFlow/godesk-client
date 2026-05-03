// Typography helpers — bundled fonts (Phase 2.3).
// Switched from google_fonts to assets/fonts/* registered in pubspec.yaml.
// Offline-first per AGPL §13 source-availability and zero-CDN-dependency goal.

import 'package:flutter/material.dart';

class GDtype {
  GDtype._();

  /// UI font, all weights 400–800.
  static TextStyle ui({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: 'InterTight',
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// Mono font for LCD readouts, IDs, IP addresses, status lines.
  static TextStyle mono({
    double size = 12,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: 'JetBrainsMono',
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// Headings — 20–24px, weight 800, slight negative tracking + soft shadow.
  /// Caller adds the shadow via `style.copyWith(shadows: ...)`.
  static TextStyle heading({
    double size = 20,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: 'InterTight',
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.01 * size,
      );

  /// Section label — 9px, weight 700, uppercase, tracked 0.14em.
  /// Apply uppercase at the call site (`'YOUR LABEL'.toUpperCase()`).
  static TextStyle sectionLabel({Color? color}) => TextStyle(
        fontFamily: 'InterTight',
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 9 * 0.14, // 0.14em at 9px
        color: color,
      );

  /// Wordmark / button labels — uppercase, tracked 0.06–0.10em.
  static TextStyle wordmark({
    double size = 14,
    Color? color,
    double trackingEm = 0.06,
  }) =>
      TextStyle(
        fontFamily: 'InterTight',
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: size * trackingEm,
        color: color,
      );
}

/// Soft drop-shadow for headings — light theme: white highlight; dark: black.
List<Shadow> headingShadow({required bool dark}) => <Shadow>[
      Shadow(
        offset: const Offset(0, 1),
        color: dark
            ? const Color(0x99000000) // rgba(0,0,0,0.6)
            : const Color(0xB3FFFFFF), // rgba(255,255,255,0.7)
      ),
    ];
