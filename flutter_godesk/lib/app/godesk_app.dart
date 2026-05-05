// Top-level GoDesk app — chrome + screen routing + connecting overlay +
// active session overlay + footer status bar + onboarding mode.
// Port of GoDeskSkeuoApp from godesk-skeuo-app.jsx.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bridge/bridge.dart';
import '../bridge/provider.dart';
import '../chrome/skeuo_chrome.dart';
import '../config/infra.dart';
import '../data/peers.dart';
import '../data/transfers.dart';
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
import '../util/platform_polish.dart' show tray;

class GoDeskShell extends StatefulWidget {
  const GoDeskShell({required this.controller, super.key});
  final TweaksController controller;

  @override
  State<GoDeskShell> createState() => _GoDeskShellState();
}

class _GoDeskShellState extends State<GoDeskShell>
    with SingleTickerProviderStateMixin {
  SkeuoTab _tab = _envInitialTab();
  bool _onboarding = _envInitialOnboarding();
  bool _onboardingChecked = false;
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

  /// HomeScreen invokes this with the chosen ConnectMode wire-value. We
  /// remember it on the shell so ConnectingOverlay → bridge.connect can
  /// pass the right session-flags via the mode argument.
  String? _pendingMode;
  void _connect(Peer p, {String? mode}) {
    setState(() {
      _connecting = p;
      _pendingMode = mode;
    });
  }
  void _connectComplete() {
    final p = _connecting;
    setState(() {
      _session = p;
      _connecting = null;
      _userDisconnected = false;
      if (p != null) {
        _reconnectInfo = (peer: p, mode: _pendingMode);
      }
    });
  }

  void _disconnect() {
    _userDisconnected = true;
    _reconnectInfo = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    setState(() => _session = null);
  }

  /// True when [_disconnect] was invoked by the user clicking
  /// DISCONNECT. Cleared on every successful new connect. The bridge
  /// stream tells us when a session ends; without this flag we can't
  /// distinguish "the user asked to disconnect" from "the network died
  /// and the bridge dropped the session". Auto-reconnect should only
  /// trigger in the second case.
  bool _userDisconnected = false;

  /// Snapshot of the last-active peer + mode, used by the auto-reconnect
  /// flow if the session drops.
  ({Peer peer, String? mode})? _reconnectInfo;

  /// Countdown timer for the "reconnect in N seconds" prompt that pops
  /// up after an unexpected drop.
  Timer? _reconnectTimer;
  int _reconnectSecondsLeft = 0;
  static const int _reconnectInitialDelay = 5;

  StreamSubscription<SessionState>? _sessionSub;

  /// Listen for the bridge marking the session as gone (peerId == null
  /// while we still hold a `_session`). If the user didn't trigger this,
  /// kick off the reconnect prompt.
  void _watchSessionEnd() {
    _sessionSub?.cancel();
    _sessionSub = BridgeProvider.of(context).sessionState().listen((s) {
      if (!mounted) return;
      if (_session != null && s.peerId == null) {
        if (_userDisconnected) {
          _userDisconnected = false;
          return;
        }
        _startReconnectPrompt();
      }
    });
  }

  void _startReconnectPrompt() {
    if (_reconnectInfo == null) {
      setState(() => _session = null);
      return;
    }
    setState(() {
      _session = null;
      _reconnectSecondsLeft = _reconnectInitialDelay;
    });
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _reconnectTimer?.cancel();
        return;
      }
      setState(() => _reconnectSecondsLeft -= 1);
      if (_reconnectSecondsLeft <= 0) {
        _reconnectTimer?.cancel();
        final info = _reconnectInfo;
        if (info != null) {
          _connect(info.peer, mode: info.mode);
        }
      }
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    setState(() {
      _reconnectInfo = null;
      _reconnectSecondsLeft = 0;
    });
  }

  void _reconnectNow() {
    _reconnectTimer?.cancel();
    final info = _reconnectInfo;
    if (info == null) return;
    setState(() => _reconnectSecondsLeft = 0);
    _connect(info.peer, mode: info.mode);
  }

  /// Brief flash when the user clicks the tray icon — visual ack so the
  /// click is acknowledged even if the window was already foregrounded.
  late final AnimationController _trayFlash;
  StreamSubscription<void>? _traySub;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_keyHandler);
    _trayFlash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _traySub = tray.trayPings.listen((_) {
      if (!mounted) return;
      _trayFlash.forward(from: 0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchSessionEnd();
    if (!_onboardingChecked) {
      _onboardingChecked = true;
      // Check if we need to show onboarding. The env-flag override always
      // wins (used by integration tests + screenshots).
      if (_envInitialOnboarding()) return;
      BridgeProvider.of(context).getOption('godesk-onboarding-complete').then((v) {
        if (!mounted) return;
        // Empty/missing → first-run, show onboarding.
        if (v.isEmpty) setState(() => _onboarding = true);
      });
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _onboarding = false);
    await BridgeProvider.of(context).setOption('godesk-onboarding-complete', '1');
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_keyHandler);
    _trayFlash.dispose();
    _traySub?.cancel();
    _sessionSub?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }

  bool _shortcutsOpen = false;

  bool _keyHandler(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    // Tab-switch shortcuts must not fire when the session overlay is up
    // (those shortcuts there belong to the remote OS) or when any modifier
    // is held — Ctrl+1..3 is reserved for switch-display in SessionScreen.
    if (_session != null) return false;
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return false;
    }
    final k = event.logicalKey;
    // F1 opens the shortcuts overlay (closes if already open). Esc closes
    // it without triggering anything else. Both fire even when the
    // shortcuts panel is up so the user can dismiss it the same way.
    if (k == LogicalKeyboardKey.f1) {
      setState(() => _shortcutsOpen = !_shortcutsOpen);
      return true;
    }
    if (_shortcutsOpen && k == LogicalKeyboardKey.escape) {
      setState(() => _shortcutsOpen = false);
      return true;
    }
    if (_shortcutsOpen) return false;
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

  Widget _onboardingShell(GoDeskTheme t) {
    return Column(
      children: <Widget>[
        SkeuoChrome(current: _tab, onTab: (_) {}),
        Expanded(
          child: OnboardingScreen(onComplete: _completeOnboarding),
        ),
      ],
    );
  }

  Widget _normalShell(GoDeskTheme t) {
    return Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            // Tab badges sourced from the bridge's transfer stream so the
            // user sees a red dot on Files when something needs attention
            // (or accent dot when transfers are in flight on another tab).
            StreamBuilder<List<TransferItem>>(
              stream: BridgeProvider.of(context).transfers(),
              initialData: const <TransferItem>[],
              builder: (context, snap) {
                final q = snap.data ?? const <TransferItem>[];
                final hasFailed = q.any((it) => it.failed);
                final hasActive =
                    q.any((it) => !it.done && !it.queued && !it.failed) ||
                        q.any((it) => it.queued);
                final filesBadge = hasFailed
                    ? TabBadge.alert
                    : hasActive
                        ? TabBadge.info
                        : TabBadge.none;
                return SkeuoChrome(
                  current: _tab,
                  onTab: (v) => setState(() => _tab = v),
                  badges: <SkeuoTab, TabBadge>{
                    SkeuoTab.files: filesBadge,
                  },
                );
              },
            ),
            Expanded(child: _screen()),
            _Footer(onLaunchOnboarding: () => setState(() => _onboarding = true)),
          ],
        ),
        if (_connecting != null)
          Positioned.fill(
            child: ConnectingOverlay(
              peerId: _connecting!.id,
              mode: _pendingMode,
              onCancel: () => setState(() => _connecting = null),
              onComplete: _connectComplete,
            ),
          ),
        if (_session != null)
          Positioned.fill(
            child: SessionScreen(peer: _session!, onDisconnect: _disconnect),
          ),
        if (_session == null &&
            _reconnectInfo != null &&
            _reconnectSecondsLeft > 0)
          Positioned(
            top: 16,
            right: 16,
            child: _ReconnectPrompt(
              peer: _reconnectInfo!.peer,
              secondsLeft: _reconnectSecondsLeft,
              onCancel: _cancelReconnect,
              onReconnectNow: _reconnectNow,
            ),
          ),
        if (_shortcutsOpen)
          Positioned.fill(
            child: _ShortcutsOverlay(
              inSession: _session != null,
              onClose: () => setState(() => _shortcutsOpen = false),
            ),
          ),
        // Tray-click ack: brief accent-tinted full-bleed flash that
        // peaks at 22% opacity, ~450ms total. IgnorePointer so it never
        // blocks input. Dismisses itself once the AnimationController
        // returns to 0.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _trayFlash,
              builder: (_, __) {
                if (_trayFlash.value == 0) return const SizedBox.shrink();
                final v = _trayFlash.value;
                final eased = v < 0.5 ? v * 2 : (1 - v) * 2;
                return ColoredBox(
                  color: t.accent.withValues(alpha: 0.22 * eased),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _screen() {
    return switch (_tab) {
      SkeuoTab.home => HomeScreen(onConnect: _connect),
      SkeuoTab.files => const FilesScreen(),
      SkeuoTab.settings => SettingsScreen(tweaks: widget.controller),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    // Phase 2.3 final: frameless window — SkeuoChrome IS the OS chrome.
    // UI fills the entire window; size is constrained at the OS level
    // via window_manager.minimumSize instead of an inner fixed Container.
    return Scaffold(
      backgroundColor: t.bg,
      body: _onboarding ? _onboardingShell(t) : _normalShell(t),
    );
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
          // Footer status reflects bridge.diagnostics() — `NOT CONNECTED`
          // when no session is active (empty MockBridge first-run state).
          StreamBuilder<Diagnostics>(
            stream: BridgeProvider.of(context).diagnostics(),
            builder: (context, snap) {
              final d = snap.data;
              final hasRelay = d != null && d.relay != '—';
              final hasLatency = d != null && d.latencyMs > 0;
              return Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                StatusLED(color: hasRelay ? LEDColors.online : LEDColors.offline, pulse: hasRelay, size: 6),
                const SizedBox(width: 8),
                Text(hasRelay ? 'RELAY ${d.relay.toUpperCase()}' : 'NOT CONNECTED',
                    style: GDtype.mono(size: 9, weight: FontWeight.w700, color: t.subtle, letterSpacing: 0.5)),
                if (hasLatency) ...<Widget>[
                  const SizedBox(width: 6),
                  Text('· P2P · ${d.latencyMs}ms · ${d.cipher.replaceAll('-GCM', '')}',
                      style: GDtype.mono(size: 9, color: t.subtle, letterSpacing: 0.5)),
                ],
              ]);
            },
          ),
          const SizedBox(width: 12),
          // Active transfer count — pulses when there's anything in flight,
          // hidden entirely when the queue is empty so the chrome stays
          // calm for the average user.
          StreamBuilder<List<TransferItem>>(
            stream: BridgeProvider.of(context).transfers(),
            initialData: const <TransferItem>[],
            builder: (context, snap) {
              final q = snap.data ?? const <TransferItem>[];
              final active = q.where((it) => !it.done && !it.queued && !it.failed).length;
              final queued = q.where((it) => it.queued).length;
              final failed = q.where((it) => it.failed).length;
              if (active == 0 && queued == 0 && failed == 0) {
                return const SizedBox.shrink();
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(width: 1, height: 12, color: t.chromeBorder),
                  const SizedBox(width: 10),
                  Icon(Icons.sync_alt, size: 10, color: t.subtle),
                  const SizedBox(width: 4),
                  Text(
                    [
                      if (active > 0) '$active ACTIVE',
                      if (queued > 0) '$queued QUEUED',
                      if (failed > 0) '$failed FAILED',
                    ].join(' · '),
                    style: GDtype.mono(
                        size: 9,
                        weight: FontWeight.w700,
                        color: failed > 0 ? const Color(0xFFE03030) : t.subtle,
                        letterSpacing: 0.5),
                  ),
                ],
              );
            },
          ),
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
          Text('v${GoDeskInfra.appVersion}',
              style: GDtype.mono(size: 9, color: t.subtle, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

/// F1 shortcuts cheatsheet — translucent backdrop with a centered card
/// listing every keybinding. Click outside or hit Esc/F1 to dismiss.
/// In-session bindings are listed only when [inSession] is true.
class _ShortcutsOverlay extends StatelessWidget {
  const _ShortcutsOverlay({required this.inSession, required this.onClose});
  final bool inSession;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final globalKeys = <(String, String)>[
      ('F1', 'Toggle this shortcuts overlay'),
      ('Esc', 'Dismiss overlays / dialogs'),
      ('1 / 2 / 3', 'Switch between Home / Files / Settings'),
      ('O', 'Re-open the onboarding flow'),
      ('Ctrl + F', 'Focus address-book search (Home)'),
      ('Right-click peer', 'Connect-as / Rename / Favorite / Remove'),
      ('Delete', 'Cancel / dismiss selected transfer (Files)'),
    ];
    final sessionKeys = <(String, String)>[
      ('Ctrl + 1..9', 'Switch remote display (multi-monitor peers)'),
      ('Drag toolbar', 'Hardware-keys popup → Ctrl+Alt+Del / Win+L / etc.'),
    ];
    return GestureDetector(
      onTap: onClose,
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: const Color(0xCC000000),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // swallow taps so clicking the card doesn't dismiss
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                decoration: BoxDecoration(
                  color: t.panel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.border),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x66000000),
                      offset: Offset(0, 8),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.keyboard_outlined, size: 16, color: t.subtle),
                        const SizedBox(width: 8),
                        Text('Keyboard shortcuts',
                            style: GDtype.ui(
                                size: 14, weight: FontWeight.w700, color: t.heading)),
                        const Spacer(),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: onClose,
                            behavior: HitTestBehavior.opaque,
                            child: Icon(Icons.close, size: 14, color: t.subtle),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final p in globalKeys) _row(t, p.$1, p.$2),
                    if (inSession) ...<Widget>[
                      const SizedBox(height: 10),
                      Text('IN ACTIVE SESSION',
                          style: GDtype.wordmark(
                              size: 9, color: t.subtle, trackingEm: 0.08)),
                      const SizedBox(height: 6),
                      for (final p in sessionKeys) _row(t, p.$1, p.$2),
                    ],
                    const SizedBox(height: 10),
                    Text('Press F1 again to close, or Esc.',
                        style: GDtype.ui(size: 10, color: t.subtle)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(GoDeskTheme t, String key, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: t.bg,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: t.border),
              ),
              child: Text(key,
                  textAlign: TextAlign.center,
                  style: GDtype.mono(size: 10, weight: FontWeight.w700, color: t.heading)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(desc,
                style: GDtype.ui(size: 11, color: t.body)),
          ),
        ],
      ),
    );
  }
}

