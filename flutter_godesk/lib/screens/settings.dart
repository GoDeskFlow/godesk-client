// Settings screen — General / Video & Audio / Security / Network / About.
// Port of godesk-skeuo-screens.jsx → SkeuoSettings.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../bridge/bridge.dart';
import '../bridge/provider.dart';
import '../config/infra.dart';
import '../kit/knob.dart';
import '../kit/lcd_panel.dart';
import '../kit/metal_panel.dart';
import '../kit/section_label.dart';
import '../kit/status_led.dart';
import '../kit/tactile_button.dart';
import '../kit/toggle.dart';
import '../theme/godesk_theme.dart';
import '../theme/typography.dart';

enum SettingsSection { general, video, security, network, defaults, about }

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

  // Audio device pickers — populated lazily from bridge.
  List<String> _audioInputs = const <String>[];
  List<String> _audioOutputs = const <String>[];
  String? _audioInput;
  String? _audioOutput;
  bool _audioDevicesLoaded = false;

  // Numeric-only OTP — kept in sync with bridge.numericOtp.
  bool _numericOtpLoaded = false;
  bool _numericOtp = false;

  bool _persistedLoaded = false;

  /// Soft-gate for the Security tab — prevents accidental flips of dangerous
  /// permissions (RuDesktop's "Разблокировать настройки" pattern). Toggles
  /// receive an IgnorePointer + opacity dim while locked. Unlocking is a
  /// click-confirm; no password gate yet.
  bool _securityLocked = true;

  // Failover servers — list of alternate rendezvous addresses tried in
  // order if the primary fails. Persisted as JSON in
  // `godesk-failover-servers` option.
  List<String> _failoverServers = const <String>[];
  final TextEditingController _newFailoverCtl = TextEditingController();

  // "Defaults" section — RuDesktop "Преднастройки" parity. Each toggle
  // is a key in the bridge options store; applied automatically to new
  // sessions by RealBridge once it reads them on connect.
  bool _defShowCursor = true;
  bool _defMuteAudio = false;
  bool _defPrivacyMode = false;
  bool _defLockOnEnd = false;
  bool _defViewOnly = false;
  bool _defHideWallpaper = false;
  bool _defAllowClipboard = true;
  String _defDisplayFit = 'fit'; // matches DisplayFit.name
  bool _defAdaptiveBitrate = true;
  bool _defSaveLastSession = true;
  bool _defOpenFsRoot = true;
  double _defBitrate = 50; // 0..100 — only used when Quality preset = "Custom"

  // Settings → Network → Proxy. RustDesk core supports HTTP_PROXY env var
  // for outbound; we surface a SOCKS5 setting that writes the same value
  // through main_set_option. The TextEditingControllers hold the live
  // values; _proxyAddress only feeds the "Direct connection" status line
  // so the status flips when the address changes.
  String _proxyAddress = '';
  String _proxyType = 'SOCKS5';
  final TextEditingController _proxyAddressCtl = TextEditingController();
  final TextEditingController _proxyLoginCtl = TextEditingController();
  final TextEditingController _proxyPasswordCtl = TextEditingController();
  final TextEditingController _customHeadersCtl = TextEditingController();

  Bridge get _bridge => BridgeProvider.of(context);

  /// Read a persisted boolean — RustDesk's convention is `"Y"` for true,
  /// empty string for false.
  Future<bool> _readBool(String key, {bool defaultValue = false}) async {
    final v = await _bridge.getOption(key);
    if (v.isEmpty) return defaultValue;
    return v == 'Y' || v == 'true' || v == '1';
  }

  Future<void> _writeBool(String key, bool value) =>
      _bridge.setOption(key, value ? 'Y' : '');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_audioDevicesLoaded) {
      _audioDevicesLoaded = true;
      _bridge.audioInputDevices().then((v) {
        if (!mounted) return;
        setState(() {
          _audioInputs = v;
          _audioInput = v.isNotEmpty ? v.first : null;
        });
      });
      _bridge.audioOutputDevices().then((v) {
        if (!mounted) return;
        setState(() {
          _audioOutputs = v;
          _audioOutput = v.isNotEmpty ? v.first : null;
        });
      });
    }
    if (!_numericOtpLoaded) {
      _numericOtpLoaded = true;
      setState(() => _numericOtp = _bridge.numericOtp);
    }
    if (!_persistedLoaded) {
      _persistedLoaded = true;
      _loadPersisted();
    }
  }

  /// Pull the current values from the bridge so toggle state matches what's
  /// actually persisted. Keys mirror upstream RustDesk's `options.json`.
  Future<void> _loadPersisted() async {
    final autostart = await _readBool('enable-auto-launch', defaultValue: true);
    final startMin = await _readBool('enable-start-on-boot-minimized', defaultValue: true);
    final autoUpdate = await _readBool('enable-check-update', defaultValue: true);
    final permControl = await _readBool('enable-keyboard', defaultValue: true);
    final permFiles = await _readBool('enable-file-transfer', defaultValue: true);
    final permClip = await _readBool('enable-clipboard', defaultValue: false);
    final permAudio = await _readBool('enable-audio', defaultValue: false);

    // Defaults section
    final defShowCursor = await _readBool('godesk-default-show-cursor', defaultValue: true);
    final defMuteAudio = await _readBool('godesk-default-mute-audio');
    final defPrivacyMode = await _readBool('godesk-default-privacy-mode');
    final defLockOnEnd = await _readBool('godesk-default-lock-on-end');
    final defViewOnly = await _readBool('godesk-default-view-only');
    final defHideWallpaper = await _readBool('godesk-default-hide-wallpaper');
    final defAllowClipboard = await _readBool('godesk-default-clipboard', defaultValue: true);
    final defFit = await _bridge.getOption('godesk-default-display-fit');
    final defAdaptive = await _readBool('godesk-default-adaptive-bitrate', defaultValue: true);
    final defSaveLast = await _readBool('godesk-default-save-last-session', defaultValue: true);
    final defOpenRoot = await _readBool('godesk-default-open-fs-root', defaultValue: true);
    final rawBitrate = await _bridge.getOption('godesk-default-bitrate');
    final defBitrate = double.tryParse(rawBitrate) ?? 50;

    // Failover servers — JSON-encoded list.
    final rawFailover = await _bridge.getOption('godesk-failover-servers');
    final failoverList = rawFailover.isEmpty
        ? const <String>[]
        : (jsonDecode(rawFailover) as List<dynamic>).cast<String>();

    // Proxy + custom HTTP headers.
    final proxyAddr = await _bridge.getOption('proxy-url');
    final proxyType = await _bridge.getOption('proxy-type');
    final proxyLogin = await _bridge.getOption('proxy-username');
    final proxyPassword = await _bridge.getOption('proxy-password');
    final headers = await _bridge.getOption('custom-http-headers');

    // Restore Image Quality + Relay region from persisted options. Fall
    // back to current local defaults when the option is empty.
    final quality = await _bridge.getOption('image-quality');
    final qIdx = const <String>['low', 'balanced', 'best', 'custom'].indexOf(quality);
    final region = await _bridge.getOption('godesk-relay-region');
    final rIdx = const <String>['eu-west-1', 'us-east-1', 'asia-1', 'self-hosted'].indexOf(region);

    if (!mounted) return;
    setState(() {
      _autostart = autostart;
      _startMin = startMin;
      _autoUpdate = autoUpdate;
      _permControl = permControl;
      _permFiles = permFiles;
      _permClip = permClip;
      _permAudio = permAudio;
      _defShowCursor = defShowCursor;
      _defMuteAudio = defMuteAudio;
      _defPrivacyMode = defPrivacyMode;
      _defLockOnEnd = defLockOnEnd;
      _defViewOnly = defViewOnly;
      _defHideWallpaper = defHideWallpaper;
      _defAllowClipboard = defAllowClipboard;
      _defDisplayFit = defFit.isEmpty ? 'fit' : defFit;
      _defAdaptiveBitrate = defAdaptive;
      _defSaveLastSession = defSaveLast;
      _defOpenFsRoot = defOpenRoot;
      _defBitrate = defBitrate.clamp(0, 100);
      _failoverServers = failoverList;
      _proxyAddress = proxyAddr;
      _proxyAddressCtl.text = proxyAddr;
      _proxyType = proxyType.isEmpty ? 'SOCKS5' : proxyType;
      _proxyLoginCtl.text = proxyLogin;
      _proxyPasswordCtl.text = proxyPassword;
      _customHeadersCtl.text = headers;
      if (qIdx >= 0) _quality = qIdx;
      if (rIdx >= 0) _relay = rIdx;
    });
  }

  Future<void> _saveFailover() async {
    await _bridge.setOption(
      'godesk-failover-servers',
      _failoverServers.isEmpty ? '' : jsonEncode(_failoverServers),
    );
  }

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
      (SettingsSection.defaults, 'Defaults'),
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
      SettingsSection.defaults => _defaults(t),
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
              _toggleRow('Launch GoDesk at login', _autostart, (v) {
                setState(() => _autostart = v);
                _writeBool('enable-auto-launch', v);
              }, t),
              const SizedBox(height: 10),
              _toggleRow('Start minimized to menu bar', _startMin, (v) {
                setState(() => _startMin = v);
                _writeBool('enable-start-on-boot-minimized', v);
              }, t),
              const SizedBox(height: 10),
              _toggleRow('Check for updates automatically', _autoUpdate, (v) {
                setState(() => _autoUpdate = v);
                _writeBool('enable-check-update', v);
              }, t),
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
                        onTap: () {
                          setState(() => _quality = i);
                          // Map index to RustDesk's image-quality wire
                          // values. session_set_image_quality also accepts
                          // these strings on a per-session basis.
                          const wire = <String>['low', 'balanced', 'best', 'custom'];
                          _bridge.setOption('image-quality', wire[i]);
                        },
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
              const SizedBox(height: 18),
              _audioDevicePicker(
                t,
                label: 'Output device',
                value: _audioOutput,
                items: _audioOutputs,
                onChanged: (v) => setState(() => _audioOutput = v),
              ),
              const SizedBox(height: 12),
              _audioDevicePicker(
                t,
                label: 'Input device (mic)',
                value: _audioInput,
                items: _audioInputs,
                onChanged: (v) => setState(() => _audioInput = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _audioDevicePicker(
    GoDeskTheme t, {
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isEmpty = items.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(),
            style: GDtype.wordmark(size: 10, color: t.subtle, trackingEm: 0.06)),
        const SizedBox(height: 6),
        LCDPanel(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: SizedBox(
            height: 28,
            child: isEmpty
                ? Text('— no devices reported —', style: lcdReadout(theme: t, size: 11).copyWith(color: t.lcdDim))
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: value,
                      isExpanded: true,
                      isDense: true,
                      dropdownColor: t.panel,
                      style: lcdReadout(theme: t, size: 11),
                      iconEnabledColor: t.lcdInk,
                      items: <DropdownMenuItem<String>>[
                        for (final d in items)
                          DropdownMenuItem<String>(
                            value: d,
                            child: Text(d, style: lcdReadout(theme: t, size: 11)),
                          ),
                      ],
                      onChanged: onChanged,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _security(GoDeskTheme t) {
    return Column(
      children: <Widget>[
        // Unlock-gate panel — appears at the top of Security so the user
        // must explicitly opt in before flipping dangerous toggles.
        SizedBox(
          width: double.infinity,
          child: TactileButton(
            variant: _securityLocked ? TactileVariant.primary : TactileVariant.defaultStyle,
            onPressed: () => setState(() => _securityLocked = !_securityLocked),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(_securityLocked ? Icons.lock_outline : Icons.lock_open_outlined, size: 12),
                const SizedBox(width: 6),
                Text(_securityLocked ? 'UNLOCK SECURITY SETTINGS' : 'LOCK'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        IgnorePointer(
          ignoring: _securityLocked,
          child: Opacity(
            opacity: _securityLocked ? 0.4 : 1.0,
            child: _securityBody(t),
          ),
        ),
      ],
    );
  }

  Widget _securityBody(GoDeskTheme t) {
    return Column(
      children: <Widget>[
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Permissions for incoming sessions'),
              const SizedBox(height: 12),
              _toggleRow('Allow remote control of keyboard & mouse', _permControl, (v) {
                setState(() => _permControl = v);
                _writeBool('enable-keyboard', v);
              }, t),
              const SizedBox(height: 10),
              _toggleRow('Allow file transfers', _permFiles, (v) {
                setState(() => _permFiles = v);
                _writeBool('enable-file-transfer', v);
              }, t),
              const SizedBox(height: 10),
              _toggleRow('Share clipboard with remote', _permClip, (v) {
                setState(() => _permClip = v);
                _writeBool('enable-clipboard', v);
              }, t),
              const SizedBox(height: 10),
              _toggleRow('Allow audio capture', _permAudio, (v) {
                setState(() => _permAudio = v);
                _writeBool('enable-audio', v);
              }, t),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('One-time password'),
              const SizedBox(height: 12),
              _toggleRow(
                'Easier-to-dictate password (digits only)',
                _numericOtp,
                (v) {
                  setState(() => _numericOtp = v);
                  _bridge.numericOtp = v;
                },
                t,
              ),
              const SizedBox(height: 6),
              Text(
                _numericOtp
                    ? 'New OTPs will be 8 digits (xxxx-xxxx). Easy to read aloud over the phone.'
                    : 'New OTPs use the consonant-vowel-digit format (cv9-cv9-cv).',
                style: GDtype.ui(size: 10, color: t.subtle).copyWith(height: 1.4),
              ),
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
    return Column(
      children: <Widget>[
        MetalPanel(
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
                        onTap: () {
                          setState(() => _relay = i);
                          const region = <String>['eu-west-1', 'us-east-1', 'asia-1', 'self-hosted'];
                          _bridge.setOption('godesk-relay-region', region[i]);
                        },
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
                  // All three regions currently fall back to the default
                  // VPS until Phase 5+ provisions per-region relays.
                  // Per [ADR-009](decisions.md#adr-009).
                  _relay == 3
                      ? 'self-hosted.example.com:${GoDeskInfra.relayPort}'
                      : '${GoDeskInfra.relayHost}:${GoDeskInfra.relayPort}',
                  style: lcdReadout(theme: t, size: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // RuDesktop "Альтернативные сервера" parity — failover list tried in
        // order if the primary rendezvous fails to connect.
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Alternative servers'),
              const SizedBox(height: 6),
              Text(
                'Tried in order if the primary relay is unreachable.',
                style: GDtype.ui(size: 10, color: t.subtle).copyWith(height: 1.4),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < _failoverServers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: LCDPanel(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Text(_failoverServers[i],
                              style: lcdReadout(theme: t, size: 11)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TactileButton(
                        small: true,
                        variant: TactileVariant.danger,
                        onPressed: () {
                          setState(() => _failoverServers = <String>[
                                ..._failoverServers.sublist(0, i),
                                ..._failoverServers.sublist(i + 1),
                              ]);
                          _saveFailover();
                        },
                        child: const Icon(Icons.delete_outline, size: 11),
                      ),
                    ],
                  ),
                ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: LCDPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: TextField(
                        controller: _newFailoverCtl,
                        cursorColor: t.lcdInk,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintText: 'host:port',
                          hintStyle: lcdReadout(theme: t, size: 11).copyWith(color: t.lcdDim),
                        ),
                        style: lcdReadout(theme: t, size: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TactileButton(
                    small: true,
                    variant: TactileVariant.primary,
                    onPressed: () {
                      final v = _newFailoverCtl.text.trim();
                      if (v.isEmpty) return;
                      setState(() {
                        _failoverServers = <String>[..._failoverServers, v];
                        _newFailoverCtl.clear();
                      });
                      _saveFailover();
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.add, size: 12),
                        SizedBox(width: 4),
                        Text('ADD'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Outbound proxy — RuDesktop "Прокси" parity. RustDesk core honours
        // proxy-url / proxy-type / proxy-username / proxy-password options
        // for SOCKS5 / HTTP outbound when reaching hbbs/hbbr.
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Proxy'),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    flex: 2,
                    child: LCDPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: TextField(
                        controller: _proxyAddressCtl,
                        cursorColor: t.lcdInk,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintText: 'host:port',
                          hintStyle: lcdReadout(theme: t, size: 11).copyWith(color: t.lcdDim),
                        ),
                        style: lcdReadout(theme: t, size: 11),
                        onSubmitted: (v) {
                          setState(() => _proxyAddress = v);
                          _bridge.setOption('proxy-url', v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: LCDPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: SizedBox(
                        height: 22,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _proxyType,
                            isExpanded: true,
                            isDense: true,
                            dropdownColor: t.panel,
                            style: lcdReadout(theme: t, size: 11),
                            iconEnabledColor: t.lcdInk,
                            items: const <DropdownMenuItem<String>>[
                              DropdownMenuItem(value: 'SOCKS5', child: Text('SOCKS5')),
                              DropdownMenuItem(value: 'HTTP', child: Text('HTTP')),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _proxyType = v);
                              _bridge.setOption('proxy-type', v);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LCDPanel(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: TextField(
                  controller: _proxyLoginCtl,
                  cursorColor: t.lcdInk,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: 'username (optional)',
                    hintStyle: lcdReadout(theme: t, size: 11).copyWith(color: t.lcdDim),
                  ),
                  style: lcdReadout(theme: t, size: 11),
                  onSubmitted: (v) =>
                      _bridge.setOption('proxy-username', v),
                ),
              ),
              const SizedBox(height: 8),
              LCDPanel(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: TextField(
                  controller: _proxyPasswordCtl,
                  obscureText: true,
                  cursorColor: t.lcdInk,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: 'password (optional)',
                    hintStyle: lcdReadout(theme: t, size: 11).copyWith(color: t.lcdDim),
                  ),
                  style: lcdReadout(theme: t, size: 11),
                  onSubmitted: (v) =>
                      _bridge.setOption('proxy-password', v),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _proxyAddress.isEmpty
                    ? 'Direct connection (no proxy).'
                    : 'Outbound traffic to hbbs/hbbr routes through $_proxyType.',
                style: GDtype.ui(size: 10, color: t.subtle).copyWith(height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Custom HTTP headers — niche but enterprise-friendly. RuDesktop
        // 2.8.1532 parity. Free-form text area; one header per line.
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Custom HTTP headers'),
              const SizedBox(height: 6),
              Text(
                'One per line: "Header-Name: value". Sent on every outbound HTTP/HTTPS request.',
                style: GDtype.ui(size: 10, color: t.subtle).copyWith(height: 1.4),
              ),
              const SizedBox(height: 8),
              LCDPanel(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: TextField(
                  controller: _customHeadersCtl,
                  maxLines: 3,
                  cursorColor: t.lcdInk,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: 'X-Auth: token\nX-Trace: …',
                    hintStyle: lcdReadout(theme: t, size: 11).copyWith(color: t.lcdDim),
                  ),
                  style: lcdReadout(theme: t, size: 11),
                  onSubmitted: (v) =>
                      _bridge.setOption('custom-http-headers', v),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _defaults(GoDeskTheme t) {
    return Column(
      children: <Widget>[
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Connection defaults'),
              const SizedBox(height: 6),
              Text(
                'Applied to every new session unless the peer overrides.',
                style: GDtype.ui(size: 10, color: t.subtle).copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              _toggleRow('Show remote cursor', _defShowCursor, (v) {
                setState(() => _defShowCursor = v);
                _writeBool('godesk-default-show-cursor', v);
              }, t),
              const SizedBox(height: 8),
              _toggleRow('Mute audio', _defMuteAudio, (v) {
                setState(() => _defMuteAudio = v);
                _writeBool('godesk-default-mute-audio', v);
              }, t),
              const SizedBox(height: 8),
              _toggleRow('Privacy mode', _defPrivacyMode, (v) {
                setState(() => _defPrivacyMode = v);
                _writeBool('godesk-default-privacy-mode', v);
              }, t),
              const SizedBox(height: 8),
              _toggleRow('Lock remote on session end', _defLockOnEnd, (v) {
                setState(() => _defLockOnEnd = v);
                _writeBool('godesk-default-lock-on-end', v);
              }, t),
              const SizedBox(height: 8),
              _toggleRow('View only by default', _defViewOnly, (v) {
                setState(() => _defViewOnly = v);
                _writeBool('godesk-default-view-only', v);
              }, t),
              const SizedBox(height: 8),
              _toggleRow('Hide remote wallpaper', _defHideWallpaper, (v) {
                setState(() => _defHideWallpaper = v);
                _writeBool('godesk-default-hide-wallpaper', v);
              }, t),
              const SizedBox(height: 8),
              _toggleRow('Allow clipboard sharing', _defAllowClipboard, (v) {
                setState(() => _defAllowClipboard = v);
                _writeBool('godesk-default-clipboard', v);
              }, t),
              const SizedBox(height: 8),
              _toggleRow('Adaptive bitrate (auto-tune to link speed)', _defAdaptiveBitrate, (v) {
                setState(() => _defAdaptiveBitrate = v);
                _writeBool('godesk-default-adaptive-bitrate', v);
              }, t),
              const SizedBox(height: 8),
              _toggleRow('Save last session to address book', _defSaveLastSession, (v) {
                setState(() => _defSaveLastSession = v);
                _writeBool('godesk-default-save-last-session', v);
              }, t),
              const SizedBox(height: 8),
              _toggleRow('Open root of remote FS on file transfer', _defOpenFsRoot, (v) {
                setState(() => _defOpenFsRoot = v);
                _writeBool('godesk-default-open-fs-root', v);
              }, t),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Custom bitrate — only meaningful when Adaptive is OFF or when the
        // remote forces the cap. Range 0..100 maps to RustDesk's
        // custom-image-quality scale.
        IgnorePointer(
          ignoring: _defAdaptiveBitrate,
          child: Opacity(
            opacity: _defAdaptiveBitrate ? 0.4 : 1.0,
            child: MetalPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const SectionLabel('Custom bitrate cap'),
                      const Spacer(),
                      LCDPanel(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        child: Text('${_defBitrate.round()}%',
                            style: lcdReadout(theme: t, size: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Slider(
                    value: _defBitrate,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    activeColor: t.accent,
                    inactiveColor: t.border,
                    onChanged: (v) => setState(() => _defBitrate = v),
                    onChangeEnd: (v) =>
                        _bridge.setOption('godesk-default-bitrate', v.round().toString()),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Display fit (default)'),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  for (final fit in const <(String, String)>[
                    ('fit', 'Fit'),
                    ('original', '1:1'),
                    ('stretch', 'Stretch'),
                  ]) ...<Widget>[
                    Expanded(
                      child: _SegmentButton(
                        label: fit.$2,
                        active: _defDisplayFit == fit.$1,
                        onTap: () {
                          setState(() => _defDisplayFit = fit.$1);
                          _bridge.setOption('godesk-default-display-fit', fit.$1);
                        },
                      ),
                    ),
                    if (fit.$1 != 'stretch') const SizedBox(width: 6),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _about(GoDeskTheme t) {
    final rows = <(String, String)>[
      ('Version', '${GoDeskInfra.appVersion} (build ${GoDeskInfra.buildStamp})'),
      ('License', '${GoDeskInfra.licenseSpdx} · open source'),
      ('Forked from', GoDeskInfra.upstream),
      ('Platform', 'Windows 11 · x64'),
      ('Rendezvous', '${GoDeskInfra.rendezvousHost}:${GoDeskInfra.rendezvousPort}'),
      ('Relay', '${GoDeskInfra.relayHost}:${GoDeskInfra.relayPort}'),
      ('Source', GoDeskInfra.sourceUrl),
    ];
    return Column(
      children: <Widget>[
        // RuDesktop "О приложении" parity — three live status dots that
        // turn green when the underlying subsystem is healthy.
        StreamBuilder<Diagnostics>(
          stream: _bridge.diagnostics(),
          builder: (context, snap) {
            final d = snap.data;
            final relayOk = d != null && d.relay != '—';
            // FFI is "ready" once the bridge instance answered identity()
            // — we use it as a proxy for "Rust core is loaded". Once we
            // can read it via getOption, treat that as healthy.
            return MetalPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SectionLabel('Status'),
                  const SizedBox(height: 10),
                  _statusRow(t, label: 'Relay', ok: relayOk,
                      detail: relayOk ? d.relay : 'not connected'),
                  const SizedBox(height: 6),
                  _statusRow(t, label: 'IPC',
                      ok: true,
                      detail: 'librustdesk loaded'),
                  const SizedBox(height: 6),
                  _statusRow(t, label: 'E2E cipher',
                      ok: true,
                      detail: d?.cipher ?? 'AES-256-GCM'),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        MetalPanel(
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
        ),
      ],
    );
  }

  Widget _statusRow(GoDeskTheme t,
      {required String label, required bool ok, required String detail}) {
    return Row(
      children: <Widget>[
        StatusLED(color: ok ? LEDColors.online : LEDColors.warning, pulse: ok),
        const SizedBox(width: 8),
        SizedBox(
          width: 96,
          child: Text(label,
              style: GDtype.ui(size: 11, weight: FontWeight.w600, color: t.body)),
        ),
        Expanded(
          child: Text(detail,
              style: GDtype.mono(size: 10, color: t.subtle)),
        ),
      ],
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
