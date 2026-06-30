# Release Guide

This guide describes the current release path for Codex Meter.

## Local Verification

Run:

```bash
swift build
./script/build_and_run.sh --verify
```

Then manually verify:

- menu-bar icon appears
- left-click opens the quick peek popover
- right-click opens the menu
- quick peek Refresh Now, Show/Hide Codex Meter, and Settings actions work
- Refresh Now works
- Reset Position and Size returns the widget to the top-right default frame
- Settings opens
- meter style picker changes the widget between Circular, Bars, and Battery
- Reset Bank shows granted and expiration dates without scrolling

## Package The App

The release helper builds a signed `.app` bundle and wraps it in a drag-to-Applications `.dmg`.

Create the release DMG:

```bash
./script/package_dmg.sh
```

The output is:

```text
dist/CodexMeter-<version>.dmg
dist/CodexMeter-<version>.dmg.sha256
```

For a new version before the tag exists locally, pass it explicitly:

```bash
VERSION=0.2.0 ./script/package_dmg.sh
```

By default, the app is ad-hoc signed for local testing. For public distribution, run the script with a Developer ID Application certificate:

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./script/package_dmg.sh
```

The older ZIP path is still useful for quick local handoff:

Create the release ZIP:

```bash
/usr/bin/ditto -c -k --sequesterRsrc --keepParent dist/CodexMeter.app CodexMeter.app.zip
```

## Signing And Notarization

The current development build is ad-hoc signed. For public distribution:

1. Sign with a Developer ID Application certificate.
2. Notarize with Apple.
3. Staple the notarization ticket.
4. Verify Gatekeeper behavior on a clean Mac user account.

Suggested future automation:

- GitHub Actions build on tag
- Developer ID signing secret
- notarization
- release asset upload

## GitHub Release Checklist

- Update `CHANGELOG.md`.
- Attach `CodexMeter-<version>.dmg`.
- Attach `CodexMeter-<version>.dmg.sha256`.
- Optionally attach `CodexMeter.app.zip` as a fallback.
- Attach the demo video from `outputs/codex-meter-demo.mp4`.
- Include the security/privacy disclaimer.
- Link to `PRIVACY.md` and `SECURITY.md`.
- Mention that undocumented endpoints may change.

## Versioning

Use simple semver:

- Patch: docs, small UI polish, compatibility fix
- Minor: new settings, new meter styles, release workflow
- Major: endpoint/auth architecture change or breaking macOS version change
