// BridgeProvider — `InheritedWidget` exposing a `Bridge` instance to the
// whole widget subtree.
//
// Screens use `Bridge.of(context)` instead of importing concrete data
// modules. The provider's bridge is constructed once in main.dart
// (`MockBridge()` today, `RealBridge()` once Phase 2.4 wiring lands).

import 'package:flutter/widgets.dart';

import 'bridge.dart';

class BridgeProvider extends InheritedWidget {
  const BridgeProvider({
    required this.bridge,
    required super.child,
    super.key,
  });

  final Bridge bridge;

  static Bridge of(BuildContext context) {
    final p = context.dependOnInheritedWidgetOfExactType<BridgeProvider>();
    assert(p != null, 'No BridgeProvider in widget tree above this context.');
    return p!.bridge;
  }

  @override
  bool updateShouldNotify(BridgeProvider oldWidget) => bridge != oldWidget.bridge;
}
