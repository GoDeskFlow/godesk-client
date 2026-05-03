// StatusLED — glowing colored dot used for online/offline/warning indicators.
// Direct port of `StatusLED` from godesk-skeuo-kit.jsx.
//
// Three states:
//   - default (steady):       static dot + glow halo
//   - pulse=true (online):     2s breathe (opacity + brightness)
//   - blink=true (warning):    1.4s harsh blink (opacity 1 ↔ 0.3)
//
// Reduced motion (Phase 2.3 a11y): when MediaQuery.disableAnimationsOf is
// true, freeze the LED in fully-lit state — no breathe, no blink.

import 'package:flutter/material.dart';

import '../util/a11y.dart';

class StatusLED extends StatefulWidget {
  const StatusLED({
    this.color = const Color(0xFF22C55E),
    this.size = 7,
    this.pulse = false,
    this.blink = false,
    super.key,
  });

  final Color color;
  final double size;
  final bool pulse;
  final bool blink;

  @override
  State<StatusLED> createState() => _StatusLEDState();
}

class _StatusLEDState extends State<StatusLED> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: widget.blink ? const Duration(milliseconds: 1400) : const Duration(seconds: 2),
    );
    if (widget.pulse || widget.blink) _ac.repeat(reverse: false);
  }

  @override
  void didUpdateWidget(StatusLED old) {
    super.didUpdateWidget(old);
    if ((widget.pulse || widget.blink) != (old.pulse || old.blink)) {
      if (widget.pulse || widget.blink) {
        _ac.repeat();
      } else {
        _ac.stop();
        _ac.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  double _opacityFor(double v) {
    // godesk-led-breathe: 0/100% opacity 1 ↔ 50% opacity 0.7
    if (widget.pulse) return 1.0 - 0.3 * (1 - (v - 0.5).abs() * 2).abs();
    // godesk-blink: 0/100% opacity 1 ↔ 50% opacity 0.3
    if (widget.blink) return 1.0 - 0.7 * (1 - (v - 0.5).abs() * 2).abs();
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    // Reduced-motion (Phase 2.3 a11y): freeze the LED in fully-lit state.
    if (reducedMotion(context) && _ac.isAnimating) {
      _ac.stop();
      _ac.value = 0;
    }
    return AnimatedBuilder(
      animation: _ac,
      builder: (context, _) {
        final op = _opacityFor(_ac.value);
        return Opacity(
          opacity: op,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: widget.color, blurRadius: widget.size),
              ],
            ),
            // Inset top highlight — small bright cap on the dot.
            child: ClipOval(
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Standard LED colors used across the kit.
class LEDColors {
  static const online = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFE25555);
  static const offline = Color(0xFF6B7280);
}
