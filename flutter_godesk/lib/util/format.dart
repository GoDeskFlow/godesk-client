// Formatting utilities — direct ports of helpers from godesk-shared.jsx.

import 'dart:math' show Random;

/// Strip non-digits, cap at 9, group as "xxx xxx xxx".
String formatId(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  final clipped = d.length > 9 ? d.substring(0, 9) : d;
  if (clipped.length <= 3) return clipped;
  if (clipped.length <= 6) {
    return '${clipped.substring(0, 3)} ${clipped.substring(3)}';
  }
  return '${clipped.substring(0, 3)} ${clipped.substring(3, 6)} ${clipped.substring(6)}';
}

/// Phonetic-friendly password: cv9-cv9-cv (consonant + vowel + digit segments).
String genPassword([Random? rng]) {
  final r = rng ?? Random();
  const consonants = 'bcdfghjkmnpqrstvwxyz';
  const vowels = 'aeiou';
  const digits = '23456789';
  String pick(String s) => s[r.nextInt(s.length)];
  String seg() => '${pick(consonants)}${pick(vowels)}${pick(digits)}';
  return '${seg()}-${seg()}-${pick(consonants)}${pick(vowels)}';
}

/// 8-digit numeric password formatted as `xxxx-xxxx`. Easier to dictate over
/// a phone call than the cv9 form. RuDesktop 2.9.492 parity (Settings →
/// Security → "Easier-to-dictate password").
String genNumericPassword([Random? rng]) {
  final r = rng ?? Random();
  String four() => List<int>.generate(4, (_) => r.nextInt(10)).join();
  return '${four()}-${four()}';
}

/// Bytes → human-readable string.
String formatBytes(num n) {
  if (n < 1024) return '${n.round()} B';
  if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
  if (n < 1024 * 1024 * 1024) {
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(n / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
