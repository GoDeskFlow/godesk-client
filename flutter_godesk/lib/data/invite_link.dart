// InviteLink — local data model for the invite-link manager dialog
// (RuDesktop "Приглашения" tab parity, scaled to home tier).
//
// Phase 4-MVP: in-memory only. Persisting across launches needs a
// server-side tracking endpoint we don't have yet. RuDesktop tracks
// usage counts on their cloud — ours is generate-and-go for now.

import 'dart:convert';

enum InviteMode {
  fullControl('full-control', 'Full control'),
  viewOnly('view-only', 'View only'),
  fileTransfer('file-transfer', 'File transfer');

  const InviteMode(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static InviteMode fromWire(String w) =>
      InviteMode.values.firstWhere((m) => m.wireValue == w,
          orElse: () => InviteMode.fullControl);
}

class InviteLink {
  InviteLink({
    required this.id,
    required this.url,
    required this.mode,
    required this.createdAt,
    this.expiresAt,
    this.usageCount = 0,
  });

  final String id;
  final String url;
  final InviteMode mode;
  final DateTime createdAt;
  final DateTime? expiresAt;
  int usageCount;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'url': url,
        'mode': mode.wireValue,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'usageCount': usageCount,
      };

  factory InviteLink.fromJson(Map<String, dynamic> j) => InviteLink(
        id: j['id'] as String,
        url: j['url'] as String,
        mode: InviteMode.fromWire(j['mode'] as String? ?? 'full-control'),
        createdAt: DateTime.parse(j['createdAt'] as String),
        expiresAt: (j['expiresAt'] as String?) != null
            ? DateTime.parse(j['expiresAt'] as String)
            : null,
        usageCount: (j['usageCount'] as num?)?.toInt() ?? 0,
      );

  static String encodeAll(List<InviteLink> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<InviteLink> decodeAll(String raw) {
    if (raw.isEmpty) return const <InviteLink>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => InviteLink.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const <InviteLink>[];
    }
  }
}
