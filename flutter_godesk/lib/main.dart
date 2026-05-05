// flutter_godesk — entry point.

import 'dart:io';

import 'package:flutter/material.dart';

import 'app/godesk_app.dart';
import 'bridge/bridge.dart';
import 'bridge/mock_bridge.dart';
import 'bridge/provider.dart';
import 'bridge/real_bridge.dart';
import 'theme/godesk_theme.dart';
import 'theme/tweaks.dart';
import 'util/platform_polish.dart';

/// Compile-time switch: build with
///   `flutter build windows --release --dart-define=GODESK_REAL_BRIDGE=true`
/// to use the production FFI bridge (loads librustdesk.dll). Default is
/// `MockBridge` so `flutter run` from a fresh checkout still works without
/// a Rust core build.
///
/// macOS / Linux: RealBridge requires per-platform `librustdesk` binaries
/// that aren't built yet. Until those land, those platforms always run
/// the mock UI regardless of this define.
const bool _kUseRealBridgeRequested =
    bool.fromEnvironment('GODESK_REAL_BRIDGE', defaultValue: false);

bool get _kUseRealBridge => _kUseRealBridgeRequested && Platform.isWindows;

Future<void> main() async {
  // Single-instance lock first — if a copy is already running, exit before
  // any window or tray icon appears.
  enforceSingleInstance();

  WidgetsFlutterBinding.ensureInitialized();
  await initCrashLog();
  await tray.init();

  final controller = await TweaksController.create();
  // Phase 2.4 wired: GODESK_REAL_BRIDGE=true → real FFI to librustdesk.dll;
  // unset → MockBridge (current default for clean development checkouts).
  final Bridge bridge = _kUseRealBridge ? RealBridge() : MockBridge();
  runApp(GoDeskApp(controller: controller, bridge: bridge));
}

class GoDeskApp extends StatefulWidget {
  const GoDeskApp({
    required this.controller,
    required this.bridge,
    super.key,
  });

  final TweaksController controller;
  final Bridge bridge;

  @override
  State<GoDeskApp> createState() => _GoDeskAppState();
}

class _GoDeskAppState extends State<GoDeskApp>
    with SingleTickerProviderStateMixin {
  /// Last-seen tweaks fingerprint. When this changes (user flipped dark
  /// mode, picked a new accent, etc.), we run a brief cross-fade overlay
  /// so the UI doesn't snap from one palette to the other in a single
  /// frame. Skeuo widgets don't support tween-by-color natively because
  /// the theme is a `ThemeExtension`, so masking the swap is the cheap
  /// workable approach.
  late final AnimationController _swap;
  String? _lastFp;

  @override
  void initState() {
    super.initState();
    _swap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    widget.controller.addListener(_onTweaks);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTweaks);
    _swap.dispose();
    super.dispose();
  }

  void _onTweaks() {
    final tw = widget.controller.value;
    final fp = '${tw.darkMode}|${tw.accent}|${tw.lcd}|${tw.intensity}';
    if (_lastFp != null && _lastFp != fp) {
      _swap.forward(from: 0).then((_) => _swap.value = 0);
    }
    _lastFp = fp;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final tw = widget.controller.value;
        _lastFp ??= '${tw.darkMode}|${tw.accent}|${tw.lcd}|${tw.intensity}';
        final godeskTheme = makeSkeuoTheme(
          dark: tw.darkMode,
          accentName: tw.accent,
          lcdName: tw.lcd,
          intensity: tw.intensity,
        );
        return BridgeProvider(
          bridge: widget.bridge,
          child: MaterialApp(
            title: 'GoDesk',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: tw.darkMode ? Brightness.dark : Brightness.light,
              scaffoldBackgroundColor: godeskTheme.bg,
              extensions: <ThemeExtension<dynamic>>[godeskTheme],
            ),
            home: Stack(
              children: <Widget>[
                Positioned.fill(child: GoDeskShell(controller: widget.controller)),
                // Theme-swap fade — opaque at the midpoint so the frame
                // where the palette flips is fully masked, then fades
                // back out.
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _swap,
                    builder: (_, __) {
                      // Triangle wave: 0 → 1 at t=0.5 → 0 at t=1.0
                      final v = _swap.value;
                      final alpha = v < 0.5 ? v * 2 : (1 - v) * 2;
                      return ColoredBox(
                        color: godeskTheme.bg.withValues(alpha: alpha),
                        child: const SizedBox.expand(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
