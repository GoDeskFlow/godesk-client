// Top-level GoDesk app — chrome + screen routing + connecting overlay +
// active session overlay + footer status bar + onboarding mode.
// Port of GoDeskSkeuoApp from godesk-skeuo-app.jsx.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chrome/skeuo_chrome.dart';
import '../data/peers.dart';
import '../kit/status_led.dart';
import '../kit/tactile_button.dart';
import '../screens/connecting_overlay.dart';
import '../screens/files.dart';
import '../screens/home.dart';
import '../screens/onboarding.dart';
import '../screens/session.dart';
import '../screens/settings.dart';
import '../theme/godesk_theme.dart';
import '../theme/tweaks.dart';
import '../theme/typography.dart';

class GoDeskShell extends StatefulWidget {
  const GoDeskShell({required this.controller, super.key});
  final TweaksController controller;

  @override
  State<GoDeskShell> createState() => _GoDeskShellState();
}

class _GoDeskShellState extends State<GoDeskShell> {
  SkeuoTab _tab = _envInitialTab();
  bool _onboarding = _envInitialOnboarding();
  Peer? _connecting = _envInitialConnecting();
  Peer? _session = _envInitialSession();

  static SkeuoTab _envInitialTab() {
    const v = String.fromEnvironment('GODESK_INIT_TAB');
    return switch (v) {
      'files' => SkeuoTab.files,
      'settings' => SkeuoTab.settings,
      _ => SkeuoTab.home,
    };
  }

  static bool _envInitialOnboarding() =>
      const String.fromEnvironment('GODESK_INIT') == 'onboarding';

  static Peer? _envInitialConnecting() =>
      const String.fromEnvironment('GODESK_INIT') == 'connecting' ? recentPeers.first : null;

  static Peer? _envInitialSession() =>
      const String.fromEnvironment('GODESK_INIT') == 'session' ? recentPeers.first : null;

  void _connect(Peer p) => setState(() => _connecting = p);
  void _connectComplete() {
    setState(() {
      _session = _connecting;
      _connecting = null;
    });
  }

  void _disconnect() => setState(() => _session = null);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_keyHandler);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_keyHandler);
    super.dispose();
  }

  bool _keyHandler(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.digit1) {
      setState(() => _tab = SkeuoTab.home);
      return true;
    }
    if (k == LogicalKeyboardKey.digit2) {
      setState(() => _tab = SkeuoTab.files);
      return true;
    }
    if (k == LogicalKeyboardKey.digit3) {
      setState(() => _tab = SkeuoTab.settings);
      return true;
    }
    if (k == LogicalKeyboardKey.keyO) {
      setState(() => _onboarding = !_onboarding);
      return true;
    }
    if (k == LogicalKeyboardKey.keyC) {
      _connect(recentPeers.first);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return Scaffold(
      backgroundColor: t.bg.darken(0.02),
      body: Center(
        child: Container(
          width: 920,
          height: 620,
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: t.chromeBorder),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x4D000000), spreadRadius: 1),
              BoxShadow(color: Color(0x4D000000), offset: Offset(0, 24), blurRadius: 60),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _onboarding ? _onboardingShell(t) : _normalShell(t),
          ),
        ),
      ),
    );
  }
}

extension _GoDeskShellPrivate on _GoDeskShellState {
  Widget _onboardingShell(GoDeskTheme t) {
    return Column(
      children: <Widget>[
        SkeuoChrome(current: _tab, onTab: (_) {}),
        Expanded(
          child: OnboardingScreen(onComplete: () => setState(() => _onboarding = false)),
        ),
      ],
    );
  }

  Widget _normalShell(GoDeskTheme t) {
    return Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            SkeuoChrome(
              current: _tab,
              onTab: (v) => setState(() => _tab = v),
            ),
            Expanded(child: _screen()),
            _Footer(onLaunchOnboarding: () => setState(() => _onboarding = true)),
          ],
        ),
        if (_connecting != null)
          Positioned.fill(
            child: ConnectingOverlay(
              peerId: _connecting!.id,
              onCancel: () => setState(() => _connecting = null),
              onComplete: _connectComplete,
            ),
          ),
        if (_session != null)
          Positioned.fill(
            child: SessionScreen(peer: _session!, onDisconnect: _disconnect),
          ),
      ],
    );
  }

  Widget _screen() {
    return switch (_tab) {
      SkeuoTab.home => HomeScreen(onConnect: _connect),
      SkeuoTab.files => const FilesScreen(),
      SkeuoTab.settings => const SettingsScreen(),
    };
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onLaunchOnboarding});
  final VoidCallback onLaunchOnboarding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: t.chromeGradient,
        border: Border(top: BorderSide(color: t.chromeBorder)),
      ),
      child: Row(
        children: <Widget>[
          const StatusLED(color: LEDColors.online, pulse: true, size: 6),
          const SizedBox(width: 8),
          Text('RELAY EU-WEST-1',
              style: GDtype.mono(size: 9, weight: FontWeight.w700, color: t.subtle, letterSpacing: 0.5)),
          const SizedBox(width: 6),
          Text('· P2P · 12ms · AES-256',
              style: GDtype.mono(size: 9, color: t.subtle, letterSpacing: 0.5)),
          const Spacer(),
          SizedBox(
            height: 18,
            child: TactileButton(
              small: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: onLaunchOnboarding,
              child: const Text('▸ ONBOARDING'),
            ),
          ),
          const SizedBox(width: 8),
          Text('v0.1.0',
              style: GDtype.mono(size: 9, color: t.subtle, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

extension on Color {
  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}
