# FFI mapping — `Bridge` interface → upstream RustDesk `flutter_ffi.rs`

When `flutter_rust_bridge_codegen` produces `generated_bridge.dart`, the
RealBridge wrapper translates our `Bridge` interface methods into calls on
the RustDesk-exported functions. This file is the lookup table.

Upstream surface area: **325 `pub fn`** in `client/src/flutter_ffi.rs`.
Our MVP needs ~20.

## Identity

| Bridge method | Rust fn | Notes |
|---------------|---------|-------|
| `identity().id` | `main_get_my_id() -> String` | The 9-digit ID. Sync. |
| `identity().deviceName` | `main_get_options()` → JSON, key `"name"` | One of many keys in main options map. |
| `oneTimePassword()` | (TBD — likely `main_get_options()` key `"password"` or via session) | Sync helper to be confirmed in Rust source. |
| `regeneratePassword()` | `main_set_option("password", "")` then `main_get_options()` | RustDesk regenerates on empty. |

## Address book

| Bridge method | Rust fn | Notes |
|---------------|---------|-------|
| `peers()` (initial load) | `main_load_recent_peers()` (void) → triggers GLOBAL event stream | Stream parses event JSON to peer list. |
| `peers()` (sync snapshot) | `main_load_recent_peers_for_ab(filter: String)` → JSON | Returns all peers matching filter. |
| `peers()` (favorites) | `main_load_fav_peers()` | Same pattern. |
| `upsertPeer(p)` | `main_set_peer_alias(id, alias)` + `main_set_peer_option(id, k, v)` | Multi-call for full upsert. |
| `forgetPeer(id)` | `main_remove_peer(id: String)` | Sync. |

## Diagnostics

| Bridge method | Rust fn | Notes |
|---------------|---------|-------|
| `diagnostics()` | global event stream → events with `type: "stats"` etc. | Latency, NAT, relay region all flow through global stream as JSON events. |

## Connect / session

| Bridge method | Rust fn | Notes |
|---------------|---------|-------|
| `connect(peerId)` | `session_add_sync(...) -> SessionID` then `session_start(session_id, ...)` | Two-step: register session, then start. |
| `cancelConnect()` | `session_close(session_id)` | Same call as disconnect — distinguished by current state on Dart side. |
| `disconnect()` | `session_close(session_id)` | |
| `connectEvents()` | global event stream → events scoped to session_id | Parse `type: "msgbox" / "permission" / "connecting" / "connected"`. |

## Transfers

| Bridge method | Rust fn | Notes |
|---------------|---------|-------|
| `transfers()` | global event stream → `type: "file_dir"` / `type: "job_progress"` | All transfer state pushed via stream. |
| `addTransfer(...)` | `session_add_job(...)` (search exact name in source) | Files only — folders are recursive on the Rust side. |
| `cancelTransfer(id)` | `session_cancel_job(session_id, job_id)` | |
| `clearCompleted()` | (UI-only — we just filter the local list) | No Rust call. |

## Event stream — the spine

```rust
pub fn start_global_event_stream(s: StreamSink<String>, app_type: String) -> ResultType<()>
```

Called once at app start. The `StreamSink<String>` accepts JSON-encoded
events. Every async result, every state change, every transfer progress
tick comes through here. RealBridge's job is to:

1. Spin up a single subscription to this stream.
2. Demultiplex events by `type` field (`msgbox`, `peer`, `transfer`,
   `clipboard`, `cursor`, `frame`, `stats`, etc).
3. Re-emit on per-capability streams (`peers()`, `transfers()`,
   `connectEvents()`, `diagnostics()`).

Dart-side schema: the existing `lib/bridge/bridge.dart` `Stream<X>`
signatures already match this fan-out — implementation is mechanical.

## Settings (Settings screen)

A few examples — full set is `session_get_*` / `session_set_*` and
`main_get_options` / `main_set_option`:

| UI control | Rust fn |
|------------|---------|
| Image quality (Eco/Balanced/Quality/Lossless) | `session_get_image_quality(session_id)` / `session_set_image_quality(session_id, value)` |
| Volume / mic gain (Knob) | `session_set_option(session_id, "volume", value)` / similar |
| Toggle "Launch at login" | `main_set_option("enable-auto-launch", "Y" / "")` |
| Permissions on incoming sessions | `main_set_option("allow-remote-config-modification", ...)` etc |
| Encryption display | static — `AES-256-GCM` always |

## What Mock vs Real do differently

`MockBridge` (current default) ships a full implementation using static
data and timers — every screen renders meaningfully on first launch.

`RealBridge` (Phase 2.4) replaces each method with a one-liner call into
generated FFI. The `Bridge` interface stays the same. UI code in
`screens/` does not change.

## Implementation order for Phase 2.4

1. Get `cargo build --release` succeeding (vcpkg + 22 native libs).
2. Run `flutter_rust_bridge_codegen` to produce `generated_bridge.dart`.
3. Implement `RealBridge.identity()` first — minimal, just `main_get_my_id`. Verify the real ID shows on Home screen.
4. Then `peers()` — verify Address Book populates from RustDesk's stored peers.
5. Then `connect()` — verify ConnectingOverlay advances through real handshake stages.
6. Then transfers, settings, diagnostics — order doesn't matter once event-stream demultiplexer works.
7. Flip `main.dart`: `MockBridge()` → `RealBridge()`, ship `--dart-define=GODESK_REAL_BRIDGE=1` for parallel-running stage.
