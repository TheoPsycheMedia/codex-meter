# Changelog

## 0.2.0 - 2026-06-20

Four-PR feature release for Codex Meter.

### Added

- Codex-first menu-bar usage display modes, including icon-only, percent-only, reset-time, primary-plus-weekly, and lowest-overall views.
- Launch-at-login settings backed by macOS `SMAppService`.
- Resilient last-known-good behavior when usage or reset-credit endpoints fail independently.
- Privacy-safe Copy Diagnostics from the widget and Settings.
- Local runway predictions for Codex and Codex-Spark weekly usage windows.
- Local smart alerts for low capacity, projected runout, expiring reset credits, and restored reset capacity.
- SwiftPM regression tests and GitHub Actions CI.

### Changed

- Health colors now treat 50-100% remaining as healthy, 20-49% as warning, and below 20% as critical.
- Menu-bar status updates now track endpoint failure state instead of the removed legacy error message.
- Release packaging keeps the ad-hoc signed DMG flow while preserving the Gatekeeper/notarization caveat.

## 0.1.0

Initial public release candidate.

### Added

- Native macOS menu-bar app.
- Floating, resizable Codex Meter widget.
- Reset Bank with available count, granted dates, and expiration dates.
- Codex 5h and weekly usage meters.
- Codex-Spark 5h and weekly meters when available.
- Circular, Bars, and Battery meter styles.
- Health-based meter colors.
- Settings window for refresh interval, Spark visibility, and meter style.
- Local auth reader for `~/.codex/auth.json`.
- Privacy, security, contribution, architecture, and release docs.

### Notes

- Uses undocumented ChatGPT backend endpoints that may change.
- Development build is ad-hoc signed and not notarized.
