# Resilient Last Known Good Mode Planning

## Codex Session Purpose

This planning-only session scopes a future implementation PR for Codex Meter's last-known-good and stale-data resilience. The future PR should let the widget keep showing the last successful normalized usage/reset snapshot when a refresh fails, while making the freshness and failure state unmistakable.

No production Swift behavior is changed by this planning document.

## Product Intent

Codex Meter is a fast-glance macOS menu-bar utility. Its job is to answer, "How much Codex usage and Reset Bank capacity do I have right now?" without adding accounts, analytics, heavy dashboards, or private data exposure.

The current app depends on undocumented ChatGPT backend endpoints. Those endpoints may fail, return auth errors, or change schema. When that happens, replacing useful values with a generic error card makes the app feel less trustworthy than it needs to be. The resilient mode should preserve useful prior values and tell the truth clearly:

> 87% remaining - Data from 8 minutes ago
>
> Current usage response could not be interpreted.

The product should feel calm and honest: still small, still glanceable, but harder to misread.

## Scope

Plan one future PR that adds:

- A normalized in-memory last-good snapshot for usage, reset credits, and capture time.
- Independent request status for usage and reset-credit fetches.
- Stale-data badges and relative timestamps.
- Specific user-facing states for auth, HTTP, decoding, and schema mismatch failures.
- Tolerant decoding around optional/new endpoint fields.
- A privacy-safe Copy Diagnostics action.
- Fixture-based decoder regression tests for expected, missing, extra, malformed, and schema-shifted payloads.
- UI updates in the existing widget/settings visual language.

The planned PR should update code only during the future implementation pass. This planning session creates only this doc.

## Non-Goals

- Do not replace the undocumented endpoints with an official API.
- Do not add an account system, analytics, telemetry, crash reporting, or external tracking.
- Do not persist raw endpoint responses, auth file contents, bearer tokens, cookies, account IDs, or private payload values.
- Do not turn the widget into a dashboard, incident timeline, or developer console.
- Do not hide stale/failure truth behind a premium tier.
- Do not notarize, publish, push, or open a public PR as part of this planning pass.
- Do not introduce production dependencies unless the later implementation explicitly justifies them.

## UX / UI Direction

Keep the existing compact material widget structure shown in `docs/assets/codex-meter-widget-circular.png`: header, Reset Bank card, Usage Remaining card, compact status pill, rounded 8px inner cards, health-colored meters, and the existing footer mood control.

The resilience UI should be a trust layer inside the current cards, not a new dashboard. Prefer small status pills, one-line captions, and focused recovery actions.

### Required UI States

Live:

- Reset Bank and Usage Remaining show current data.
- Top status pill stays `Live` with the existing checkmark style.
- Timestamp reads `Updated 4:10 PM` or equivalent.

Refreshing with prior data:

- Prior values remain visible.
- Status pill changes to `Refreshing` with the existing refresh/hourglass language.
- A small caption may read `Checking for latest data...`.
- Meters and reset-credit rows must not blank, jump to loading placeholders, or show an error card while prior data exists.

Stale:

- Prior values remain visible.
- Status pill changes to `Stale` or `Data stale`.
- Timestamp becomes relative and explicit, such as `Data from 8 minutes ago`.
- A short issue line appears near the affected card: `Latest refresh failed. Showing last known good data.`
- Health colors continue to represent the stale values, but stale status must be visible enough that users do not mistake the numbers for live data.

Auth missing:

- If no prior data exists, show a focused empty/error state: `Codex sign-in not found`.
- Recovery copy: `Sign in to Codex on this Mac, then refresh.`
- If prior data exists, keep the prior data visible and mark status `Auth needed`.

Expired session:

- Treat HTTP 401/403 as an expired or unauthorized session.
- If prior data exists, keep prior data visible with `Session expired`.
- Recovery copy: `Sign in to Codex again, then refresh.`
- Avoid wording that implies the local auth file contents were inspected beyond token availability.

Usage endpoint failed:

- Usage card shows prior usage values if available.
- Usage card status reads `Usage stale`.
- Reset Bank can remain `Live` if the reset-credit endpoint succeeded.
- Detail copy: `Current usage response could not be loaded.`

