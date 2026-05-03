// Platform-polish layer — Windows-only at Phase 2.3 final.
//
// Three concerns that the upstream Flutter scaffold doesn't handle for us:
//
//   1. Single-instance lock — running godesk.exe twice silently spawns a
//      second window. Bad UX. We use a Win32 named mutex via a tiny FFI
//      call; if the mutex already exists, we exit. The first instance
//      stays the canonical one. Tray subsystem can later listen for a
//      "show window" message from second-instance attempts; for now, the
//      second instance simply quits.
//
//   2. System tray (tray_manager + window_manager) — Close button hides
//      the window instead of quitting. Tray menu offers Show / Hide /
//      Quit. Right-click on tray icon shows the menu. Click on tray icon
//      restores the window.
//
//   3. Crash log to %LOCALAPPDATA%\GoDesk\logs\godesk-YYYY-MM-DD.log —
//      uncaught Dart errors are funnelled here. Production essential.
//
// All three are wired in `main()` before `runApp()`.

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter/material.dart' show Size, Color;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

const _bundleId = 'com.godesk.client';
const _mutexName = 'Global\\GoDesk_SingleInstance_$_bundleId';

// ─── single-instance ────────────────────────────────────────────────────

/// Returns true if this is the first running instance. False = another copy
/// already holds the mutex; caller should `exit(0)`.
bool _acquireSingleInstance() {
  if (!Platform.isWindows) return true;
  // CreateMutexW(NULL, FALSE, name)
  final kernel32 = ffi.DynamicLibrary.open('kernel32.dll');
  final createMutex = kernel32.lookupFunction<
      ffi.IntPtr Function(ffi.Pointer<ffi.Void>, ffi.Int32, ffi.Pointer<Utf16>),
      int Function(ffi.Pointer<ffi.Void>, int, ffi.Pointer<Utf16>)>('CreateMutexW');
  final getLastError = kernel32
      .lookupFunction<ffi.Uint32 Function(), int Function()>('GetLastError');

  final namePtr = _mutexName.toNativeUtf16();
  try {
    final handle = createMutex(ffi.nullptr, 0, namePtr);
    if (handle == 0) return true; // failed to create — proceed permissively
    const errorAlreadyExists = 183;
    return getLastError() != errorAlreadyExists;
  } finally {
    calloc.free(namePtr);
  }
}

/// Exits this process if another instance already holds the mutex.
/// Call BEFORE `runApp` from `main()`.
void enforceSingleInstance() {
  if (!_acquireSingleInstance()) {
    // ignore: avoid_print
    print('[GoDesk] Another instance is already running — exiting.');
    exit(0);
  }
}

// ─── crash log ──────────────────────────────────────────────────────────

class _CrashLog {
  IOSink? _sink;
  String? _path;

  Future<void> open() async {
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}\\logs');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      _path = '${dir.path}\\godesk-$today.log';
      _sink = File(_path!).openWrite(mode: FileMode.append);
      _sink!.writeln('[${DateTime.now().toIso8601String()}] === GoDesk session start ===');
      await _sink!.flush();
    } catch (e) {
      // If logging itself fails, don't crash startup.
      // ignore: avoid_print
      print('[GoDesk] crash-log open failed: $e');
    }
  }

  void writeError(Object error, StackTrace? stack) {
    try {
      _sink?.writeln('[${DateTime.now().toIso8601String()}] ERROR: $error');
      if (stack != null) _sink?.writeln(stack.toString());
      // ignore: unawaited_futures
      _sink?.flush();
    } catch (_) {}
  }

  Future<void> close() async {
    try {
      _sink?.writeln('[${DateTime.now().toIso8601String()}] === session end ===');
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}
  }

  String? get path => _path;
}

final _CrashLog _crashLog = _CrashLog();

/// Initialise crash logging. Call once from `main()` before `runApp()`.
Future<void> initCrashLog() async {
  await _crashLog.open();
  FlutterError.onError = (FlutterErrorDetails details) {
    _crashLog.writeError(details.exception, details.stack);
    FlutterError.presentError(details);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    _crashLog.writeError(error, stack);
    return false; // don't suppress
  };
}

String? get crashLogPath => _crashLog.path;

// ─── tray + window ──────────────────────────────────────────────────────

class TrayController with TrayListener, WindowListener {
  Future<void> init() async {
    await windowManager.ensureInitialized();
    // Frameless: hide the OS title bar so our SkeuoChrome IS the chrome.
    // Eliminates the "app inside an app" visual stacking.
    const opts = WindowOptions(
      size: Size(940, 660), // matches design 920×620 + small padding for shadow
      minimumSize: Size(900, 600),
      center: true,
      title: 'GoDesk',
      backgroundColor: Color(0x00000000),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    windowManager.addListener(this);
    // Intercept Close button → hide instead of quit.
    await windowManager.setPreventClose(true);

    await trayManager.setIcon('assets/icons/tray.ico');
    await trayManager.setToolTip('GoDesk — encrypted remote desktop');
    await trayManager.setContextMenu(Menu(items: <MenuItem>[
      MenuItem(key: 'show', label: 'Show GoDesk'),
      MenuItem(key: 'hide', label: 'Hide to tray'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit GoDesk'),
    ]));
    trayManager.addListener(this);
  }

  @override
  void onWindowClose() async {
    // Hide instead of quit.
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() async {
    if (await windowManager.isVisible()) {
      await windowManager.focus();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  void onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'hide':
        await windowManager.hide();
        break;
      case 'quit':
        await _crashLog.close();
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
        break;
    }
  }
}

final TrayController tray = TrayController();
