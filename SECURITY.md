# Security Policy

## Supported versions

Only the latest commit on `main` is supported for security fixes.

## Reporting a vulnerability

Please do not open public issues for security vulnerabilities.

Instead:

1. Email the maintainer with reproduction steps, impact, and affected files.
2. Include your environment (macOS version, app version/commit).
3. Allow time for triage and a patch before public disclosure.

## Current security posture

- Local-first macOS app (no backend required for timer functionality)
- No secrets bundled in source
- No shell execution, eval, or dynamic code execution
- State restore now sanitizes and bounds persisted values
- Task names and stored counters are bounded to avoid malformed-state abuse
- Release build uses Hardened Runtime

## Security hardening release checklist

Before each public release:

1. Build from a clean tree.
2. Run:
   - `cd PomodoroBar && swift build`
   - `xcodebuild -project PomodoroBarXcode/PomodoroBar.xcodeproj -scheme PomodoroBar -configuration Release -derivedDataPath PomodoroBarXcode/.DerivedData build`
3. Verify Hardened Runtime is enabled in Release settings.
4. Verify app still runs with notifications and launch-at-login toggles.
5. Sign and notarize before sharing broadly.
