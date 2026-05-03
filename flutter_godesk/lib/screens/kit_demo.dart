// Kit demo — Phase 2.1 visual sanity screen.
// Shows every primitive from `lib/kit/` and `lib/chrome/` in one window so
// it can be diffed side-by-side against the HTML prototype at
// http://127.0.0.1:7755/GoDesk.html
//
// This screen is replaced by the real Home/Files/Settings screens in
// Phase 2.2.

import 'package:flutter/material.dart';

import '../chrome/skeuo_chrome.dart';
import '../kit/knob.dart';
import '../kit/lcd_panel.dart';
import '../kit/metal_panel.dart';
import '../kit/section_label.dart';
import '../kit/status_led.dart';
import '../kit/tactile_button.dart';
import '../kit/toggle.dart';
import '../kit/vu_meter.dart';
import '../theme/godesk_theme.dart';
import '../theme/tweaks.dart';
import '../theme/typography.dart';

class KitDemoScreen extends StatefulWidget {
  const KitDemoScreen({required this.controller, super.key});

  final TweaksController controller;

  @override
  State<KitDemoScreen> createState() => _KitDemoScreenState();
}

class _KitDemoScreenState extends State<KitDemoScreen> {
  SkeuoTab _tab = SkeuoTab.home;
  bool _toggleA = true;
  bool _toggleB = false;
  double _knobA = 70;
  double _knobB = 45;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return Scaffold(
      backgroundColor: t.bg.darken(0.02),
      body: Center(
        child: Container(
          width: 920,
          height: 620,
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: t.chromeBorder),
            boxShadow: <BoxShadow>[
              const BoxShadow(color: Color(0x4D000000), spreadRadius: 1),
              const BoxShadow(
                color: Color(0x4D000000),
                offset: Offset(0, 24),
                blurRadius: 60,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(
              children: <Widget>[
                SkeuoChrome(current: _tab, onTab: (v) => setState(() => _tab = v)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: SingleChildScrollView(child: _leftColumn(t)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SingleChildScrollView(child: _rightColumn(t)),
                        ),
                      ],
                    ),
                  ),
                ),
                _Footer(controller: widget.controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leftColumn(GoDeskTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // LEDs + section label
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Status LEDs'),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  const StatusLED(color: LEDColors.online, pulse: true),
                  const SizedBox(width: 8),
                  Text('Online (breathe)', style: GDtype.ui(size: 11, color: t.body)),
                  const Spacer(),
                  const StatusLED(color: LEDColors.warning, blink: true),
                  const SizedBox(width: 8),
                  Text('Warn (blink)', style: GDtype.ui(size: 11, color: t.body)),
                  const Spacer(),
                  const StatusLED(color: LEDColors.danger),
                  const SizedBox(width: 8),
                  Text('Static', style: GDtype.ui(size: 11, color: t.body)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // LCD readouts
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Your ID'),
              const SizedBox(height: 8),
              LCDPanel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('> ID:', style: lcdDimLabel(theme: t)),
                    const SizedBox(height: 4),
                    Text('742 819 365',
                        style: lcdReadout(theme: t, size: 26)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const SectionLabel('One-time password'),
              const SizedBox(height: 6),
              LCDPanel(
                child: Text('k7q-m4n', style: lcdReadout(theme: t, size: 18)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Buttons row
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Tactile buttons'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  TactileButton(onPressed: () {}, child: const Text('DEFAULT')),
                  TactileButton(
                    onPressed: () {},
                    variant: TactileVariant.primary,
                    child: const Text('PRIMARY'),
                  ),
                  TactileButton(
                    onPressed: () {},
                    variant: TactileVariant.danger,
                    child: const Text('DANGER'),
                  ),
                  TactileButton(
                    onPressed: () {},
                    small: true,
                    child: const Text('SMALL'),
                  ),
                  const TactileButton(child: Text('DISABLED')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rightColumn(GoDeskTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Toggles
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Toggles'),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text('Launch at login',
                        style: GDtype.ui(size: 12, color: t.heading, weight: FontWeight.w500)),
                  ),
                  GoDeskToggle(
                    value: _toggleA,
                    onChanged: (v) => setState(() => _toggleA = v),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text('Share clipboard',
                        style: GDtype.ui(size: 12, color: t.heading, weight: FontWeight.w500)),
                  ),
                  GoDeskToggle(
                    value: _toggleB,
                    onChanged: (v) => setState(() => _toggleB = v),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Knobs
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Audio'),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(child: _KnobCell(label: 'Volume', value: _knobA, onChanged: (v) => setState(() => _knobA = v))),
                  Expanded(child: _KnobCell(label: 'Mic gain', value: _knobB, onChanged: (v) => setState(() => _knobB = v))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // VU Meters
        MetalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionLabel('Throughput'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  VUMeter(value: 0.62, label: '↑ TX'),
                  VUMeter(value: 0.31, label: '↓ RX', color: t.lcdInk),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KnobCell extends StatelessWidget {
  const _KnobCell({required this.label, required this.value, required this.onChanged});
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Knob(value: value, onChanged: onChanged),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SectionLabel(label),
            const SizedBox(height: 4),
            LCDPanel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                '${value.round()}%',
                style: lcdReadout(theme: t, size: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});
  final TweaksController controller;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).extension<GoDeskTheme>()!;
    final tw = controller.value;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: t.chromeGradient,
        border: Border(top: BorderSide(color: t.chromeBorder)),
      ),
      child: Row(
        children: <Widget>[
          const StatusLED(color: LEDColors.online, pulse: true, size: 6),
          const SizedBox(width: 8),
          Text(
            'RELAY EU-WEST-1 · P2P · 12ms · AES-256',
            style: GDtype.mono(size: 9, color: t.body, letterSpacing: 0.5),
          ),
          const Spacer(),
          // Live tweaks readout
          Text(
            'dark=${tw.darkMode}  accent=${tw.accent}  lcd=${tw.lcd}  i=${tw.intensity.toStringAsFixed(1)}',
            style: GDtype.mono(size: 9, color: t.subtle, letterSpacing: 0.5),
          ),
          const SizedBox(width: 8),
          Text('v0.1.0',
              style: GDtype.mono(size: 9, color: t.subtle, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

extension on Color {
  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}