Reset-credit endpoint failed:

- Reset Bank card shows prior reset count and rows if available.
- Reset Bank status reads `Reset Bank stale`.
- Usage Remaining can remain `Live` if the usage endpoint succeeded.
- Detail copy: `Current reset-credit response could not be loaded.`

Schema mismatch:

- Use this when a response is 2xx but cannot be decoded or fails minimum semantic validation.
- If prior data exists, show it with `Schema changed` or `Data format changed`.
- Detail copy: `Current usage response could not be interpreted.` or `Current reset-credit response could not be interpreted.`
- Include Copy Diagnostics so users can safely report endpoint-shape breakage.

Copy diagnostics success:

- A secondary button in the error/stale detail row copies sanitized diagnostics.
- After copy, show a brief inline confirmation, such as `Diagnostics copied`, without opening a modal.
- Copy success should not obscure the stale/live state.

### Layout Notes

- Add card-level status only where it clarifies split health. The top-level status pill can summarize the worst current state.
- Keep the Reset Bank dates visible near the top as today.
- For the circular meter style, avoid adding large warning banners between meters. Use compact captions under the `Usage remaining` header or near the weekly reset text.
- Settings can add a small `Diagnostics` row only if needed, but the primary Copy Diagnostics action should be reachable from the stale/error state in the widget.
- Use system symbols already in the visual vocabulary: `checkmark.circle.fill`, `arrow.triangle.2.circlepath`, `clock.badge.exclamationmark`, `exclamationmark.triangle.fill`, `doc.on.doc`.
- Accessibility labels should include live/stale state and age, for example: `Codex weekly, 79 percent remaining, stale, data from 8 minutes ago`.

## Prototype / Mockup Requirements

Product Design brief playback:

- Product: Codex Meter, a native macOS menu-bar utility.
- Surface: existing floating SwiftUI widget and small Settings window.
- Visual source: `docs/assets/codex-meter-widget-circular.png` and `docs/assets/codex-meter-settings.png`.
- Goal: show resilient stale-data states with high trust while preserving glanceability.
- Interactivity level for a future prototype: static or lightly interactive state switcher is enough; the final production implementation will be native SwiftUI.

Product Design image/mockup generation is pending in this background planning thread because no Product Design-specific image/mockup tool was exposed. A later visual pass should generate or create mockups from the real screenshot references instead of pretending generated images already exist.

Required mockup frames:

- Frame 1, Live: current circular widget with `Live` pill, normal timestamps, usage and reset data unchanged.
- Frame 2, Refreshing with prior data: same values remain visible, status pill becomes `Refreshing`, subtle spinner/progress treatment in the header refresh button.
- Frame 3, Split stale state: Usage Remaining is stale while Reset Bank is live. Usage card includes `Usage stale` and `Data from 8 minutes ago`; Reset Bank remains `Live`.
- Frame 4, Schema mismatch with diagnostics: prior usage remains visible, detail line says `Current usage response could not be interpreted.`, secondary `Copy Diagnostics` button is visible.
- Frame 5, No prior data/auth missing: no meters are shown; focused card says `Codex sign-in not found` with `Refresh`/recovery action.
- Frame 6, Diagnostics copied: same as Frame 4, but the button or inline status confirms `Diagnostics copied`.

Wireframe descriptions:

- Top summary: current status pill in Reset Bank header can become a global summary pill if both cards share the same status. If states differ, each major card owns its own small pill.
- Reset Bank stale row: keep the large count and two credit rows; add a one-line stale caption above the rows or under the timestamp.
- Usage stale row: keep the circular meter grid; add a compact line under the Usage Remaining heading and before meter groups.
- Diagnostics action: place as a low-emphasis secondary button inside the stale/error detail row. It should not look like the primary Refresh action.
- Settings optional row: if added, place below `Refresh Now` as `Copy last diagnostics` with last status timestamp. Do not expand settings height dramatically.

Visual constraints:

