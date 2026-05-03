<div align="center">

# GoDesk

**Encrypted remote desktop with a tactile, hardware-instrument UI.**
Fork of [RustDesk](https://github.com/rustdesk/rustdesk) under AGPL-3.0.

[Download](https://godeskflow.com) • [Source](https://github.com/GoDeskFlow) • [Docs](https://github.com/GoDeskFlow/godesk-docs) • [Privacy](https://github.com/GoDeskFlow/godesk-docs/blob/main/privacy.md)

![GoDesk Home screen](docs/screenshots/home.png)

</div>

---

## What it is

GoDesk lets you control any computer over the internet — encrypted
end-to-end, peer-to-peer when network conditions allow, with no account
required. Connect by 9-digit ID + one-time code.

**Status: pre-public-launch.** Server-side infrastructure is live at
godeskflow.com. Signed Windows installer ships once code-signing
certificate validation completes. Open issues for bugs you find in the
unsigned beta.

## Why this fork exists

[RustDesk](https://github.com/rustdesk/rustdesk) is excellent technology
with a generic Material UI. We replaced that UI entirely with a
skeuomorphic, Dieter-Rams-inspired design — brushed metal panels,
beveled tactile buttons, glowing LCD readouts, physical knobs, ambient
LED indicators. The Rust core, networking protocol, and platform-API
layer remain inherited (small delta from upstream); only the UI is full
replacement. See [ADR-010](../wiki/decisions.md) and [ADR-011](../wiki/decisions.md) for the rationale.

## Screenshots

|||
|:-:|:-:|
| ![Home](docs/screenshots/home.png) **Home** — your ID, OTP, diagnostics, address book, connect by remote ID | ![Files](docs/screenshots/files.png) **Files** — analog VU meters, transfer queue, throughput readout |
| ![Settings](docs/screenshots/settings.png) **Settings** — General / Video & Audio / Security / Network / About | ![Onboarding](docs/screenshots/onboarding.png) **Onboarding** — 4-step first-run wizard |
| ![Connecting](docs/screenshots/connecting.png) **Connecting overlay** — radar pulse + 4-stage handshake | ![Session](docs/screenshots/session.png) **Active session** — floating toolbar over remote desktop |

[Widget kit demo](docs/screenshots/kit.png) — every primitive in the skeuo
kit (TactileButton, LCDPanel, MetalPanel, Toggle, Knob, VUMeter,
StatusLED, SectionLabel, SkeuoChrome) on one screen.

## Install

### Windows

Pre-built installer: <https://godeskflow.com/downloads/windows> *(coming
soon, awaiting code-signing cert)*. Until then, build from source per the
upstream RustDesk instructions and substitute `flutter_godesk/` for the
Flutter dir:

```powershell
git clone https://github.com/GoDeskFlow/godesk-client
cd godesk-client
git submodule update --init --recursive
python build_godesk_patch.py     # one-line patch to upstream build.py
python build.py --flutter --portable
```

Output: `build/windows/x64/runner/Release/godesk.exe`.

macOS, Linux, Android, iOS clients are on the roadmap (Phase 5+).

## Architecture

This repo is the **client**. Other GoDeskFlow repos:

- [godesk-server](https://github.com/GoDeskFlow/godesk-server) — `hbbs`
  (signaling) + `hbbr` (relay) — fork of `rustdesk-server`
- [godesk-infra](https://github.com/GoDeskFlow/godesk-infra) — Docker
  compose + NSIS installer + deployment
- [godesk-docs](https://github.com/GoDeskFlow/godesk-docs) — public
  end-user documentation

## Project layout

```
client/
├── flutter/                 upstream RustDesk Flutter UI — untouched, reference only
├── flutter_godesk/          OUR overlay — skeuomorphic UI
│   ├── lib/
│   │   ├── theme/             tokens, bevels, GoDeskTheme, typography, tweaks (persisted)
│   │   ├── kit/               9 widget primitives ported from the design handoff
│   │   ├── chrome/            44px brushed-metal title bar (frameless window)
│   │   ├── screens/           home, files, settings, onboarding, connecting, session
│   │   ├── bridge/            Bridge interface + MockBridge (default) + RealBridge (TODO)
│   │   ├── config/            compile-time infra constants
│   │   └── util/              format, a11y, platform_polish (tray + single-instance)
│   ├── assets/fonts/          Inter, JetBrains Mono — bundled, offline-first
│   └── windows/runner/        frameless Win32 host
├── src/                     RustDesk Rust core — small delta from upstream
└── build_godesk_patch.py    idempotent patcher for upstream build.py
```

## Phase status

| | What | Done? |
|:-:|---|:-:|
| 0 | Decisions (path, license, brand, infra, markets) | ✅ |
| 1 | Forks + clean upstream server build | ✅ |
| 2.0 | Theme tokens + persistence + first window | ✅ |
| 2.1 | 9-widget skeuomorphic kit | ✅ |
| 2.2 | All 6 screens + routing + onboarding | ✅ |
| 2.3 | Bundled fonts + a11y + frameless chrome + tray + crash log | ✅ |
| 2.4 | Bridge interface decoupling | ✅ |
| 2.4 | RealBridge wiring to Rust core (FFI) | 🟡 awaiting cargo-build session |
| 3 | Production hbbs+hbbr live on godeskflow.com | ✅ |
| 4 | NSIS installer (unsigned) | ✅ |
| 4 | Code-signing certificate purchase + signing | 🟡 awaiting Cyprus ROC clearing |
| 4 | hbbr split to dedicated VPS before public launch | 🔲 |
| 5 | Public docs (source, privacy, EULA, install, troubleshoot, security) | ✅ |
| 5 | Public launch announcement | 🔲 post-cert |

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md). Bugs and feature requests
welcome via [Issues](https://github.com/GoDeskFlow/godesk-client/issues).
Security: see [docs/security.md](https://github.com/GoDeskFlow/godesk-docs/blob/main/security.md).

## License

[AGPL-3.0-only](../LICENSE). Source code distributed with every binary
per AGPL §13. See [NOTICE](../NOTICE) for upstream attribution and
significant modifications.

The "GoDesk" name and logo are trademarks of UPDEVTEAM LTD. The AGPL
grants you rights to the code, not to the trademark — please rename
forks.
