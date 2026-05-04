// SkeuoChrome — 44px brushed-metal title bar with traffic lights, GoDesk
// wordmark, segmented screen tabs, and a serial-number plate on the right.
// Direct port of `SkeuoChrome` from godesk-skeuo-chrome.jsx.
//
// Phase 2.3 final: this IS the OS chrome. The Win11 native title bar is
// hidden (`window_manager.titleBarStyle: hidden`), so we wrap the chrome in
// `DragToMoveArea` and wire the traffic lights to real close/minimize/
// maximize actions. No more "app inside an app" stacking.

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../kit/_internal/inset_painter.dart';
import '../kit/brushed_overlay.dart';
import '../theme/godesk_theme.dart';
import '../theme/typography.dart';
import 'skeuo_logo.dart';

enum SkeuoTab { home, files, settings }

class SkeuoChrome extends StatelessWidget {
  const SkeuoChrome({
    required this.current,
    required this.onTab,
    this.serial = 'SN-742·8193',
    super.key,
  });

  final SkeuoTab current;
  final ValueChanged<SkeuoTab> onTab;
  final String serial;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    // Layered structure: the DragToMoveArea fills the chrome behind everything,
    // and interactive widgets (traffic lights, tab buttons) sit above it via a
    // Stack. Their inner GestureDetectors win the hit-test for taps; empty
    // space between/around them falls through to DragToMoveArea so the user
    // can drag the window from blank chrome regions.
    //
    // Earlier version wrapped the entire chrome in DragToMoveArea, which
    // intercepted pointer-down events before the inner GestureDetectors could
    // claim them on Windows — clicks on the tab buttons (and traffic lights)
    // silently became drag-starts, so tabs never switched.
    return SizedBox(
      height: 44,
      child: Stack(
        children: <Widget>[
          // Layer 1 — drag region fills the chrome. Two stacked decorations:
          // the chromeGradient base + brushed-metal vertical stripes overlay.
          // DecoratedBox WITHOUT a sized child renders 0×0 in Flutter, so the
          // stripes overlay must live in its own Positioned.fill or it will
          // disappear (regression introduced when first lifting drag-area
          // out of the controls Row — user reported "фон заходит").
          Positioned.fill(
            child: DragToMoveArea(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: t.chromeGradient,
                        border: Border(bottom: BorderSide(color: t.chromeBorder)),
                      ),
                    ),
                  ),
                  // Subtle chrome stripes — JSX reference uses
                  // `repeating-linear-gradient(90deg, rgba(255,255,255,0.02)
                  // 0 1px, transparent 1px 3px)` — i.e. ~2% alpha. The
                  // MetalPanel-level 0.6 we initially used here painted the
                  // chrome with too-dark stripes that bled through the tabs
                  // ("словно фон заходит"). Drop opacity to barely-there.
                  const Positioned.fill(
                    child: BrushedOverlay(opacity: 0.06, tile: 3),
                  ),
                ],
              ),
            ),
          ),
          // Layer 2 — interactive controls. Padding/Row/Center/Expanded don't
          // intercept clicks themselves, so blank gaps fall through to drag.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: <Widget>[
                const _TrafficLights(),
                const SizedBox(width: 12),
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SkeuoLogo(),
                        const SizedBox(width: 7),
                        Text(
                          // Reference uses CSS `text-transform: uppercase` →
                          // displays "GODESK". Without uppercasing here the
                          // chrome shows mixed-case "GoDesk".
                          'GoDesk'.toUpperCase(),
                          style: GDtype.wordmark(
                            size: 12,
                            color: t.heading,
                            trackingEm: 0.08,
                          ).copyWith(
                            shadows: <Shadow>[
                              Shadow(
                                color: t.dark
                                    ? const Color(0x99000000)
                                    : const Color(0xB3FFFFFF),
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        _ScreenTabs(current: current, onTab: onTab),
                      ],
                    ),
                  ),
                ),
                _SerialPlate(serial: serial, theme: t),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenTabs extends StatelessWidget {
  const _ScreenTabs({required this.current, required this.onTab});
  final SkeuoTab current;
  final ValueChanged<SkeuoTab> onTab;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    const tabs = <(SkeuoTab, String)>[
      (SkeuoTab.home, 'Home'),
      (SkeuoTab.files, 'Files'),
      (SkeuoTab.settings, 'Settings'),
    ];
    return Container(
      decoration: BoxDecoration(
        // Slightly darker than t.panel so the well reads as a recess against
        // the chrome strip rather than blending into it.
        color: Color.alphaBlend(
          Colors.black.withValues(alpha: t.dark ? 0.18 : 0.06),
          t.panel,
        ),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: t.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.5),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                // Stronger inset (depth 5 vs the previous 3) — design canvas
                // reads as carved-into-metal; the subtle 3-px well looked
                // flat in side-by-side comparison.
                child: CustomPaint(
                  painter: InsetShadowPainter(theme: t, borderRadius: 5, depth: 5),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < tabs.length; i++) ...<Widget>[
                  _TabButton(
                    label: tabs[i].$2,
                    active: tabs[i].$1 == current,
                    onTap: () => onTab(tabs[i].$1),
                  ),
                  if (i < tabs.length - 1)
                    // Darker than t.border so the segment seam is visible.
                    Container(
                      width: 1,
                      color: t.dark
                          ? const Color(0x66000000)
                          : const Color(0x33000000),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          // Vertical padding bumped 4→6 so tabs have more breathing room
          // — earlier the strip read as cramped vs the design canvas.
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[t.accent, t.accentDark],
                  )
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[t.panelHi, t.panel],
                  ),
            // Bevel highlight along the top edge of the active button —
            // visible on the design canvas as a 1-px brighter line that
            // sells the "physical button protrudes from the recess" feel.
            border: active
                ? Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  )
                : null,
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color: t.accentGlow.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: -1,
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Text(
            label.toUpperCase(),
            style: GDtype.wordmark(
              size: 10,
              color: active ? Colors.white : t.body,
              trackingEm: 0.1,
            ).copyWith(
              shadows: <Shadow>[
                Shadow(
                  color: active
                      ? const Color(0x66000000)
                      : t.dark
                          ? const Color(0x66000000)
                          : const Color(0x99FFFFFF),
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SerialPlate extends StatelessWidget {
  const _SerialPlate({required this.serial, required this.theme});
  final String serial;
  final GoDeskTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: theme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2.5),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: InsetShadowPainter(theme: theme, borderRadius: 3, depth: 2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Text(
                serial,
                style: GDtype.mono(
                  size: 9,
                  weight: FontWeight.w600,
                  color: theme.subtle,
                  letterSpacing: 0.36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficLights extends StatelessWidget {
  const _TrafficLights();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _TrafficDot(
          color: const Color(0xFFFF5F57),
          tooltip: 'Close (hide to tray)',
          onTap: () async {
            // setPreventClose intercepts and routes to TrayController.onWindowClose,
            // which calls windowManager.hide(). User can still Quit from tray menu.
            await windowManager.close();
          },
        ),
        const SizedBox(width: 6),
        _TrafficDot(
          color: const Color(0xFFFEBC2E),
          tooltip: 'Minimize',
          onTap: () => windowManager.minimize(),
        ),
        const SizedBox(width: 6),
        _TrafficDot(
          color: const Color(0xFF28C840),
          tooltip: 'Maximize / restore',
          onTap: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
      ],
    );
  }
}

class _TrafficDot extends StatelessWidget {
  const _TrafficDot({
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.15), width: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