- Match the material backdrop, rounded inner cards, dense spacing, rounded system typography, and health-color meters from the existing screenshots.
- Do not add full-width warning panels unless there is no prior data.
- Do not use red for stale data unless values are invalid or auth is blocked. Use amber/secondary treatment for stale; reserve red for depleted usage or blocking errors.
- Do not introduce marketing copy, feature explanation text, or tutorial language in the widget.

## Premium / Packaging Notes

Resilience, stale indicators, specific error truth, tolerant decoding, and safe diagnostics should remain free/core. They protect trust and safety and are part of the basic promise of a local utility using fragile endpoints.

Future premium or support packaging, if the product ever has one, can be optional and additive:

- Guided issue template generation from sanitized diagnostics.
- Advanced local fixture runner for contributors.
- Release-channel notifications or compatibility checks.
- Priority maintenance/support outside the app.

Premium must not hide:

- Whether the current data is live or stale.
- Auth/session failure truth.
- Endpoint/schema failure truth.
- The safe ability to copy diagnostics needed to report breakage.

Current packaging context: `v0.1.0` exists, local builds are ad-hoc signed and not notarized. Endpoint resilience should land before broader public distribution because it reduces the support risk of an undocumented endpoint changing.

## Technical Plan

### Data Model

Add a normalized snapshot type in the future implementation, likely near `Sources/CodexMeter/Models/UsageSnapshot.swift` or a new `WidgetSnapshot.swift`:

- `WidgetSnapshot`
  - `usage: UsageResponse?`
  - `availableCount: Int?`
  - `credits: [RateLimitResetCredit]`
  - `capturedAt: Date`
  - `usageSource: RequestFreshness`
  - `resetCreditsSource: RequestFreshness`
- `EndpointStatus`
  - `idle`
  - `refreshing(hasPriorData: Bool)`
  - `live(updatedAt: Date)`
  - `stale(lastSuccessAt: Date, failure: RefreshFailure)`
  - `unavailable(failure: RefreshFailure)`
- `RefreshFailure`
  - `missingAuth`
  - `expiredSession(statusCode: Int)`
  - `httpFailure(endpoint: EndpointKind, statusCode: Int)`
  - `networkFailure(endpoint: EndpointKind, reason: String)`
  - `malformedPayload(endpoint: EndpointKind, decoderPath: String?)`
  - `schemaMismatch(endpoint: EndpointKind, recognizedKeys: [String])`
  - `unknown(endpoint: EndpointKind?, reason: String)`
- `EndpointKind`
  - `usage`
  - `resetCredits`

Prefer an in-memory last-good snapshot for the first PR. Persisting endpoint-derived usage/reset values to `UserDefaults` should remain out of scope unless a separate privacy review decides the values are acceptable to store.

### Store Flow

Refactor `WidgetStore.refresh()` so usage and reset-credit requests resolve independently:

1. Read token once.
2. If token read fails, update both endpoint statuses to missing auth/unavailable or stale depending on prior data.
3. Start both endpoint requests.
4. Capture `Result<UsageResponse, RefreshFailure>` and `Result<RateLimitResetResponse, RefreshFailure>` separately.
5. On each success, update the normalized fields for that endpoint and set that endpoint status to live.
6. On each failure, preserve last-good fields for that endpoint and set that endpoint status to stale if prior data exists, otherwise unavailable.
7. Update top-level `lastUpdated` only when at least one endpoint succeeds, or add separate `lastSuccessfulUsageAt` and `lastSuccessfulResetCreditsAt`.
8. Keep `isLoading` as a refresh-in-progress flag, but do not let it erase prior data.

Avoid `try await (usageResponse, creditResponse)` as the single failure boundary because one failed endpoint should not discard the other successful response.

### Client Errors

Wrap client failures in typed, privacy-safe errors:

- Include endpoint kind.
- Include HTTP status code.
- Include response category, not body.
- Include decoder coding path and expected type where available.
- Include recognized top-level JSON keys when decode fails, but not values.

Keep bearer token handling inside `CodexAuthTokenReader`, `UsageClient`, and `RateLimitResetClient`.

### Tolerant Decoding

Keep required fields only where the UI truly cannot function without them.

Usage tolerance:

