// Onboarding — 4-step first-run flow.
// Port of godesk-skeuo-screens.jsx → SkeuoOnboarding.

import 'package:flutter/material.dart';

import '../bridge/provider.dart';
import '../chrome/skeuo_logo.dart';
import '../data/peers.dart';
import '../kit/lcd_panel.dart';
import '../kit/metal_panel.dart';
import '../kit/section_label.dart';
import '../kit/status_led.dart';
import '../kit/tactile_button.dart';
import '../theme/godesk_theme.dart';
import '../theme/typography.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onComplete, super.key});
  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  String _name = '';
  final Map<String, bool> _perms = <String, bool>{
    'accessibility': false,
    'screen': false,
    'input': false,
  };

  static const _stepNames = <String>['Welcome', 'Identify', 'Permissions', 'Ready'];

  bool get _allGranted => _perms.values.every((v) => v);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: t.dark
              ? const <Color>[Color(0xFF1C1D22), Color(0xFF16171B)]
              : const <Color>[Color(0xFFE8E4DC), Color(0xFFD8D3C8)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            _stepIndicator(t),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: MetalPanel(
                    padding: const EdgeInsets.all(28),
                    child: SingleChildScrollView(child: _bodyForStep(t)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepIndicator(GoDeskTheme t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var i = 0; i < _stepNames.length; i++) ...<Widget>[
          _stepChip(t, i, _stepNames[i]),
          if (i < _stepNames.length - 1)
            Container(width: 16, height: 1, color: t.border),
        ],
      ],
    );
  }

  Widget _stepChip(GoDeskTheme t, int i, String label) {
    final active = i == _step;
    final past = i < _step;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: active
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[t.accent, t.accentDark],
              )
            : past
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xFF34D058), Color(0xFF22A843)],
                  )
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[t.panelHi, t.panel],
                  ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active
              ? t.accentDark
              : past
                  ? const Color(0xFF22A843)
                  : t.border,
        ),
        boxShadow: active
            ? <BoxShadow>[
                BoxShadow(color: t.accentGlow.withValues(alpha: 0.4), blurRadius: 8),
              ]
            : const <BoxShadow>[],
      ),
      child: Text(
        '${i + 1}. ${label.toUpperCase()}',
        style: GDtype.wordmark(
          size: 10,
          color: i <= _step ? Colors.white : t.subtle,
          trackingEm: 0.1,
        ),
      ),
    );
  }

  Widget _bodyForStep(GoDeskTheme t) {
    return switch (_step) {
      0 => _stepWelcome(t),
      1 => _stepIdentify(t),
      2 => _stepPermissions(t),
      3 => _stepReady(t),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _stepWelcome(GoDeskTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const SkeuoLogo(size: 64),
        const SizedBox(height: 18),
        Text(
          'Welcome to GoDesk',
          style: GDtype.heading(size: 24, color: t.heading)
              .copyWith(shadows: headingShadow(dark: t.dark)),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            'Remote desktop, dialed in. Connect to any machine on the planet — '
            'encrypted end-to-end, peer-to-peer when possible, your data never '
            'sits on our servers.',
            textAlign: TextAlign.center,
            style: GDtype.ui(size: 13, color: t.body).copyWith(height: 1.55),
          ),
        ),
        const SizedBox(height: 20),
        LCDPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: <Widget>[
              Text('> VERSION', style: lcdDimLabel(theme: t)),
              const SizedBox(height: 2),
              Text('GODESK 0.1.0 · BUILD 26.05.03',
                  style: lcdReadout(theme: t, size: 14)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 200,
          child: TactileButton(
            variant: TactileVariant.primary,
            onPressed: () => setState(() => _step = 1),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('GET STARTED'),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepIdentify(GoDeskTheme t) {
    return Column(
      children: <Widget>[
        Center(
          child: Column(
            children: <Widget>[
              const SectionLabel('Step 02 / 04'),
              const SizedBox(height: 6),
              Text(
                'How should this device appear?',
                textAlign: TextAlign.center,
                style: GDtype.heading(size: 20, color: t.heading)
                    .copyWith(shadows: headingShadow(dark: t.dark)),
              ),
              const SizedBox(height: 4),
              Text(
                'This is what others see when they look you up.',
                style: GDtype.ui(size: 12, color: t.subtle),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: const SectionLabel('Device name'),
        ),
        const SizedBox(height: 6),
        LCDPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: TextField(
            onChanged: (v) => setState(() => _name = v),
            cursorColor: t.lcdInk,
            decoration: InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              hintText: "ALEX'S WINDOWS PC",
              hintStyle: lcdReadout(theme: t, size: 16).copyWith(color: t.lcdDim, shadows: const <Shadow>[]),
            ),
            style: lcdReadout(theme: t, size: 16),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: const SectionLabel('Your permanent ID'),
        ),
        const SizedBox(height: 6),
        LCDPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Expanded(child: Text(myId, style: lcdReadout(theme: t, size: 22))),
              Text('SECURED', style: lcdDimLabel(theme: t)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Your ID is generated locally. It never changes.',
            style: GDtype.ui(size: 11, color: t.subtle),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            TactileButton(
              onPressed: () => setState(() => _step = 0),
              child: const Text('BACK'),
            ),
            TactileButton(
              variant: TactileVariant.primary,
              onPressed: () => setState(() => _step = 2),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('CONTINUE'),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepPermissions(GoDeskTheme t) {
    final perms = <(String, String, String)>[
      ('accessibility', 'Accessibility', 'Required to send keyboard & mouse to this device.'),
      ('screen', 'Screen recording', 'So the remote operator can see your screen.'),
      ('input', 'Input monitoring', 'Captures key events for the remote session.'),
    ];
    return Column(
      children: <Widget>[
        Center(
          child: Column(
            children: <Widget>[
              const SectionLabel('Step 03 / 04'),
              const SizedBox(height: 6),
              Text(
                'System permissions',
                style: GDtype.heading(size: 20, color: t.heading)
                    .copyWith(shadows: headingShadow(dark: t.dark)),
              ),
              const SizedBox(height: 4),
              Text(
                'Required so others can control this PC.',
                style: GDtype.ui(size: 12, color: t.subtle),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final p in perms) ...<Widget>[
          _permRow(t, p.$1, p.$2, p.$3),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            TactileButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('BACK'),
            ),
            TactileButton(
              variant: TactileVariant.primary,
              onPressed: _allGranted ? () => setState(() => _step = 3) : null,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('CONTINUE'),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 14),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _permRow(GoDeskTheme t, String key, String label, String desc) {
    final granted = _perms[key]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.dark ? const Color(0x33000000) : const Color(0x0A000000),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: <Widget>[
          StatusLED(
            color: granted ? LEDColors.online : LEDColors.warning,
            pulse: !granted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label,
                    style: GDtype.ui(size: 12, weight: FontWeight.w700, color: t.heading)),
                const SizedBox(height: 1),
                Text(desc, style: GDtype.ui(size: 10, color: t.subtle)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TactileButton(
            small: true,
            variant: granted ? TactileVariant.defaultStyle : TactileVariant.primary,
            onPressed: () => setState(() => _perms[key] = !granted),
            child: granted
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.check, size: 11),
                      SizedBox(width: 4),
                      Text('GRANTED'),
                    ],
                  )
                : const Text('GRANT'),
          ),
        ],
      ),
    );
  }

  Widget _stepReady(GoDeskTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF34D058), Color(0xFF22A843)],
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x66229843), offset: Offset(0, 8), blurRadius: 20),
              BoxShadow(color: Color(0x8034D058), blurRadius: 32),
            ],
          ),
          child: const Icon(Icons.check, size: 44, color: Colors.white),
        ),
        const SizedBox(height: 18),
        Text("You're all set",
            style: GDtype.heading(size: 24, color: t.heading)
                .copyWith(shadows: headingShadow(dark: t.dark))),
        const SizedBox(height: 8),
        Text('GoDesk is online and ready to connect.',
            style: GDtype.ui(size: 13, color: t.body)),
        const SizedBox(height: 16),
        LCDPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('> STATUS', style: lcdDimLabel(theme: t)),
                  const Spacer(),
                  Text('READY', style: lcdReadout(theme: t, size: 10)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Text('> ID', style: lcdDimLabel(theme: t)),
                  const Spacer(),
                  Text(myId, style: lcdReadout(theme: t, size: 10)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Text('> RELAY', style: lcdDimLabel(theme: t)),
                  const Spacer(),
                  Text('EU-WEST-1', style: lcdReadout(theme: t, size: 10)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: 220,
          child: TactileButton(
            variant: TactileVariant.primary,
            onPressed: () async {
              // Persist the device name the user chose on step 02 so the
              // RustDesk core advertises it to remote operators. Empty
              // name → leave RustDesk default (machine hostname).
              final name = _name.trim();
              if (name.isNotEmpty) {
                await BridgeProvider.of(context).setOption('hostname', name);
              }
              widget.onComplete();
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('ENTER GODESK'),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
