# Menu-Bar Percentage + Launch At Login Planning

## Codex Session Purpose

This is a planning-only session for a future implementation PR that adds a glanceable menu-bar percentage display and a native "Launch Codex Meter at Login" setting to Codex Meter.

Do not implement production Swift behavior in this session. The goal is to give a later build pass a clear PR body: product intent, UI states, Product Design mockup requirements, technical sequencing, edge cases, acceptance criteria, and verification.

## Product Intent

Codex Meter is a native macOS menu-bar utility. This feature should make the app useful before the widget is opened:

- The menu bar should answer "how much Codex usage do I have left?" at a glance.
- The full breakdown should remain one click away in the existing widget/menu, not moved into a heavy dashboard.
- Launch at login should make the utility feel dependable without surprising the user with the large floating widget every time macOS starts.

The default product behavior should be quiet, local, and native: a template gauge icon plus compact text in the menu bar, full detail on click, and no account system, analytics, helper daemons, LaunchAgents, or external tracking.

## Scope

Plan a future PR that adds:

- Menu-bar display modes:
  - `87%`
  - `87% · 2h 14m`
  - `P 87 · W 63`
  - lowest remaining window with label, such as `W 63%`
  - icon-only
- Default display mode: lowest relevant remaining percentage, shown as `87%`.
- A status menu that exposes the full usage breakdown and mode controls.
- A Settings row for menu-bar display mode.
- A Settings toggle labeled `Launch Codex Meter at Login`.
- Native launch-at-login registration using `SMAppService.mainApp`.
- Quiet login launch behavior: after macOS login, Codex Meter starts in the menu bar, refreshes normally, and does not automatically open the floating widget.

The future PR can touch app source, tests if added, docs, and screenshots. This planning pass only creates this document.

## Non-Goals

- Do not change endpoint behavior, authentication, token handling, or payload decoding beyond what the display helper requires.
- Do not add analytics, telemetry, account systems, paid entitlement checks, helper apps, LaunchAgents, LaunchDaemons, or bundled login helper targets.
- Do not color the whole menu-bar item or use non-template menu-bar icons.
- Do not move the existing Reset Bank or Usage Remaining detail into the menu bar.
- Do not make the core percentage meter or launch-at-login feature paid.
- Do not solve notarization or Developer ID signing in the feature PR, except to document launch-at-login behavior under the current packaging state.

## UX / UI Direction

### Status Item

Use the current `NSStatusItem.variableLength` item and keep the existing template gauge icon from `StatusItemIcon.image()`. Add text only through the status button title/attributed title.

Display modes:

- `Lowest remaining percentage`
  - Text: `87%`
  - Default mode.
  - Uses the lowest relevant remaining usage window.
- `Percentage and reset time`
  - Text: `87% · 2h 14m`
  - The time is the reset countdown for the same lowest window.
  - Shorten to `87% · 2h` when under tight width if needed.
- `Primary and weekly`
  - Text: `P 87 · W 63`
  - `P` means Codex primary window.
  - `W` means Codex weekly/secondary window.
  - If one value is missing, use `P -- · W 63` or `P 87 · W --`.
- `Lowest window label`
  - Text: `W 63%`, `P 87%`, `S 92%`, or `SW 74%`.
  - Labels mean Codex primary, Codex weekly, Spark primary, and Spark weekly.
- `Icon only`
  - Text: empty.
  - Image position stays image-only.

System state text:

- Initial loading with no snapshot: `--%` in text modes, icon only in icon-only mode.
- Refreshing with prior snapshot: keep the previous configured text; show refreshing state in tooltip/menu.
- Live data: configured mode text, such as `87%`.
- Stale data with prior snapshot: keep the configured text, such as `87%`; tooltip begins `Stale · Updated 4:10 PM`, and the menu includes `Status: Stale`.
- Error with prior snapshot: keep the configured text, such as `87%`; tooltip begins `Refresh failed · Updated 4:10 PM`, and the menu includes the readable recovery/error message.
- Error with no snapshot: `ERR` in text modes, icon only in icon-only mode; tooltip and menu explain the error.
- No usage windows and no error: `--%` in text modes.

This keeps the menu bar calm. The status item should not become a blinking warning strip when stale data still gives the user useful context.

