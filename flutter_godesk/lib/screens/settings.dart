// Settings screen — General / Video & Audio / Security / Network / About.
// Port of godesk-skeuo-screens.jsx → SkeuoSettings.

import 'package:flutter/material.dart';

import '../config/infra.dart';
import '../kit/knob.dart';
import '../kit/lcd_panel.dart';
import '../kit/metal_panel.dart';
import '../kit/section_label.dart';
import '../kit/toggle.dart';
import '../theme/godesk_theme.dart';
import '../theme/typography.dart';

enum SettingsSection { general, video, security, network, about }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsSection _section = SettingsSection.general;
  bool _autostart = true;
  bool _startMin = true;
  bool _autoUpdate = true;
  bool _permControl = true;
  bool _permFiles = true;
  bool _permClip = false;
  bool _permAudio = false;
  int _quality = 2;
  double _vol = 70;
  double _mic = 45;
  int _relay = 0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: t.dark
              ? const <Color>[Color(0xFF1C1D22), Color(0xFF16171B)]
              : const <Color>[Color(0xFFE8E4DC), Color(0xFFD8D3C8)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(width: 200, child: _sidebar(t)),
            const SizedBox(width: 14),
            Expanded(child: SingleChildScrollView(child: _body(t))),
          ],
        ),
      ),
    );
  }

  Widget _sidebar(GoDeskTheme t) {
    final items = <(SettingsSection, String)>[
      (SettingsSection.general, 'General'),
      (SettingsSection.video, 'Video & Audio'),
      (SettingsSection.security, 'Security'),
      (SettingsSection.network, 'Network'),
      (SettingsSection.about, 'About'),
    ];
    return MetalPanel(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final i in items)
            _SidebarButton(
              label: i.$2,
              active: i.$1 == _section,
              onTap: () => setState(() => _section = i.$1),
            ),
        ],
      ),
    );
  }

  Widget _body(GoDeskTheme t) {
    return switch (_section) {
      SettingsSection.general => _general(t),
      SettingsSection.video => _video(t),
      SettingsSection.security => _security(t),
      SettingsSection.network => _network(t),
      SettingsSection.about => _about(t),
    };
  }

  Widget _general(GoDeskTheme t) {
    return Column(
      children: <Widget>[
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Startup'),
              const SizedBox(height: 12),
              _toggleRow('Launch GoDesk at login', _autostart, (v) => setState(() => _autostart = v), t),
              const SizedBox(height: 10),
              _toggleRow('Start minimized to menu bar', _startMin, (v) => setState(() => _startMin = v), t),
              const SizedBox(height: 10),
              _toggleRow('Check for updates automatically', _autoUpdate, (v) => setState(() => _autoUpdate = v), t),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Theme'),
              const SizedBox(height: 12),
              Text(
                'Theme & accent are controlled from the floating Tweaks panel (later: integrated here).',
                style: GDtype.ui(size: 11, color: t.subtle),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _video(GoDeskTheme t) {
    final quals = <String>['Eco', 'Balanced', 'Quality', 'Lossless'];
    return Column(
      children: <Widget>[
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Image Quality'),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  for (var i = 0; i < quals.length; i++) ...<Widget>[
                    Expanded(
                      child: _SegmentButton(
                        label: quals[i],
                        active: _quality == i,
                        onTap: () => setState(() => _quality = i),
                      ),
                    ),
                    if (i < quals.length - 1) const SizedBox(width: 6),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Audio'),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(child: _knobCell(t, 'Volume', _vol, (v) => setState(() => _vol = v))),
                  Expanded(child: _knobCell(t, 'Mic gain', _mic, (v) => setState(() => _mic = v))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _security(GoDeskTheme t) {
    return Column(
      children: <Widget>[
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Permissions for incoming sessions'),
              const SizedBox(height: 12),
              _toggleRow('Allow remote control of keyboard & mouse', _permControl, (v) => setState(() => _permControl = v), t),
              const SizedBox(height: 10),
              _toggleRow('Allow file transfers', _permFiles, (v) => setState(() => _permFiles = v), t),
              const SizedBox(height: 10),
              _toggleRow('Share clipboard with remote', _permClip, (v) => setState(() => _permClip = v), t),
              const SizedBox(height: 10),
              _toggleRow('Allow audio capture', _permAudio, (v) => setState(() => _permAudio = v), t),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Encryption'),
              const SizedBox(height: 8),
              LCDPanel(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text('> CIPHER', style: lcdDimLabel(theme: t)),
                        const Spacer(),
                        Text('AES-256-GCM', style: lcdReadout(theme: t, size: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Text('> EXCHANGE', style: lcdDimLabel(theme: t)),
                        const Spacer(),
                        Text('X25519 + ED25519', style: lcdReadout(theme: t, size: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _network(GoDeskTheme t) {
    final relays = <String>['EU West', 'US East', 'Asia', 'Self-hosted'];
    return MetalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionLabel('Relay Server'),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              for (var i = 0; i < relays.length; i++) ...<Widget>[
                Expanded(
                  child: _SegmentButton(
                    label: relays[i],
                    active: _relay == i,
                    onTap: () => setState(() => _relay = i),
                  ),
                ),
                if (i < relays.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 12),
          LCDPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              _relay == 0
                  // EU West not yet provisioned; falls back to default until Phase 5
                  // adds a true regional relay. Per ADR-009.
                  ? '${GoDeskInfra.relayHost}:${GoDeskInfra.relayPort}'
                  : _relay == 1
                      ? '${GoDeskInfra.relayHost}:${GoDeskInfra.relayPort}'
                      : _relay == 2
                          ? '${GoDeskInfra.relayHost}:${GoDeskInfra.relayPort}'
                          : 'self-hosted.example.com:${GoDeskInfra.relayPort}',
              style: lcdReadout(theme: t, size: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _about(GoDeskTheme t) {
    final rows = <(String, String)>[
      ('Version', '0.1.0 (build 26.05.03)'),
      ('License', '${GoDeskInfra.licenseSpdx} · open source'),
      ('Forked from', GoDeskInfra.upstream),
      ('Platform', 'Windows 11 · x64'),
      ('Rendezvous', '${GoDeskInfra.rendezvousHost}:${GoDeskInfra.rendezvousPort}'),
      ('Relay', '${GoDeskInfra.relayHost}:${GoDeskInfra.relayPort}'),
      ('Source', GoDeskInfra.sourceUrl),
    ];
    return MetalPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionLabel('About'),
          const SizedBox(height: 12),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 110,
                    child: Text(r.$1,
                        style: GDtype.ui(size: 12, weight: FontWeight.w600, color: t.subtle)),
                  ),
                  Expanded(
                    child: Text(r.$2,
                        style: GDtype.mono(size: 12, color: t.heading)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _toggleRow(String label, bool v, ValueChanged<bool> onChanged, GoDeskTheme t) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(label,
              style: GDtype.ui(size: 12, weight: FontWeight.w500, color: t.heading)),
        ),
        GoDeskToggle(value: v, onChanged: onChanged),
      ],
    );
  }

  Widget _knobCell(GoDeskTheme t, String label, double v, ValueChanged<double> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Knob(value: v, onChanged: onChanged),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SectionLabel(label),
            const SizedBox(height: 4),
            LCDPanel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text('${v.round()}%',
                  style: lcdReadout(theme: t, size: 14)),
            ),
          ],
        ),
      ],
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      t.accent.withValues(alpha: 0.2),
                      t.accent.withValues(alpha: 0.1),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: active ? t.accentDark : Colors.transparent,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: GDtype.wordmark(
              size: 11,
              color: active ? t.accentDark : t.body,
              trackingEm: 0.06,
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[t.accent, t.accentDark],
                  )
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[t.panelHi, t.panel],
                  ),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: active ? t.accentDark : t.border),
            boxShadow: active
                ? <BoxShadow>[
                    BoxShadow(
                      color: t.accentGlow.withValues(alpha: 1 / 3),
                      blurRadius: 8,
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          alignment: Alignment.center,
          child: Text(
            label.toUpperCase(),
            style: GDtype.wordmark(
              size: 11,
              color: active ? Colors.white : t.body,
              trackingEm: 0.06,
            ),
          ),
        ),
      ),
    );
  }
}