- Allow missing `plan_type`.
- Allow missing or empty `additional_rate_limits`.
- Allow missing `credits`.
- Allow missing Spark buckets without error.
- Consider optionalizing `UsageRateLimit.allowed` and `limitReached` if they are not displayed.
- Do not fail the whole usage response if an unknown additional meter appears.

Reset-credit tolerance:

- Allow missing `credits` by treating it as an empty array only if `available_count` is present.
- If a single credit row is malformed, consider whether to drop that row and report partial schema warning, or fail the reset-credit endpoint. The first implementation should prefer failing the endpoint if dates/IDs are malformed, because expiration dates are core product data.
- Keep date decoding flexible for ISO8601 with and without fractional seconds.

Semantic validation:

- Clamp percent values for display, but diagnostics should record when values were outside expected 0...100.
- Validate minimum useful usage response: at least one usable Codex window, or a documented empty-state reason.
- Validate reset credits: `available_count` is present and nonnegative.

### Diagnostics Builder

Add a privacy-safe diagnostics builder, likely under `Sources/CodexMeter/Support/DiagnosticsBuilder.swift` or `Sources/CodexMeter/Models/Diagnostics.swift`.

Diagnostics may include:

- App name and version.
- macOS version.
- Timestamp of diagnostic generation.
- Endpoint kind and endpoint path, not auth headers.
- HTTP status code.
- Failure category.
- Decoder error coding path.
- Expected/failed decoded type.
- Recognized top-level JSON keys.
- Current app state summary: has prior usage data, has prior reset-credit data, last-success age bucket.
- Meter style and auto-refresh interval if useful for UI bug reports.

Diagnostics must never include:

- Access tokens, refresh tokens, cookies, auth file contents, or authorization headers.
- Raw JSON payload values.
- Account IDs, user IDs, email addresses, organization IDs, or private plan/account details.
- Local absolute paths other than generic references already documented publicly.
- Full raw endpoint URLs if query strings or sensitive parameters ever appear. Prefer endpoint path constants.

Copy action:

- Use `NSPasteboard.general` from a small AppKit bridge or `PasteboardWriter`.
- Show a transient `Diagnostics copied` state in `WidgetStore`.
- Clear the success state after a short delay or on the next refresh.

### UI Implementation Targets

Likely future files:

- `Sources/CodexMeter/Stores/WidgetStore.swift`: state machine, last-good snapshot, independent statuses.
- `Sources/CodexMeter/Models/UsageSnapshot.swift`: tolerant usage response decoding and/or normalized snapshot.
- `Sources/CodexMeter/Models/RateLimitResetCredit.swift`: reset-credit tolerance and validation.
- `Sources/CodexMeter/Services/UsageClient.swift`: typed endpoint errors and decode diagnostics.
- `Sources/CodexMeter/Services/RateLimitResetClient.swift`: typed endpoint errors and decode diagnostics.
- `Sources/CodexMeter/Views/MeterWidgetView.swift`: stale/live/auth/schema UI states and Copy Diagnostics action.
- `Sources/CodexMeter/Views/SettingsView.swift`: optional diagnostics affordance if needed.

Testing targets may require adding a SwiftPM test target:

- `Tests/CodexMeterTests/UsageDecodingTests.swift`
- `Tests/CodexMeterTests/RateLimitResetDecodingTests.swift`
- `Tests/CodexMeterTests/DiagnosticsBuilderTests.swift`
- `Tests/CodexMeterTests/Fixtures/*.json`

Because the current `Package.swift` only defines an executable target, the implementation PR should add tests deliberately and keep production code testable without exposing auth details.

## Edge Cases

