# PomodoroBar

Native macOS menu bar app with two separate workflows:

1. Pomodoro countdown timer
2. Project timer (count up) with resumable logged sessions

## Features

- Compact, single popup window
- Pomodoro controls: start/pause, reset, skip
- Daily Pomodoro session count
- Project timer with tracked project list and delete support
- Local notifications and optional sounds
- Launch-at-login toggle (for proper app bundle installs)

## Security notes

- Local-first app (no network backend for timer features)
- Persisted local state is sanitized and bounded on restore/save
- Release build uses Hardened Runtime in Xcode settings

## Run from Swift Package

```bash
cd PomodoroBar
swift run
```

## Xcode app project

- `PomodoroBarXcode/PomodoroBar.xcodeproj`

Set your Team in Signing, then run/archive.

## Open-source release docs

- `README.md`
- `SECURITY.md`
- `RELEASE_CHECKLIST.md`