### Lowest-Window Calculation

Build a single display snapshot from the same usage semantics already used by `MeterWidgetView`.

Candidate windows:

- Codex primary: `usage.rateLimit.primaryWindow`
- Codex weekly: `usage.rateLimit.secondaryWindow`
- Spark primary: actual `codex_bengalfox` or `Codex-Spark` additional primary window, only when `showSparkUsage` is true
- Spark weekly: actual Spark secondary window, only when `showSparkUsage` is true

Rules:

- Remaining percent is `UsageWindow.remainingPercent`, clamped to `0...100`.
- Exclude the widget's synthetic Spark fallback `100%` window from the status-item calculation unless the endpoint returns a real Spark window. The menu bar should not imply a real Spark meter exists when it does not.
- Pick the lowest remaining percent.
- Ties sort by earliest reset time, then shortest reset-after seconds, then Codex before Spark.
- If no candidates exist, show the loading/error/no-data state above.
- The tooltip and menu should include all available candidates, so the menu bar can stay compact.

### Status Menu

Right-click or Control-click should keep opening the menu. Left-click should keep showing/hiding the widget.

Proposed menu labels:

- Disabled status row: `Usage: 63% remaining (Codex weekly)`
- Disabled freshness row: `Updated 4:10 PM`, `Refreshing...`, `Status: Stale`, or `Refresh failed`
- Optional disabled breakdown rows:
  - `Codex 5h: 87%`
  - `Codex weekly: 63%`
  - `Codex-Spark 5h: 92%`
  - `Codex-Spark weekly: 74%`
- `Refresh Now`
- `Show Codex Meter` or `Hide Codex Meter`
- `Reset Position and Size`
- `Menu-Bar Display` submenu:
  - `Lowest Remaining Percentage`
  - `Percentage and Reset Time`
  - `Codex Primary and Weekly`
  - `Lowest Window Label`
  - `Icon Only`
- `Settings...`
- `Quit Codex Meter`

Keep the launch-at-login control in Settings rather than adding another menu checkbox. The menu already has enough operational items.

### Settings

Use the existing settings visual language: rounded material window, clear row labels, native toggles, native pickers, simple dividers, and no nested cards.

Add two rows:

- `Menu-bar display`
  - Picker style: `.menu` or a compact native popup, not segmented, because labels are too long for the current width.
  - Options:
    - `Lowest remaining percentage`
    - `Percentage and reset time`
    - `Primary and weekly`
    - `Lowest window label`
    - `Icon only`
- `Launch Codex Meter at Login`
  - SwiftUI `Toggle`.
  - Status/help text beneath or trailing only when useful:
    - `Enabled`
    - `Approval required in System Settings`
    - `Unavailable in this build`
    - readable error text if registration fails
  - When approval is required, show a native button labeled `Open Login Items...`.

Suggested placement:

- Keep `Auto refresh while running` first.
- Keep `Refresh every` second.
- Keep `Show Codex-Spark meter` third.
- Add `Menu-bar display` before `Meter style`, because both are display choices.
- Add `Launch Codex Meter at Login` after display choices and before the bottom divider.

### First-Run Permission

When the user turns on `Launch Codex Meter at Login`:

- Call `SMAppService.mainApp.register()`.
- Re-read `SMAppService.mainApp.status`.
- If status is `.enabled`, keep the toggle on and show `Enabled`.
- If status is `.requiresApproval`, keep the user's intent visible and show `Approval required in System Settings` with `Open Login Items...`.
- If registration throws, restore the previous toggle state and show the error in the row.
- If status is `.notFound`, show `Unavailable in this build`; this may indicate a packaging/signing problem.

When the user turns it off:

- Call `SMAppService.mainApp.unregister()`.
- If unregister succeeds or the item is already not registered, show the toggle off.
- If unregister fails, keep the actual status visible and show a recovery message.

### Quiet Login Launch

Desired behavior:

- On normal user-driven launch, Codex Meter may keep the current behavior of opening the widget.
- On launch from macOS login items, Codex Meter should create the status item, start auto-refresh, refresh usage, and not call `widgetController.show()`.

Implementation risk:

