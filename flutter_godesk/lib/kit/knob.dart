// Knob — 64 × 64 rotary knob.
// Direct port of `Knob` from godesk-skeuo-screens.jsx.
//
// Mark rotates from −135° to +135° around (value/100). Five tick marks at
// 0/25/50/75/100. Click increments value by 10 (mod 110); a real
// implementation supports drag — added here as a vertical-drag that maps
// 100 px of upward drag = full sweep.
//
// LCD readout for the value sits next to the knob (handled by caller).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/godesk_theme.dart';

class Knob extends StatefulWidget {
  const Knob({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 0..100
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<Knob> createState() => _KnobState();
}

class _KnobState extends State<Knob> {
  double? _dragStartValue;
  double? _dragStartY;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final angle = (-135 + (widget.value / 100) * 270) * math.pi / 180;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            widget.onChanged(((widget.value + 10) % 110).clamp(0.0, 100.0)),
        onVerticalDragStart: (d) {
          _dragStartValue = widget.value;
          _dragStartY = d.globalPosition.dy;
        },
        onVerticalDragUpdate: (d) {
          if (_dragStartValue == null || _dragStartY == null) return;
          final delta = (_dragStartY! - d.globalPosition.dy);
          final v = (_dragStartValue! + delta).clamp(0.0, 100.0);
          widget.onChanged(v);
        },
        onVerticalDragEnd: (_) {
          _dragStartValue = null;
          _dragStartY = null;
        },
        child: SizedBox(
          width: 64,
          height: 64,
          child: CustomPaint(
            painter: _KnobPainter(theme: t),
            child: Stack(
              children: <Widget>[
                // Mark — rotates around center.
                Center(
                  child: Transform.rotate(
                    angle: angle,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: angle, end: angle),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      builder: (context, _, __) => SizedBox(
                        width: 64,
                        height: 64,
                        child: CustomPaint(
                          painter: _MarkPainter(
                            angleRad: angle,
                            color: t.accent,
                            glow: t.accentGlow,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Center recess dot.
                Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[t.bg, t.panel],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                          spreadRadius: -1,
                        ),
                      ],
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

class _KnobPainter extends CustomPainter {
  const _KnobPainter({required this.theme});
  final GoDeskTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Body — radial gradient (darker rim, lit top-left).
    final body = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4), // ~ "circle at 35% 30%"
        radius: 0.85,
        colors: <Color>[
          theme.panelHi,
          theme.panel,
          theme.dark ? const Color(0xFF1A1C20) : const Color(0xFFA8A298),
        ],
        stops: const <double>[0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r - 0.5, body);

    // Outer rim border.
    final border = Paint()
      ..color = theme.border
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(c, r - 0.5, border);

    // Drop shadow under the knob (faint).
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(c.translate(0, 4), r - 1, shadow);

    // Tick marks at 0, 25, 50, 75, 100.
    final tick = Paint()
      ..color = theme.subtle
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final v in <int>[0, 25, 50, 75, 100]) {
      final a = (-135 + (v / 100) * 270 - 90) * math.pi / 180;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * 30;
      final p2 = c + Offset(math.cos(a), math.sin(a)) * 33;
      canvas.drawLine(p1, p2, tick);
    }
  }

  @override
  bool shouldRepaint(_KnobPainter old) => old.theme.dark != theme.dark;
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.angleRad,
    required this.color,
    required this.glow,
  });
  final double angleRad;
  final Color color;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angleRad);

    final glowPaint = Paint()
      ..color = glow.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final markPaint = Paint()..color = color;

    final markRect = Rect.fromCenter(
      center: const Offset(0, -22),
      width: 3,
      height: 16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(markRect, const Radius.circular(1.5)),
      glowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(markRect, const Radius.circular(1.5)),
      markPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.angleRad != angleRad || old.color != color;
}