- First launch with no auth file and no prior data.
- First launch with expired token and no prior data.
- Refresh fails after previous live data exists.
- Usage succeeds while reset credits fail.
- Reset credits succeed while usage fails.
- Usage endpoint returns 200 with missing `rate_limit`.
- Usage endpoint returns new meter buckets or renamed Spark bucket.
- Reset-credit endpoint returns available count but empty/missing credits.
- Reset-credit endpoint returns a malformed date.
- HTTP 401/403 should read as session/auth, not generic networking.
- HTTP 429 should read as service/rate failure without implying Codex usage depletion.
- Network offline/DNS failure.
- Decoder errors with nested coding paths.
- Clock changes that make relative stale age negative or absurdly large.
- Auto-refresh fires while manual refresh is already running.
- Widget opens while data is stale and auto-refresh is disabled.
- Copy Diagnostics when no failure exists should copy a small state summary or disable the action.
- Diagnostics copy failure due to pasteboard access should show a small failure message.
- Very narrow/resized widget should not clip stale badges or diagnostics buttons.
- VoiceOver should not read stale values as live values.

## Acceptance Criteria

- When a refresh fails after successful prior data, Codex Meter keeps the prior Reset Bank and/or Usage Remaining values visible.
- The UI clearly says whether displayed data is live, refreshing, stale, auth-blocked, expired, endpoint-failed, or schema-mismatched.
- Usage and reset-credit statuses are independent; one endpoint can be stale while the other remains live.
- Refreshing with prior data does not replace cards with loading placeholders.
- No-prior-data failures still show a focused error state with recovery guidance.
- HTTP 401/403 shows expired/session recovery copy.
- 2xx malformed or schema-shifted payloads show `could not be interpreted` style copy and expose Copy Diagnostics.
- Copy Diagnostics produces sanitized text containing app/platform/status/decoder metadata only.
- Diagnostics contain no bearer tokens, cookies, auth file contents, raw response bodies, account IDs, user IDs, emails, or sensitive local paths.
- Tolerant decoders continue to accept optional/new fields and missing noncritical fields.
- Fixture tests cover successful payloads, missing optional fields, extra fields, HTTP classification, malformed payloads, and schema-shifted payloads.
- `swift build` passes.
- `./script/build_and_run.sh --verify` passes on macOS.
- Manual proof captures live, refreshing-with-prior-data, stale usage-only, stale reset-only, auth missing, expired session, schema mismatch, and copy diagnostics success states.

## Verification Plan

Future implementation verification should include:

```bash
swift build
```

```bash
swift test
```

Run `swift test` only after the future PR adds a test target. If tests are not added, that should be called out as a gap.

```bash
./script/build_and_run.sh --verify
```

Manual error-state proof:

- Use fixture injection, local mock clients, or a debug-only endpoint/client override to force usage success/failure independently from reset-credit success/failure.
- Capture screenshot proof for live, refreshing-with-prior-data, stale usage-only, stale reset-only, auth missing, expired session, schema mismatch, and diagnostics copied.
- Confirm the widget never displays stale values without a stale/status label.
- Confirm Reset Bank dates remain visible.
- Confirm meter health colors still reflect remaining capacity and are not replaced by decorative theme colors.
- Confirm diagnostics text by copying it into a scratch buffer and checking that no token/auth/raw payload/private account data appears.

Prototype/mockup review:

- Review the Product Design frames against the current circular widget screenshot and settings screenshot.
- Confirm the stale UI reads at glance size and does not feel like a dashboard.
- Confirm text fits within the widget at the current minimum width.

Release/package checks:

- Re-run the normal app verification script before any release candidate.
- If this lands before a wider release, include the behavior in release notes as endpoint resilience, not as monitoring or analytics.

## Open Questions

- Should last-good data remain in memory only for v1, or should a later privacy-reviewed version persist sanitized normalized values across app launches?
- What stale age should change copy severity: 5 minutes, 30 minutes, 1 hour, 24 hours?
- Should a successful usage response update `availableCount` from `rate_limit_reset_credits` when the reset-credit endpoint fails, or should Reset Bank count remain tied only to the reset-credit endpoint?
- Should malformed individual reset-credit rows fail the whole reset-credit endpoint, or should valid rows render with a partial-data warning?
- Should diagnostics include recognized nested keys for specific objects, or only top-level keys?
- Is the Copy Diagnostics action enough in the widget, or should Settings also expose `Copy last diagnostics` for cases where the widget is hidden?
- Do we need a debug-only local fixture mode for manual screenshot proof, and if so should it be compile-time only?