- `SMAppService.mainApp` is the right no-helper API, but the implementation pass must verify whether the app can reliably distinguish a login-item launch from a normal launch.
- Start by testing `NSApplicationLaunchIsDefaultLaunchKey` from `applicationDidFinishLaunching(_:)` and any observable launch context under a real login-item launch.
- If main-app login launch cannot be distinguished reliably, choose the quieter product fallback: when launch-at-login is enabled, start status-item-only on startup and let left-click open the widget. That is acceptable for a menu-bar utility and avoids surprising the user at login.

## Prototype / Mockup Requirements

Product Design visual generation is pending for this planning thread. The Product Design plugin workflow was used for brief routing and context inspection, but this thread did not expose a Product Design image/mockup tool that can attach the existing repo screenshots as visual references. Per the Product Design workflow, do not pretend reference images were attached and do not create ungrounded generated UI.

Future Product Design pass should use these existing visual references:

- `docs/assets/codex-meter-settings.png` at 1014 x 892.
- `docs/assets/codex-meter-widget-circular.png` at 1230 x 2052.
- Optional supporting references: `docs/assets/codex-meter-widget-bars.png`, `docs/assets/codex-meter-widget-battery.png`, and `docs/assets/codex-meter-screenshot.png`.

Create static mockups first; no coded prototype is required before the implementation PR.

Required mockup frames:

- Settings row layout:
  - Match the existing settings screenshot.
  - Add `Menu-bar display` as a native popup row.
  - Add `Launch Codex Meter at Login` as a native toggle row.
  - Include the `Approval required in System Settings` state and `Open Login Items...` button.
- Status-item mode picker:
  - Show the picker open or focused inside Settings with the five exact display options.
  - Keep it compact enough for the current 420-point logical settings width.
- Menu opened state:
  - Show a native status menu with current usage summary rows, `Refresh Now`, show/hide, reset placement, display mode submenu, settings, and quit.
  - Include a stale or refresh-failed state in one version.
- Small top-bar/status-item visual mock:
  - Show light and dark menu-bar crops with the template gauge icon plus:
    - `87%`
    - `87% · 2h 14m`
    - `P 87 · W 63`
    - `W 63%`
    - icon-only
  - Do not color the entire menu-bar item.
  - Preserve native macOS menu-bar spacing and baseline.

If visual generation becomes available, produce exactly three independent Product Design options:

- Option 1: conservative native settings rows, minimal status menu.
- Option 2: slightly richer menu breakdown with disabled status rows and a compact display-mode submenu.
- Option 3: approval-focused settings state with clearer pending/error handling.

Each option should stay inside the current Codex Meter visual language rather than inventing a new brand system.

## Premium / Packaging Notes

Menu-bar percentage and launch at login should be core/free utility features. They are foundational trust and convenience behaviors for a menu-bar app.

Future premium ideas, only if Codex Meter becomes commercial:

- Advanced display profiles, such as per-workspace display presets.
- Custom threshold labels or custom status-item format strings.
- Multiple named menu-bar layouts.
- Notifications or advanced depletion rules.

Do not make the basic meter, default percentage, icon-only mode, or launch-at-login paid.

Packaging notes:

- Current release context is v0.1.0, ad-hoc signed, not notarized.
- `SMAppService` APIs require a code-signed app. The current local build script ad-hoc signs the `.app`; the future PR must verify whether that is enough for local launch-at-login testing.
- A broader public release should eventually use Developer ID signing and notarization, but this feature PR should not take on the whole packaging lane.

## Technical Plan

### Likely Files

- `Sources/CodexMeter/App/AppDelegate.swift`
  - Update `configureStatusItem()`.
  - Add status-item text updates.
  - Subscribe to store state changes.
  - Keep left/right click behavior intact.
  - Add quiet-start behavior.
- `Sources/CodexMeter/Stores/WidgetStore.swift`
  - Add `statusItemDisplayMode` preference.
  - Expose a display snapshot helper or computed data source.
  - Keep `UserDefaults` persistence consistent with existing settings.
- `Sources/CodexMeter/Views/SettingsView.swift`
  - Add menu-bar display picker.
  - Add launch-at-login toggle and status row.
