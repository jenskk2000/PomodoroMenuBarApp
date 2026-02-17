import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let activeStatusWidth: CGFloat = 98
    private let panelWidth: CGFloat = 356
    private let panelTopGap: CGFloat = 4
    private var panelHeight: CGFloat = 300
    private var statusItem: NSStatusItem!
    private var panel: MenuPanel?
    private var eventMonitor: EventMonitor?
    private let timerEngine = PomodoroEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPanel()
        setupEventMonitor()
        timerEngine.onTick = { [weak self] in
            self?.refreshStatusItem()
        }
        refreshStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = "PomodoroBar"
        }
    }

    private func setupPanel() {
        let hostingController = NSHostingController(
            rootView: MenuContentView(engine: timerEngine) { [weak self] height in
                self?.updatePanelHeight(height)
            }
            .frame(width: panelWidth)
        )
        let panel = MenuPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.contentViewController = hostingController
        self.panel = panel
    }

    private func updatePanelHeight(_ height: CGFloat) {
        let clampedHeight = min(max(280, ceil(height)), 420)
        guard abs(panelHeight - clampedHeight) > 0.5 else { return }
        panelHeight = clampedHeight
        panel?.setContentSize(NSSize(width: panelWidth, height: clampedHeight))
        if isPanelShown, let button = statusItem.button {
            positionPanel(relativeTo: button)
        }
    }

    private func setupEventMonitor() {
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.isPanelShown {
                    self.closePanel(event)
                }
            }
        }
    }

    private func refreshStatusItem() {
        guard let button = statusItem.button else { return }
        switch timerEngine.activeTimerKind {
        case .pomodoro:
            statusItem.length = activeStatusWidth
            button.imagePosition = .imageLeading
            button.image = statusImage(symbolName: "timer")
            setMenuBarTitle(" \(timerEngine.menuBarPomodoroClockText)")
        case .taskTimer:
            statusItem.length = activeStatusWidth
            button.imagePosition = .imageLeading
            button.image = statusImage(symbolName: "timer")
            setMenuBarTitle(" \(timerEngine.menuBarTaskClockText)")
        case .none:
            statusItem.length = NSStatusItem.squareLength
            button.imagePosition = .imageOnly
            button.image = statusImage(symbolName: "timer")
            setMenuBarTitle("")
        }
    }

    private func statusImage(symbolName: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let candidates = [symbolName, "timer.circle", "clock", "stopwatch"]
        guard let image = candidates.compactMap({
            NSImage(systemSymbolName: $0, accessibilityDescription: "PomodoroBar")?.withSymbolConfiguration(config)
        }).first else { return nil }
        image.isTemplate = true
        return image
    }

    private func setMenuBarTitle(_ text: String) {
        guard let button = statusItem.button else { return }
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        button.attributedTitle = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if isPanelShown {
            closePanel(sender)
        } else {
            showPanel(sender)
        }
    }

    private var isPanelShown: Bool {
        panel?.isVisible == true
    }

    private func showPanel(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        guard let panel else { return }
        positionPanel(relativeTo: button)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        eventMonitor?.start()
    }

    private func closePanel(_ sender: AnyObject?) {
        panel?.orderOut(sender)
        eventMonitor?.stop()
    }

    private func positionPanel(relativeTo button: NSStatusBarButton) {
        guard let panel else { return }
        let width = panelWidth
        let height = panelHeight
        let fallbackScreenFrame = NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: width, height: height)

        guard let statusWindow = button.window else {
            let origin = NSPoint(
                x: round(fallbackScreenFrame.midX - width / 2),
                y: round(fallbackScreenFrame.maxY - height - panelTopGap)
            )
            panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: false)
            return
        }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = statusWindow.convertToScreen(buttonFrameInWindow)
        let screenFrame = statusWindow.screen?.visibleFrame ?? fallbackScreenFrame
        let horizontalInset: CGFloat = 8
        var originX = buttonFrameOnScreen.midX - width / 2
        originX = max(screenFrame.minX + horizontalInset, min(originX, screenFrame.maxX - width - horizontalInset))
        let originY = buttonFrameOnScreen.minY - height - panelTopGap
        let frame = NSRect(
            x: round(originX),
            y: round(originY),
            width: width,
            height: height
        )
        panel.setFrame(frame, display: false)
    }
}

private final class MenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
