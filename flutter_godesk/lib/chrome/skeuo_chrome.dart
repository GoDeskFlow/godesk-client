// SkeuoChrome — 44px brushed-metal title bar with traffic lights, GoDesk
// wordmark, segmented screen tabs, and a serial-number plate on the right.
// Direct port of `SkeuoChrome` from godesk-skeuo-chrome.jsx.

import 'package:flutter/material.dart';

import '../kit/_internal/inset_painter.dart';
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
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: t.chromeGradient,
        border: Border(bottom: BorderSide(color: t.chromeBorder)),
      ),
      child: Stack(
        children: <Widget>[
          // Brushed-metal vertical stripes overlay.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(decoration: BoxDecoration(gradient: t.brushedStripes)),
            ),
          ),
          Row(
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
                        'GoDesk',
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
        color: t.panel,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: t.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.5),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: InsetShadowPainter(theme: t, borderRadius: 5, depth: 3),
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
                    Container(width: 1, color: t.border),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color: t.accentGlow.withValues(alpha: 1 / 3),
                      blurRadius: 6,
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
                      ? const Color(0x40000000)
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
      children: const <Widget>[
        _TrafficDot(color: Color(0xFFFF5F57)),
        SizedBox(width: 6),
        _TrafficDot(color: Color(0xFFFEBC2E)),
        SizedBox(width: 6),
        _TrafficDot(color: Color(0xFF28C840)),
      ],
    );
  }
}

class _TrafficDot extends StatelessWidget {
  const _TrafficDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.15), width: 0.5),
      ),
    );
  }
}
