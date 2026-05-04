// GoDesk infrastructure configuration — compile-time constants.
//
// This file mirrors what RustDesk core compiles in via `RENDEZVOUS_SERVERS`
// and `RS_PUB_KEY` in `client/src/config.rs`. The Flutter UI side reads the
// same values through this file, so the "About" / Settings → Network screens
// can show what server the running build is wired to.
//
// When the Rust core's compile-time defaults change, update both here and in
// the patched `client/src/config.rs` to keep them in sync.
//
// Per [ADR-003] (self-hosted infra) and [ADR-005] (shared VPS during MVP).

class GoDeskInfra {
  GoDeskInfra._();

  /// Rendezvous server hostname. Compiled into the client; users do not need
  /// to type it. Resolves to the godeskflow.com VPS during Phase 1–3 (MVP).
  static const String rendezvousHost = 'id.godeskflow.com';

  /// Default rendezvous TCP port (RustDesk-default 21115; the relay sits one
  /// over at 21117).
  static const int rendezvousPort = 21115;

  /// Relay server hostname. Same VPS as rendezvous during MVP; will split to
  /// a dedicated VPS before Phase 4 public launch (per ADR-005).
  static const String relayHost = 'relay.godeskflow.com';
  static const int relayPort = 21117;

  /// WebSocket fallback ports — used by the future browser client (TBD).
  static const int rendezvousWsPort = 21118;
  static const int relayWsPort = 21119;

  /// Rendezvous server's ed25519 public key (base64). The client uses this to
  /// authenticate the rendezvous server and reject MitM. Generated once on
  /// the VPS via `docker run rustdesk/rustdesk-server rustdesk-utils
  /// genkeypair`; the secret half lives offline + on the VPS only.
  ///
  /// Public-by-design — burning this into the binary is correct.
  static const String rendezvousPublicKey =
      '2Db7cpnlMVASoi29tZ3oGpt+bvyGlhl14ZxqxLURFO8=';

  /// Update server (Phase 4 — replaces RustDesk's update channel with ours).
  static const String updateChannelUrl = 'https://update.godeskflow.com/win/x64';

  /// Marketing site (footer links, About → website link).
  static const String websiteUrl = 'https://godeskflow.com';
  static const String supportUrl = 'https://godeskflow.com/help';
  static const String sourceUrl = 'https://github.com/GoDeskFlow';
  static const String privacyUrl = 'https://godeskflow.com/privacy';

  /// Build identity used in About + crash reports.
  static const String productName = 'GoDesk';
  static const String bundleId = 'com.godesk.client';
  static const String licenseSpdx = 'AGPL-3.0-only';
  static const String upstream = 'github.com/rustdesk/rustdesk@v1.4.6';

  /// Single source of truth for the displayed app version. Bumped alongside
  /// the NSIS installer's `-DGODESK_VERSION=X.Y.Z` flag and `pubspec.yaml`'s
  /// `version:` line. Read by Settings → About and the bottom-bar footer
  /// instead of hardcoding `v0.1.0` in two places.
  static const String appVersion = '0.2.1';

  /// Compact build stamp — Y.MM.DD shown next to the version in About.
  /// Update when cutting a new build.
  static const String buildStamp = '26.05.03';
}
