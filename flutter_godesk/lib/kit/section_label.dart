// SectionLabel — tiny uppercase tracked label preset.
// Direct port of `SectionLabel` from godesk-skeuo-kit.jsx.
//
// 9px / weight 700 / letter-spacing 0.14em / uppercase / color theme.subtle.
//
// High-contrast (Phase 2.3 a11y): when MediaQuery.highContrastOf is true,
// use `theme.heading` (max contrast) instead of `theme.subtle` (engraved).
// Handoff explicitly flags engraved labels as a contrast risk.

import 'package:flutter/material.dart';

import '../theme/godesk_theme.dart';
import '../theme/typography.dart';
import '../util/a11y.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {this.color, super.key});

  final String text;

  /// Override default `theme.subtle` color (e.g. on accent backgrounds).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final autoColor = highContrast(context) ? t.heading : t.subtle;
    return Text(
      text.toUpperCase(),
      style: GDtype.sectionLabel(color: color ?? autoColor),
    );
  }
}
