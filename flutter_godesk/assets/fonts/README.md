# Fonts

Bundled fonts for GoDesk. Both are SIL Open Font License 1.1 — shipping them
inside the AGPL app is fine.

## Required files

| Family | Weight | File | Source |
|--------|--------|------|--------|
| Inter Tight | 400 | `InterTight-Regular.ttf` | https://fonts.google.com/specimen/Inter+Tight |
| Inter Tight | 500 | `InterTight-Medium.ttf` | same |
| Inter Tight | 600 | `InterTight-SemiBold.ttf` | same |
| Inter Tight | 700 | `InterTight-Bold.ttf` | same |
| Inter Tight | 800 | `InterTight-ExtraBold.ttf` | same |
| JetBrains Mono | 400 | `JetBrainsMono-Regular.ttf` | https://fonts.google.com/specimen/JetBrains+Mono |
| JetBrains Mono | 500 | `JetBrainsMono-Medium.ttf` | same |
| JetBrains Mono | 600 | `JetBrainsMono-SemiBold.ttf` | same |
| JetBrains Mono | 700 | `JetBrainsMono-Bold.ttf` | same |

## How to populate

Easiest: download the family ZIP from Google Fonts, extract, copy the named
TTFs above into this directory.

Alternative — automate via `dart pub run google_fonts` once we add the
`google_fonts` package script (NOT recommended for production: bundles via
runtime fetch the first time, which is bad on offline launches).

## Why bundled and not Google Fonts CDN

The marketing-site prototype loaded fonts from Google Fonts CDN — fine for
the browser. For a desktop app:

- Offline-first: clients connect to remote machines from networks with arbitrary
  egress restrictions. The UI must render correctly without internet.
- AGPL §13: source-availability includes everything the app needs to run; no
  external service dependency at runtime.
- Performance: zero startup network round-trip.
