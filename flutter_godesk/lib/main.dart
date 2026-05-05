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

class GoDeskApp extends StatelessWidget {
  const GoDeskApp({
    required this.controller,
    required this.bridge,
    super.key,
  });

  final TweaksController controller;
  final Bridge bridge;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final tw = controller.value;
        final godeskTheme = makeSkeuoTheme(
          dark: tw.darkMode,
          accentName: tw.accent,
          lcdName: tw.lcd,
          intensity: tw.intensity,
        );
        return BridgeProvider(
          bridge: bridge,
          child: MaterialApp(
            title: 'GoDesk',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: tw.darkMode ? Brightness.dark : Brightness.light,
              scaffoldBackgroundColor: godeskTheme.bg,
              extensions: <ThemeExtension<dynamic>>[godeskTheme],
            ),
            home: GoDeskShell(controller: controller),
          ),
        );
      },
    );
  }
}
