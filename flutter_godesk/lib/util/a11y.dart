// Accessibility helpers — Phase 2.3 a11y pass.
//
// Reduced-motion: respects the OS-level "Show animations" setting via
// `MediaQuery.disableAnimationsOf`. When true, every kit widget that has
// an animation (LED breathe, Toggle springy thumb, Knob mark rotation,
// VUMeter needle springiness, TactileButton press depress, ConnectingOverlay
// pulse) should either freeze the controller, set duration to Duration.zero,
// or fall back to a static rendering.
//
// High-contrast: when MediaQuery.highContrastOf is true, kit widgets should
// boost text shadows / fall back to solid colors instead of subtle gradients.

import 'package:flutter/material.dart';

/// True when the OS "Show animations" toggle is off — the user wants no
/// motion. Every animated widget in the kit checks this.
bool reducedMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// True when the OS "Increase contrast" toggle is on. Widgets boost
/// readability: solid colors over gradients, stronger borders, removed
/// engraved text-shadow tricks.
bool highContrast(BuildContext context) => MediaQuery.highContrastOf(context);

/// Wraps a duration: returns Duration.zero when motion is reduced.
Duration motionDuration(BuildContext context, Duration normal) =>
    reducedMotion(context) ? Duration.zero : normal;
