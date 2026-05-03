// flutter_godesk — entry point.

import 'package:flutter/material.dart';

import 'app/godesk_app.dart';
import 'bridge/bridge.dart';
import 'bridge/mock_bridge.dart';
import 'bridge/provider.dart';
import 'theme/godesk_theme.dart';
import 'theme/tweaks.dart';
import 'util/platform_polish.dart';

Future<void> main() async {
  // Single-instance lock first — if a copy is already running, exit before
  // any window or tray icon appears.
  enforceSingleInstance();

  WidgetsFlutterBinding.ensureInitialized();
  await initCrashLog();
  await tray.init();

  final controller = await TweaksController.create();
  // Phase 2.4 swap point: replace `MockBridge()` with `RealBridge()` once
  // the FFI codegen + wiring is complete. UI code reads through the
  // `Bridge` abstraction so no screen needs to change.
  final Bridge bridge = MockBridge();
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
