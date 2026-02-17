# Contributing

Thanks for contributing to PomodoroBar.

## Dev setup

1. Xcode 16+ installed
2. macOS 13+
3. Swift 6 toolchain

## Project structure

- Swift Package source of truth:
  - `PomodoroBar/Sources/PomodoroBar`
- Xcode app mirror:
  - `PomodoroBarXcode/PomodoroBar/Source`

Keep these folders in sync.

## Build checks

Run both before opening a PR:

1. `cd PomodoroBar && swift build`
2. `xcodebuild -project PomodoroBarXcode/PomodoroBar.xcodeproj -scheme PomodoroBar -configuration Release -derivedDataPath PomodoroBarXcode/.DerivedData build`

## Security expectations

- Do not add telemetry or remote APIs without explicit opt-in UX.
- Do not store secrets in source or plist files.
- Keep timer/task persisted state bounded and sanitized.
- Prefer local-only behavior unless a feature clearly requires networking.