/// Top-right toast that appears after an unexpected session drop. Counts
/// down [secondsLeft] then triggers reconnect; user can hit RECONNECT
/// NOW to skip the wait or CANCEL to abort. Auto-dismisses when
/// [secondsLeft] hits 0 (parent rebuilds without this widget).
class _ReconnectPrompt extends StatelessWidget {
  const _ReconnectPrompt({
    required this.peer,
    required this.secondsLeft,
    required this.onCancel,
    required this.onReconnectNow,
  });
  final Peer peer;
  final int secondsLeft;
  final VoidCallback onCancel;
  final VoidCallback onReconnectNow;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        decoration: BoxDecoration(
          color: t.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: t.border),
          boxShadow: const <BoxShadow>[
            BoxShadow(
                color: Color(0x40000000), offset: Offset(0, 4), blurRadius: 14),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.wifi_tethering_error, size: 14, color: t.accent),
                const SizedBox(width: 8),
                Text('Session dropped',
                    style: GDtype.ui(
                        size: 12, weight: FontWeight.w700, color: t.heading)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Reconnecting to ${peer.displayName} in ${secondsLeft}s…',
              style: GDtype.ui(size: 11, color: t.body),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TactileButton(
                  small: true,
                  onPressed: onCancel,
                  child: const Text('CANCEL'),
                ),
                const SizedBox(width: 6),
                TactileButton(
                  small: true,
                  variant: TactileVariant.primary,
                  onPressed: onReconnectNow,
                  child: const Text('RECONNECT NOW'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