- `Sources/CodexMeter/Support/StatusItemIcon.swift`
  - Keep template icon behavior.
  - No colorized status item.
- New candidate files:
  - `Sources/CodexMeter/Models/StatusItemDisplayMode.swift`
  - `Sources/CodexMeter/Support/StatusItemDisplaySnapshot.swift`
  - `Sources/CodexMeter/Services/LaunchAtLoginService.swift`

### Status Item Configuration

- Continue using `NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)`.
- Keep `button.image = StatusItemIcon.image()`.
- Use `button.imagePosition = .imageOnly` for icon-only mode.
- Use `button.imagePosition = .imageLeft` or the current SDK's leading equivalent when text is present.
- Set `button.title` or `button.attributedTitle` to the resolved status text.
- Prefer native menu-bar typography. Only use attributed title if monospaced digits are needed to prevent jitter.
- Update `button.toolTip` with full context:
  - lowest window
  - all available percentages
  - last updated/freshness
  - error/recovery when relevant

### State Updates

Subscribe in `AppDelegate` to the minimal state needed:

- `store.$usage`
- `store.$showSparkUsage`
- `store.$isLoading`
- `store.$lastUpdated`
- `store.$errorMessage`
- `store.$recoveryMessage`
- `store.$statusItemDisplayMode`

Centralize formatting so the widget, status item, menu, and tests do not each invent their own percentage rules.

### Preference Persistence

Add `StatusItemDisplayMode: String, CaseIterable, Identifiable`.

Suggested raw values:

- `lowestPercentage`
- `percentageWithReset`
- `primaryWeekly`
- `lowestWindowLabel`
- `iconOnly`

Suggested `UserDefaults` key:

- `statusItemDisplayMode`

Default:

- `.lowestPercentage`

Migration:

- If the key is missing, use `.lowestPercentage`.
- Do not alter existing `meterStyle`; this is a separate menu-bar display preference.

### Launch At Login

Use `SMAppService.mainApp` because the project minimum is macOS 13.

Create a small service wrapper so Settings stays clean:

- `status() -> SMAppService.Status`
- `setEnabled(_ enabled: Bool) async/throws`
- `openSystemSettingsLoginItems()`

Implementation notes from the local macOS SDK headers:

- `SMAppService.mainApp` configures the main app to be launched at login.
- `register()` registers the service subject to user consent.
- `unregister()` prevents future launches at login.
- `status` can be `.notRegistered`, `.enabled`, `.requiresApproval`, or `.notFound`.
- `SMAppService.openSystemSettingsLoginItems()` is available for the approval/recovery path.
- Apps using `SMAppService` must be code signed.

No-helper dependency stance:

- Do not add `Contents/Library/LoginItems`.
- Do not add `~/Library/LaunchAgents`.
- Do not use deprecated `SMLoginItemSetEnabled`.
- Do not keep a helper alive separately from the main app.

### Quiet Startup Sequence

Current launch sequence calls `controller.show()` immediately. Future implementation should split startup into:

1. Create store.
2. Create widget controller but do not automatically show it until launch policy is resolved.
3. Create settings controller.
4. Configure status item.
5. Configure auto refresh.
6. Refresh usage.
7. Show the widget only if launch policy says this was an ordinary foreground launch.

Add a helper such as `shouldShowWidgetOnLaunch(notification:)` and test it manually under:

- direct launch from Finder or `open`
- launch from `./script/build_and_run.sh --verify`
- launch after login item registration and real macOS login
- relaunch after crash/quit if macOS restore behavior is involved

Consider calling `NSApp.disableRelaunchOnLogin()` if AppKit state restoration competes with the intentional `SMAppService` login path.

## Edge Cases

