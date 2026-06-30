# App Functions

This document explains what Codex Meter does at runtime and how each user-facing control should behave.

## Menu-Bar App

Codex Meter runs as a menu-bar utility, not a Dock app. The app uses `LSUIElement` so it stays out of the Dock and app switcher.

Expected behavior:

- left-click the menu-bar icon to open the quick peek popover
- right-click or Control-click the icon to open the app menu
- keep the app running when the widget is hidden
- quit only when the user chooses Quit from the menu

## Menu-Bar Quick Peek

The quick peek is a compact native popover from the menu-bar item. It should answer the most common question without opening the full floating widget: whether the user can keep working, which bucket is lowest, when that bucket resets, and how many reset credits are available.

Expected behavior:

- shows Session Readiness guidance from local usage and runway data
- shows the lowest remaining usage bucket
- shows Reset Bank available count
- shows the next reset countdown for the lowest bucket
- lists the current usage windows in compact rows
- includes Refresh Now, Show/Hide Codex Meter, and Settings actions
- keeps right-click and Control-click reserved for the full menu

## Floating Widget

The widget is a floating AppKit panel with a SwiftUI view inside it. It is designed to sit near the top-right corner of macOS, above normal windows.

Expected behavior:

- the panel can be dragged
- the panel can be resized
- closing or hiding the panel keeps the menu-bar app alive
- Reset Position and Size restores the default frame and top-right placement

## Header Buttons

The widget header contains three icon buttons:

- Refresh: calls the backend immediately and updates Reset Bank plus usage meters.
- Reset Position and Size: restores the widget to the default size and top-right position.
- Hide: hides the widget while leaving the menu-bar app running.

The reset-position button uses `arrow.up.right.square`. It is a placement reset, not an expand/fullscreen control.

## Reset Bank

Reset Bank shows the currently available reset credits returned by:

```text
GET https://chatgpt.com/backend-api/wham/rate-limit-reset-credits
```

Each reset credit should show:

- reset number
- availability status
- granted date
- expiration date

Granted and expiration dates should remain visible near the top of the widget so users do not need to scroll to find them.

## Usage Remaining

Usage Remaining shows remaining capacity from:

```text
GET https://chatgpt.com/backend-api/wham/usage
```

Supported meters:

- Codex 5h
- Codex weekly
- Codex-Spark 5h
- Codex-Spark weekly

The app displays remaining capacity, not consumed capacity. For example, `97%` means 97% appears available.

## Codex-Spark Behavior

Codex-Spark meters are grouped separately from regular Codex usage because they represent a distinct backend usage bucket.

Expected behavior:

- Spark 5h should display as `100%` when the user enables Spark meters and the backend has not returned Spark usage yet.
- Spark weekly should display only when the backend returns a Spark weekly or secondary window.
- Spark meters should visually stand out from regular Codex meters.

## Predictive Runway

Predictive runway estimates whether the current observed usage pace appears safe until the next reset. It is a local forecast, not an exact quota guarantee.

Session Readiness translates those forecasts and current usage windows into decision-oriented guidance:

- `Safe for a 2h session`
- `Watch weekly usage`
- `Save heavy work until reset`
- `Runway coach is learning`

This guidance is shown in the widget and the menu-bar quick peek. It remains local and percentage-based; it does not inspect prompts, model names, account identifiers, raw endpoint responses, or token-level usage.

The widget shows runway inline under weekly usage meters:

- Codex weekly runway appears under Codex weekly.
- Spark weekly runway appears under Spark weekly.
- The copy compares the forecast with the actual reset date when the backend provides `reset_at`.
- If `reset_at` is absent, the app derives a concrete reset date from `reset_after_seconds`.

Prediction copy should stay humble and decision-oriented:

- `Likely safe through Jun 24, 5:18 PM`
- `Variable pace toward Jun 24, 5:18 PM`
- `May run out Jun 21, 6:36 AM`
- `Codex weekly · Reset Jun 24, 5:18 PM · Est. 0-68%`
- `Spark weekly · Est. 82% by Jun 24, 8:31 PM`

Runway confidence:

- Stable: enough local samples, recent data, steady pace, and no major acceleration.
- Variable: enough signal to forecast, but pace has meaningful variation or acceleration.
- Limited data: not enough reliable local history yet.

Runway estimates are based on local observed usage snapshots. They do not inspect individual model names, prompts, account details, raw endpoint responses, or token-level usage.

## Smart Alerts

Smart alerts are local Apple User Notifications. They are disabled until the user grants notification permission and enables alerts in Settings.

Supported alert types:

- low remaining capacity thresholds: 20%, 10%, 5%
- projected exhaustion before reset
- reset credit expires within 24 hours
- reset capacity becomes available again

Alerts should dedupe by reset cycle and alert type so the app does not repeatedly notify for the same condition.

## Meter Styles

Users can choose the meter presentation in Settings:

- Circular
- Bars
- Battery

All styles use the same underlying usage percentages and health colors.

## Health Colors

Codex Meter colors meters by remaining capacity:

- Green: 90-100%
- Amber: 20-89%
- Red: 0-19%

These colors should always describe usage health. Decorative color themes should not override them.

## Refresh Behavior

The app can refresh manually or automatically.

Manual refresh:

- widget Refresh button
- menu-bar Refresh Now item
- settings Refresh Now button

Automatic refresh:

- controlled by Settings
- uses the selected refresh interval
- keeps previous values visible while a refresh is in progress
- shows a readable error state if auth or networking fails

## Local Data

Codex Meter reads the Codex auth token from:

```text
~/.codex/auth.json
```

The token is kept in memory only for requests to ChatGPT backend endpoints. The app stores UI preferences in `UserDefaults`.

Runway history is stored locally under Application Support:

```text
~/Library/Application Support/CodexMeter/usage-history-v1.json
```

The history file stores sampled percentages, reset timing, and local alert ledger state. It must not store auth tokens, raw private endpoint payloads, account identifiers, prompts, or analytics events.

Do not log, display, persist, or include tokens in bug reports.
