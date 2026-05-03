# flutter_godesk

GoDesk skeuomorphic UI — sibling Flutter package replacing upstream `client/flutter`.
Per [ADR-010](../../wiki/decisions.md) and [ADR-011](../../wiki/decisions.md).

## Layout

```
lib/
├── main.dart           Entry point (Phase 2.0 stub → real wiring in Phase 2.2)
├── theme/
│   ├── tokens.dart       Palettes (Light, Dark, accents×4, lcdPalettes×4, status)
│   ├── bevels.dart       BoxShadow recipes for outset/inset bevels
│   ├── godesk_theme.dart ThemeExtension<GoDeskTheme> + makeSkeuoTheme(...)
│   └── tweaks.dart       Persisted user prefs (shared_preferences)
├── kit/                Phase 2.1 widget primitives (pending)
├── chrome/             Title bar + tabs (pending)
├── screens/            Phase 2.2 (pending)
└── bridge/             FFI to Rust core (pending)

assets/
├── fonts/              Inter Tight + JetBrains Mono — see fonts/README.md
└── icons/              Custom skeuo icons (pending)
```

## Reference design

Live HTML prototype: `branding/design-system/GoDesk.html`. Serve via
`python -m http.server 7755` from that directory.

Tokens, bevel recipes, accent palettes, animation curves are direct ports
from `branding/design-system/components/godesk-skeuo-kit.jsx`.

## Build target

`build.py` selects this package via a flag (TBD in Phase 2.0) instead of
upstream `client/flutter/`. The upstream Flutter dir stays untouched as a
reference for FFI signatures.

## Local dev

Phase 2.0 deps only — no Rust core wired yet:

```
cd client/flutter_godesk
flutter pub get
flutter run -d windows
```

You should see a 920×620 window with "GoDesk — theme bootstrapped — kit pending"
in the active accent color. Tweaks persistence (dark/accent/lcd/intensity) is
already wired to `shared_preferences` but no UI surface exposes it yet.
