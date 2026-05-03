// User-tweakable theme preferences (dark mode, accent, lcd, intensity).
// Persisted via `shared_preferences` so they survive restart.
//
// Equivalent of `useTweaks(TWEAK_DEFAULTS)` from `tweaks-panel.jsx`,
// but production-grade: real persistence, no `EDITMODE-BEGIN` marker syntax.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tokens.dart';

@immutable
class Tweaks {
  const Tweaks({
    required this.darkMode,
    required this.accent,
    required this.lcd,
    required this.intensity,
  });

  final bool darkMode;
  final String accent;
  final String lcd;
  final double intensity;

  static const Tweaks defaults = Tweaks(
    darkMode: TweakDefaults.darkMode,
    accent: TweakDefaults.accent,
    lcd: TweakDefaults.lcd,
    intensity: TweakDefaults.intensity,
  );

  Tweaks copyWith({
    bool? darkMode,
    String? accent,
    String? lcd,
    double? intensity,
  }) =>
      Tweaks(
        darkMode: darkMode ?? this.darkMode,
        accent: accent ?? this.accent,
        lcd: lcd ?? this.lcd,
        intensity: intensity ?? this.intensity,
      );
}

class TweaksController extends ChangeNotifier {
  TweaksController._(this._prefs) : _value = _readFromPrefs(_prefs);

  static Future<TweaksController> create() async {
    final prefs = await SharedPreferences.getInstance();
    return TweaksController._(prefs);
  }

  final SharedPreferences _prefs;
  Tweaks _value;
  Tweaks get value => _value;

  static Tweaks _readFromPrefs(SharedPreferences p) => Tweaks(
        darkMode: p.getBool(_kDarkMode) ?? Tweaks.defaults.darkMode,
        accent: p.getString(_kAccent) ?? Tweaks.defaults.accent,
        lcd: p.getString(_kLcd) ?? Tweaks.defaults.lcd,
        intensity: p.getDouble(_kIntensity) ?? Tweaks.defaults.intensity,
      );

  Future<void> setDarkMode(bool v) async {
    _value = _value.copyWith(darkMode: v);
    await _prefs.setBool(_kDarkMode, v);
    notifyListeners();
  }

  Future<void> setAccent(String v) async {
    if (!accents.containsKey(v)) return;
    _value = _value.copyWith(accent: v);
    await _prefs.setString(_kAccent, v);
    notifyListeners();
  }

  Future<void> setLcd(String v) async {
    if (!lcdPalettes.containsKey(v)) return;
    _value = _value.copyWith(lcd: v);
    await _prefs.setString(_kLcd, v);
    notifyListeners();
  }

  Future<void> setIntensity(double v) async {
    final clamped = v.clamp(0.3, 1.4);
    _value = _value.copyWith(intensity: clamped);
    await _prefs.setDouble(_kIntensity, clamped);
    notifyListeners();
  }
}

const _kDarkMode = 'godesk.theme.darkMode';
const _kAccent = 'godesk.theme.accent';
const _kLcd = 'godesk.theme.lcd';
const _kIntensity = 'godesk.theme.intensity';
