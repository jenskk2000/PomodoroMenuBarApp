# PomodoroMenuBarApp

Native macOS menu bar app for focused Pomodoro sessions plus project time tracking.

## For students: download and use (no coding)

1. Open the [Releases page](https://github.com/jenskk2000/PomodoroMenuBarApp/releases).
2. Download the latest file named `PomodoroBar.app.zip` (or similar).
3. Double-click the zip file to unpack the app.
4. Drag `PomodoroBar.app` into your `Applications` folder.
5. Open `Applications`, then open `PomodoroBar`.
6. If macOS blocks it the first time: right-click the app, click `Open`, then click `Open` again.
7. Look at the top-right menu bar for the timer icon and click it to use the app.

## What this app does

- Pomodoro countdown timer
- Project timer (count up) for tracking real work time
- Weekly Pomodoro session count
- Local notifications and optional sounds
- Launch at login option

## Common problems

- "App is damaged/incomplete":
  Re-download from the Releases page. Do not use "Download Source Code" for running the app.
- "Apple could not verify this app is free from malware" (the popup with `Move to Bin`):
  1. Click `OK` (do not move to bin).
  2. Open `System Settings` -> `Privacy & Security` (`Anonymitet og sikkerhed`).
  3. Scroll down and click `Open Anyway` (`Aabn alligevel`) for `PomodoroBar.app`.
  4. Confirm by clicking `Open`.
- No icon in menu bar:
  Close and reopen the app from `Applications`.
- Launch at login does not work:
  Make sure the app is inside `Applications` first.

## For developers

### Swift Package

```bash
cd PomodoroBar
swift run
```

### Xcode app

Open `PomodoroBarXcode/PomodoroBar.xcodeproj`, then run the `PomodoroBar` scheme.

## Security and release docs

- `SECURITY.md`
- `CONTRIBUTING.md`
- `RELEASE_CHECKLIST.md`
- `LICENSE`
