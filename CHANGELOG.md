# Changelog

## 0.4.0 - 2026-06-30

Feature release for decision-oriented session guidance and a faster menu-bar workflow.

### Added

- Added Session Readiness guidance that translates runway predictions into work decisions: safe, watch, or save heavy work.
- Added reset-bank-aware readiness logic so available reset credits soften immediate-risk guidance instead of over-warning.
- Added a compact menu-bar quick peek with readiness, lowest window, reset bank, next reset, usage bars, refresh, widget toggle, and settings actions.
- Added regression tests for fresh-reset headroom, 2-hour watch guidance, 1-hour save guidance, and reset-bank downgrades.

### Changed

- Readiness now turns yellow when projected exhaustion is within 2 hours and red when it is within 1 hour.
- Freshly reset or high-headroom windows no longer trigger "save heavy work" from stale aggressive pace history alone.
- Left-clicking the menu-bar item opens the quick peek; right-click or Control-click still opens the full menu.
- Release docs now include quick peek verification in the manual release checklist.

## 0.3.0 - 2026-06-29

Feature release for native localization support.

### Added

- Added SwiftPM-bundled localized strings for the widget, settings window, menu-bar menu, local notifications, and user-facing error/recovery states.
- Added Spanish, Simplified Chinese, Japanese, and Korean localization resources with English as the default fallback.
- Added localization coverage tests to keep translated resources aligned with the English key set.

### Changed

- Release packaging now copies the SwiftPM resource bundle into the generated `.app` and declares the shipped app localizations in `Info.plist`.
- Documentation now describes the supported localized UI surface.

## 0.2.1 - 2026-06-26

Patch release for Reset Bank display scaling.

### Changed

- Reset Bank now renders every reset credit returned by the endpoint instead of clipping the list to the first two rows.
- Reset Bank rows now use lazy rendering so larger credit lists remain responsive inside the scrollable widget.

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