- Auth file missing or invalid: status item shows `ERR` only if no prior snapshot exists; menu shows the recovery text and Refresh Now.
- Backend unavailable after previous success: keep the prior percentage in the menu bar; mark stale/error in tooltip and menu.
- Endpoint payload omits primary or weekly window: omit missing candidates from lowest calculation; use `--` in `Primary and weekly` mode.
- Spark enabled but endpoint returns no real Spark meter: do not let the synthetic Spark `100%` fallback affect the menu-bar lowest calculation.
- Spark disabled: exclude Spark from status-item calculation and menu breakdown.
- Remaining percent below 0 or above 100: rely on clamped `UsageWindow.remainingPercent`.
- Multiple windows tie for lowest percent: earliest reset wins, then shortest reset-after, then Codex before Spark.
- Very long text in a crowded menu bar: allow user to switch to `87%`, `W 63%`, or icon-only; do not auto-truncate into ambiguous output.
- Light/dark mode: template icon remains native; text follows menu-bar system rendering.
- Menu opened while refresh is running: keep menu usable and show `Refreshing...`.
- User denies login item approval: Settings row shows `Approval required in System Settings` and `Open Login Items...`.
- User disables the login item from System Settings: next Settings open or app activation reflects `.requiresApproval` or `.notRegistered`.
- Local ad-hoc build fails `SMAppService` registration because of signing/package location: show a packaging-focused error and document it for release work.
- App launched at login while offline: starts quietly, shows cached/stale or loading/error state, and does not open widget.
- App already running when login item registration is toggled: do not relaunch the app; just update status.

## Acceptance Criteria

- Status item defaults to a template gauge icon plus lowest relevant remaining percentage, such as `87%`.
- Status item supports all five display modes and persists the selected mode across quit/relaunch.
- Left-click toggles the floating widget exactly as before.
- Right-click or Control-click opens the menu exactly as before.
- The menu includes full usage breakdown, freshness/error context, `Refresh Now`, show/hide, reset placement, display mode selection, settings, and quit.
- Loading, stale, error, and no-data states render with the exact text rules in this plan.
- The widget remains the source of full visual detail; the menu bar stays compact.
- Settings includes `Menu-bar display` and `Launch Codex Meter at Login` rows using native controls.
- Turning launch at login on registers `SMAppService.mainApp` and reflects `.enabled` or `.requiresApproval` honestly.
- Turning launch at login off unregisters `SMAppService.mainApp`.
- `Open Login Items...` opens the macOS Login Items settings panel when approval is required.
- On login, Codex Meter starts quietly in the menu bar and does not automatically open the large widget.
- No tokens, auth file contents, endpoint responses, account details, or sensitive local data are logged, displayed, or added to docs.
- No helper app, LaunchAgent, LaunchDaemon, analytics SDK, external account dependency, or paid entitlement gate is introduced.

## Verification Plan

Likely commands:

```bash
swift build
./script/build_and_run.sh --verify
```

Manual verification:

- Confirm status item appears in light mode and dark mode with:
  - `87%`
  - `87% · 2h 14m`
  - `P 87 · W 63`
  - `W 63%`
  - icon-only
- Confirm left-click toggles the widget and right/control-click opens the menu.
- Confirm `Refresh Now` updates the status item without flicker.
- Confirm settings persistence:
  - Change display mode.
  - Quit Codex Meter.
  - Relaunch.
  - Confirm mode persists.
- Confirm launch-at-login:
  - Toggle on.
  - Verify `SMAppService.mainApp.status`.
  - If approval is required, use `Open Login Items...` and approve it.
  - Log out/in or restart.
  - Confirm Codex Meter is running, menu-bar item is visible, and widget is not open.
  - Toggle off and confirm it no longer launches at login.
- Capture proof screenshots:
  - status item light/dark mode
  - opened menu
  - Settings with both new rows
  - approval-required Settings state if applicable
- Review Product Design mockups against `docs/assets/codex-meter-settings.png` and `docs/assets/codex-meter-widget-circular.png` before implementation.

Planning-pass verification:

- This document should be the only created artifact.
- Production Swift source should remain unchanged.

## Open Questions

- Can the future implementation reliably distinguish `SMAppService.mainApp` login launches from ordinary launches, or should Codex Meter adopt status-item-only startup whenever launch at login is enabled?
- Should existing v0.1.0 users be migrated immediately to `Lowest remaining percentage`, or should the first update preserve icon-only until they choose a mode? Product recommendation: use the new default for missing preference keys and keep icon-only only when explicitly selected.
- Should `Primary and weekly` mode ever include Spark abbreviations, or should Spark remain in the menu/widget only? Product recommendation: keep this mode Codex-only and use `Lowest window label` for Spark-aware compact display.
