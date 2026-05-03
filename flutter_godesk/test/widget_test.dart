// Smoke test — boots the app, asserts MaterialApp present.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/material.dart';
import 'package:flutter_godesk/main.dart';
import 'package:flutter_godesk/theme/tweaks.dart';

void main() {
  testWidgets('GoDesk app boots', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final controller = await TweaksController.create();
    await tester.pumpWidget(GoDeskApp(controller: controller));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
