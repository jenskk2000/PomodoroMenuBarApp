import AppKit

@main
@MainActor
struct PomodoroBarMain {
    // Keep a strong reference because NSApplication.delegate is weak.
    private static let appDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = appDelegate
        app.run()
    }
}
