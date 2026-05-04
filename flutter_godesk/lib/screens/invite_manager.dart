// InviteManagerDialog — RuDesktop-parity invite-link manager.
// Shows the persisted list of generated links, lets user create new ones
// with a chosen mode + expiration, copy or revoke existing.
//
// Triggered from Home → INVITE button (replaces the old single-shot copy).

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bridge/bridge.dart';
import '../data/invite_link.dart';
import '../kit/lcd_panel.dart';
import '../kit/section_label.dart';
import '../kit/tactile_button.dart';
import '../theme/godesk_theme.dart';
import '../theme/typography.dart';

class InviteManagerDialog extends StatefulWidget {
  const InviteManagerDialog({
    super.key,
    required this.bridge,
    required this.id,
    required this.otp,
  });

  final Bridge bridge;
  final String id;
  final String otp;

  @override
  State<InviteManagerDialog> createState() => _InviteManagerDialogState();
}

class _InviteManagerDialogState extends State<InviteManagerDialog> {
  List<InviteLink> _links = const <InviteLink>[];
  InviteMode _newMode = InviteMode.fullControl;
  Duration? _newExpiry; // null = never

  static const _expiryOptions = <(String, Duration?)>[
    ('1 hour', Duration(hours: 1)),
    ('24 hours', Duration(hours: 24)),
    ('7 days', Duration(days: 7)),
    ('Never', null),
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await widget.bridge.listInviteLinks();
    if (!mounted) return;
    setState(() => _links = list);
  }

  Future<void> _generate() async {
    final url = widget.bridge.inviteLink(id: widget.id, otp: widget.otp);
    final id = '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0xFFFF).toRadixString(16)}';
    final link = InviteLink(
      id: id,
      url: url,
      mode: _newMode,
      createdAt: DateTime.now(),
      expiresAt: _newExpiry == null ? null : DateTime.now().add(_newExpiry!),
    );
    await widget.bridge.addInviteLink(link);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        duration: Duration(milliseconds: 1600),
        content: Text('Invite link generated and copied to clipboard.'),
      ),
    );
    await _reload();
  }

  Future<void> _remove(String id) async {
    await widget.bridge.removeInviteLink(id);
    await _reload();
  }

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return 'today ${two(t.hour)}:${two(t.minute)}';
    }
    return '${t.year}-${two(t.month)}-${two(t.day)}';
  }

  String _formatExpiry(DateTime? expires) {
    if (expires == null) return 'never';
    final left = expires.difference(DateTime.now());
    if (left.isNegative) return 'expired';
    if (left.inDays > 1) return '${left.inDays}d';
    if (left.inHours > 1) return '${left.inHours}h';
    if (left.inMinutes > 1) return '${left.inMinutes}m';
    return 'soon';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return AlertDialog(
      backgroundColor: t.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: t.border),
      ),
      title: Text(
        'Invite Links',
        style: GDtype.ui(size: 14, weight: FontWeight.w700, color: t.heading),
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SectionLabel('Create new'),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _modeDropdown(t),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _expiryDropdown(t),
                ),
                const SizedBox(width: 8),
                TactileButton(
                  variant: TactileVariant.primary,
                  onPressed: _generate,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.add, size: 12),
                      SizedBox(width: 4),
                      Text('CREATE'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SectionLabel('Existing'),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: _links.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'No invite links yet.',
                        textAlign: TextAlign.center,
                        style: GDtype.ui(size: 11, color: t.subtle),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: <Widget>[
                          for (final l in _links) _LinkRow(
                            link: l,
                            theme: t,
                            createdLabel: _formatTime(l.createdAt),
                            expiresLabel: _formatExpiry(l.expiresAt),
                            onCopy: () async {
                              await Clipboard.setData(ClipboardData(text: l.url));
                              if (!mounted) return;
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                const SnackBar(
                                  duration: Duration(milliseconds: 1200),
                                  content: Text('Link copied.'),
                                ),
                              );
                            },
                            onRemove: () => _remove(l.id),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TactileButton(
          small: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CLOSE'),
        ),
      ],
    );
  }

  Widget _modeDropdown(GoDeskTheme t) {
    return LCDPanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SizedBox(
        height: 28,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<InviteMode>(
            value: _newMode,
            isExpanded: true,
            isDense: true,
            dropdownColor: t.panel,
            style: lcdReadout(theme: t, size: 11),
            iconEnabledColor: t.lcdInk,
            items: <DropdownMenuItem<InviteMode>>[
              for (final m in InviteMode.values)
                DropdownMenuItem<InviteMode>(
                  value: m,
                  child: Text(m.label, style: lcdReadout(theme: t, size: 11)),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _newMode = v);
            },
          ),
        ),
      ),
    );
  }

  Widget _expiryDropdown(GoDeskTheme t) {
    return LCDPanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SizedBox(
        height: 28,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<Duration?>(
            value: _newExpiry,
            isExpanded: true,
            isDense: true,
            dropdownColor: t.panel,
            style: lcdReadout(theme: t, size: 11),
            iconEnabledColor: t.lcdInk,
            items: <DropdownMenuItem<Duration?>>[
              for (final (label, dur) in _expiryOptions)
                DropdownMenuItem<Duration?>(
                  value: dur,
                  child: Text(label, style: lcdReadout(theme: t, size: 11)),
                ),
            ],
            onChanged: (v) => setState(() => _newExpiry = v),
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.link,
    required this.theme,
    required this.createdLabel,
    required this.expiresLabel,
    required this.onCopy,
    required this.onRemove,
  });

  final InviteLink link;
  final GoDeskTheme theme;
  final String createdLabel;
  final String expiresLabel;
  final VoidCallback onCopy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final expired = link.isExpired;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: <Widget>[
          // Mode chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: t.panelHi,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: t.border),
            ),
            child: Text(
              link.mode.label,
              style: GDtype.mono(size: 9, weight: FontWeight.w700, color: t.subtle),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  link.url,
                  overflow: TextOverflow.ellipsis,
                  style: GDtype.mono(size: 10, color: expired ? t.subtle : t.heading),
                ),
                Text(
                  'created $createdLabel · expires $expiresLabel · used ${link.usageCount}×',
                  style: GDtype.mono(size: 9, color: t.subtle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TactileButton(
            small: true,
            onPressed: onCopy,
            child: const Icon(Icons.content_copy, size: 11),
          ),
          const SizedBox(width: 4),
          TactileButton(
            small: true,
            variant: TactileVariant.danger,
            onPressed: onRemove,
            child: const Icon(Icons.delete_outline, size: 11),
          ),
        ],
      ),
    );
  }
}
