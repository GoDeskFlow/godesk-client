// SessionScreen — full-bleed dark panel with floating toolbar over a fake
// remote desktop frame. Port of SkeuoSession from godesk-skeuo-app.jsx.

import 'package:flutter/material.dart';

import '../data/peers.dart';
import '../kit/status_led.dart';
import '../kit/tactile_button.dart';
import '../theme/godesk_theme.dart';
import '../theme/typography.dart';

class SessionScreen extends StatelessWidget {
  const SessionScreen({
    required this.peer,
    required this.onDisconnect,
    super.key,
  });

  final Peer peer;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final bg = switch (peer.os) {
      PeerOS.macos => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF1A3A5C), Color(0xFF4D2A5E), Color(0xFFD96A4C)],
          stops: <double>[0.0, 0.6, 1.0],
        ),
      PeerOS.windows => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0078D4), Color(0xFF1BA1E2), Color(0xFF00B294)],
        ),
      PeerOS.linux => const RadialGradient(
          center: Alignment(-0.4, -0.2),
          radius: 1.2,
          colors: <Color>[Color(0xFF2A3142), Color(0xFF0C0D12)],
        ),
    };

    return Container(
      color: const Color(0xFF0A0A0A),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: bg),
              child: const _SessionInner(),
            ),
          ),
          // Floating toolbar
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: t.chromeGradient,
                  border: Border.all(color: t.chromeBorder),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0x66000000), offset: Offset(0, 6), blurRadius: 20),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const StatusLED(color: LEDColors.online, pulse: true),
                          const SizedBox(width: 6),
                          Text(peer.name,
                              style: GDtype.ui(size: 11, weight: FontWeight.w700, color: t.heading, letterSpacing: 0.44)),
                          const SizedBox(width: 6),
                          Text('· ${peer.id}',
                              style: GDtype.mono(size: 10, color: t.heading.withValues(alpha: 0.55))),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 16, color: t.border),
                    const SizedBox(width: 4),
                    TactileButton(
                      small: true,
                      onPressed: () {},
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.computer_outlined, size: 12),
                          SizedBox(width: 4),
                          Text('VIEW'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    TactileButton(
                      small: true,
                      onPressed: () {},
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.folder_outlined, size: 12),
                          SizedBox(width: 4),
                          Text('FILES'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    TactileButton(
                      small: true,
                      onPressed: () {},
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.lock_outline, size: 12),
                          SizedBox(width: 4),
                          Text('LOCK'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(width: 1, height: 16, color: t.border),
                    const SizedBox(width: 4),
                    TactileButton(
                      small: true,
                      variant: TactileVariant.danger,
                      onPressed: onDisconnect,
                      child: const Text('DISCONNECT'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionInner extends StatelessWidget {
  const _SessionInner();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.computer_outlined, size: 56, color: Color(0xD9FFFFFF)),
          SizedBox(height: 12),
          Text(
            'Remote desktop active',
            style: TextStyle(
              color: Color(0xD9FFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.56,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '1920 × 1080 · 60 fps · 24 ms',
            style: TextStyle(
              color: Color(0xB3FFFFFF),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
