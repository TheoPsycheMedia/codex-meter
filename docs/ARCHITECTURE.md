# Architecture

Codex Meter is a SwiftPM macOS app. It uses SwiftUI for the widget and settings UI, with small AppKit controllers for menu-bar and floating-panel behavior.

## Runtime Flow

1. `AppDelegate` starts the menu-bar app, creates the widget panel, creates the status-item quick peek, creates the settings window, and starts auto-refresh.
2. `WidgetStore` owns observable app state and lightweight preferences.
3. `CodexAuthTokenReader` reads the local Codex auth file.
4. `UsageClient` calls the usage endpoint.
5. `RateLimitResetClient` calls the reset-credit endpoint.
6. `UsageHistoryStore` appends local runway snapshots and alert ledger state.
7. `RunwayPredictionService` computes weekly-first forecasts from local observed usage pace.
8. `SessionReadinessAdvisor` translates current usage and runway forecasts into decision-oriented session guidance.
9. `SmartNotificationService` sends local Apple User Notifications when enabled.
10. `MeterWidgetView` renders Reset Bank, usage meters, Spark grouping, session readiness, runway rows, and controls.
11. `StatusPopoverView` renders the compact menu-bar quick peek.

For user-facing behavior, see [APP_FUNCTIONS.md](APP_FUNCTIONS.md).

## Key Files

```text
Sources/CodexMeter/App/AppDelegate.swift
Sources/CodexMeter/Controllers/WidgetWindowController.swift
Sources/CodexMeter/Controllers/StatusPopoverController.swift
Sources/CodexMeter/Stores/WidgetStore.swift
Sources/CodexMeter/Services/CodexAuthTokenReader.swift
Sources/CodexMeter/Services/UsageClient.swift
Sources/CodexMeter/Services/RateLimitResetClient.swift
Sources/CodexMeter/Services/UsageHistoryStore.swift
Sources/CodexMeter/Services/RunwayPredictionService.swift
Sources/CodexMeter/Services/SessionReadinessAdvisor.swift
Sources/CodexMeter/Services/SmartNotificationService.swift
Sources/CodexMeter/Support/Localization.swift
Sources/CodexMeter/Models/UsageSnapshot.swift
Sources/CodexMeter/Models/RunwayModels.swift
Sources/CodexMeter/Models/AlertPreferences.swift
Sources/CodexMeter/Views/MeterWidgetView.swift
Sources/CodexMeter/Views/StatusPopoverView.swift
Sources/CodexMeter/Views/SettingsView.swift
Sources/CodexMeter/Resources/
```

## Auth Boundary

The app reads:

```text
~/.codex/auth.json
```

It extracts the access token and keeps it in memory only for the request. Token handling should remain inside `CodexAuthTokenReader` and the endpoint clients.

Do not add logging around auth headers or raw auth-file contents.

## Endpoint Boundary

The app calls two ChatGPT backend endpoints:

```text
GET /backend-api/wham/usage
GET /backend-api/wham/rate-limit-reset-credits
```

These are not public API contracts. Decode defensively, keep optional fields optional, and show honest unavailable states when fields are absent.

## UI State

`WidgetStore` stores preferences in `UserDefaults`:

- selected color mood
- auto-refresh enabled
- refresh interval
- show/hide Spark meters
- meter style

All network refreshes flow through `WidgetStore.refresh()` so loading, errors, usage, and reset-credit state stay consistent.

## Localization

User-facing app strings are loaded through `L10n` from SwiftPM-bundled `Localizable.strings` files. English is the default localization and fallback. The app currently ships Spanish, Simplified Chinese, Japanese, and Korean resources for the widget, settings, menu-bar menu, notifications, and visible error/recovery text.

Keep protocol keys, endpoint names, diagnostic field labels, and persisted `UserDefaults` keys out of localization unless their meaning is purely presentational. DMG and local run scripts copy the SwiftPM resource bundle into the generated `.app` so packaged builds can resolve `Bundle.module` resources.

## Meter Rules

Codex Meter displays remaining capacity:

- 90-100%: green
- 20-89%: amber
- 0-19%: red

The decorative color mood should not override depletion status colors.

Spark usage is grouped separately because it appears as a separate backend meter. Spark 5h can fall back to 100% when absent. Spark weekly should only render when a Spark secondary window is present.

## Runway Prediction

Runway prediction is local and percentage-based. Each successful refresh records sanitized window observations:

- sampled time
- window kind
- remaining percent
- used percent
- reset countdown
- reset date when provided

Supported runway kinds:

- `codex-primary`
- `codex-weekly`
- `spark-primary`
- `spark-weekly`

The widget renders weekly-first forecasts. Codex compares against `codex-weekly`; Spark compares against `spark-weekly`. The 5h windows remain available to the prediction engine and alerts, but they are not the primary runway surface.

The forecast engine computes hourly consumption rates from usage deltas between local snapshots. It ignores reset-boundary segments where used percentage drops or the reset date changes.

Expected pace uses weighted buckets:

- recent 3h pace: 45%
- current reset-window pace: 30%
- last 24h pace: 20%
- rolling local baseline: 5%

Variable ranges use percentile-style optimistic and cautious rates rather than raw min/max rates. This keeps one burst from dominating the forecast. Stable confidence shows a single expected estimate.

Reset dates should use backend `reset_at` when present. If `reset_at` is absent, the app derives a date from `reset_after_seconds` so the user can still compare the runway estimate against a concrete reset time.

## Session Readiness

Session readiness is a local interpretation layer over current usage windows and `UsageWindowForecast` values. It does not call any endpoint, inspect prompts, persist new private data, or read token-level usage.

The advisor currently maps usage into four product states:

- ready: current windows and forecast look comfortable for a normal focused session
- watch: weekly or lowest-window usage is low, variable, or trending tighter
- save: a window is critically low or forecast to exhaust before reset
- learning: usage exists but local history is not yet sufficient for confident guidance

The widget and menu-bar quick peek read the same `WidgetStore.sessionReadinessAdvice` value so the decision copy stays consistent.

## Smart Notifications

Smart alerts are entirely local Apple User Notifications. `SmartNotificationService` only requests permission and schedules notification content on this Mac.

Alert preferences stay in `UserDefaults`; alert dedupe ledger state stays in the local runway history payload under Application Support.

Notifications must not include auth tokens, account identifiers, raw endpoint responses, or model/prompt content.

## Window Behavior

The widget panel is borderless, floating, resizable, and resettable.

The top-right control with `arrow.up.right.square` resets the panel to the default size and top-right position. It is not an expand button.
