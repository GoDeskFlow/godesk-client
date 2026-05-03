// flutter_godesk — entry point.

import 'package:flutter/material.dart';

import 'app/godesk_app.dart';
import 'theme/godesk_theme.dart';
import 'theme/tweaks.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await TweaksController.create();
  runApp(GoDeskApp(controller: controller));
}

class GoDeskApp extends StatelessWidget {
  const GoDeskApp({required this.controller, super.key});

  final TweaksController controller;

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
        return MaterialApp(
          title: 'GoDesk',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: tw.darkMode ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: godeskTheme.bg,
            extensions: <ThemeExtension<dynamic>>[godeskTheme],
          ),
          home: GoDeskShell(controller: controller),
        );
      },
    );
  }
}
