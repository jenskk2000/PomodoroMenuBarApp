# PomodoroMenuBarApp

Native macOS menu bar app for focused Pomodoro sessions plus project time tracking.

## What it does

- Pomodoro timer (focus, short break, long break)
- Project timer (count up) with resumable tracked projects
- Weekly Pomodoro session count
- Local notifications and optional sounds
- Launch at login toggle
- Everything in one compact popup window

## Privacy and security model

- Local-first: no network calls for timer features
- No accounts or cloud sync
- Timer/task data stays on-device (`UserDefaults`)
- Release target uses hardened runtime

## Run locally

### Swift Package

```bash
cd /Users/jenskristensen/Projects/PomodoroMenuBarApp/PomodoroBar
swift run
```

### Xcode app

Open:

- `/Users/jenskristensen/Projects/PomodoroMenuBarApp/PomodoroBarXcode/PomodoroBar.xcodeproj`

Then run the `PomodoroBar` scheme.

## Open-source + release files

- Security policy: `/Users/jenskristensen/Projects/PomodoroMenuBarApp/SECURITY.md`
- Contributing guide: `/Users/jenskristensen/Projects/PomodoroMenuBarApp/CONTRIBUTING.md`
- Release checklist: `/Users/jenskristensen/Projects/PomodoroMenuBarApp/RELEASE_CHECKLIST.md`
- License: `/Users/jenskristensen/Projects/PomodoroMenuBarApp/LICENSE`
