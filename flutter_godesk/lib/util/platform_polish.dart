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
// Per-user namespace — `Global\` requires SE_CREATE_GLOBAL_NAME which
// non-elevated processes don't have. Without elevation CreateMutexW(Global\)
// fails entirely and our single-instance check became a permissive no-op,
// allowing zombie processes to accumulate. Per-user is the correct scope
// for a desktop app anyway.
const _mutexName = 'GoDesk_SingleInstance_$_bundleId';
const _windowTitle = 'GoDesk';

// ─── single-instance ────────────────────────────────────────────────────

bool _isFirstInstance = true;

/// Returns true if this is the first running instance. False = another copy
/// already holds the mutex; caller should ping the existing window and exit.
bool _acquireSingleInstance() {
  if (!Platform.isWindows) return true;
  final kernel32 = ffi.DynamicLibrary.open('kernel32.dll');
  final createMutex = kernel32.lookupFunction<
      ffi.IntPtr Function(ffi.Pointer<ffi.Void>, ffi.Int32, ffi.Pointer<Utf16>),
      int Function(ffi.Pointer<ffi.Void>, int, ffi.Pointer<Utf16>)>('CreateMutexW');
  final getLastError = kernel32
      .lookupFunction<ffi.Uint32 Function(), int Function()>('GetLastError');

  final namePtr = _mutexName.toNativeUtf16();
  try {
    final handle = createMutex(ffi.nullptr, 0, namePtr);
    const errorAlreadyExists = 183;
    final lastError = getLastError();
    if (handle == 0) {
      // CreateMutexW genuinely failed (very rare). Proceed permissively
      // rather than blocking the user from launching at all.
      // ignore: avoid_print
      print('[GoDesk] CreateMutexW failed (err=$lastError) — proceeding.');
      return true;
    }
    return lastError != errorAlreadyExists;
  } finally {
    calloc.free(namePtr);
  }
}

/// If another instance is already running, bring its window forward (so the
/// user sees something happen) and exit this process. Otherwise return; the
/// caller proceeds with normal startup.
///
/// Call BEFORE `runApp` from `main()`.
void enforceSingleInstance() {
  if (_acquireSingleInstance()) return;
  _isFirstInstance = false;
  _wakeExistingInstance();
  // ignore: avoid_print
  print('[GoDesk] Another instance is already running — focusing it and exiting.');
  exit(0);
}

bool get isFirstInstance => _isFirstInstance;

/// Find the running GoDesk window and bring it to the foreground. Used when
/// a second launch attempt is detected — gives the user immediate feedback
/// that "the app is already open" instead of a silent no-op.
void _wakeExistingInstance() {
  if (!Platform.isWindows) return;
  try {
    final user32 = ffi.DynamicLibrary.open('user32.dll');

    final findWindow = user32.lookupFunction<
        ffi.IntPtr Function(ffi.Pointer<Utf16>, ffi.Pointer<Utf16>),
        int Function(ffi.Pointer<Utf16>, ffi.Pointer<Utf16>)>('FindWindowW');
    final showWindow = user32.lookupFunction<
        ffi.Int32 Function(ffi.IntPtr, ffi.Int32),
        int Function(int, int)>('ShowWindow');
    final setForeground = user32.lookupFunction<
        ffi.Int32 Function(ffi.IntPtr),
        int Function(int)>('SetForegroundWindow');

    final titlePtr = _windowTitle.toNativeUtf16();
    try {
      // Search by title only (lpClassName = NULL).
      final hwnd = findWindow(ffi.nullptr.cast<Utf16>(), titlePtr);
      if (hwnd == 0) return;
      const swRestore = 9;
      showWindow(hwnd, swRestore);
      setForeground(hwnd);
    } finally {
      calloc.free(titlePtr);
    }
  } catch (_) {
    // Best-effort — failure here just means user has to find the tray icon.
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

    // Platform-specific tray icon. Windows uses .ico for high-DPI tray
    // rendering; macOS/Linux fall back to a PNG. If the platform-specific
    // file is missing, swallow the error so the rest of the app still runs
    // (tray is non-critical UX).
    try {
      final iconPath = Platform.isWindows
          ? 'assets/icons/tray.ico'
          : 'assets/icons/tray.png';
      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip('GoDesk — encrypted remote desktop');
      await trayManager.setContextMenu(Menu(items: <MenuItem>[
        MenuItem(key: 'show', label: 'Show GoDesk'),
        MenuItem(key: 'hide', label: 'Hide to tray'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit GoDesk'),
      ]));
      trayManager.addListener(this);
    } catch (e) {
      // ignore: avoid_print
      print('[GoDesk] tray init skipped: $e');
    }
  }

  @override
  void onWindowClose() async {
    // X (red traffic light) = real quit. Earlier behaviour ("hide to tray")
    // came from `setPreventClose(true)` + `windowManager.hide()` in this
    // handler. That left the process resident in memory after the user
    // thought they closed it, holding a lock on flutter_windows.dll that
    // blocked installer upgrades and confused first-time users who couldn't
    // find the tray icon.
    //
    // Hide-to-tray remains available via:
    //   - yellow traffic light (windowManager.minimize)
    //   - tray menu → "Hide to tray"
    //
    // We deliberately don't `setPreventClose(false)` here — the close has
    // already been delivered to us; calling `destroy()` quits cleanly.
    await _crashLog.close();
    await windowManager.destroy();
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
