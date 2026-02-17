# Release Checklist (PomodoroBar)

## 1. Security + quality gate

1. `cd /Users/jenskristensen/Projects/forsjov/PomodoroBar && swift build`
2. `xcodebuild -project /Users/jenskristensen/Projects/forsjov/PomodoroBarXcode/PomodoroBar.xcodeproj -scheme PomodoroBar -configuration Release -derivedDataPath /Users/jenskristensen/Projects/forsjov/PomodoroBarXcode/.DerivedData build`
3. Manual smoke test:
   - Open/close popup
   - Start/pause/reset Pomodoro
   - Start/pause/end project timer
   - Delete a tracked project entry
   - Toggle notifications/sounds/launch-at-login
4. Confirm no crashes from malformed existing local state

## 2. Build + sign

1. In Xcode, set Team and signing for `PomodoroBar` target.
2. Archive a Release build.
3. Export signed `.app`.

## 3. Notarize (recommended before student distribution)

1. Submit:
   - `xcrun notarytool submit /path/to/PomodoroBar.zip --apple-id "<APPLE_ID>" --team-id "<TEAM_ID>" --password "<APP_SPECIFIC_PASSWORD>" --wait`
2. Staple:
   - `xcrun stapler staple /path/to/PomodoroBar.app`
3. Validate:
   - `spctl -a -vv /path/to/PomodoroBar.app`

## 4. Open-source release items

1. `README.md` updated
2. `LICENSE` present
3. `SECURITY.md` present
4. `CONTRIBUTING.md` present
5. Tag release and upload notarized build artifact
