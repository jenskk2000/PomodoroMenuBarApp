import SwiftUI

private enum WorkMode: String, CaseIterable, Identifiable {
    case pomodoro = "Pomodoro"
    case projectTimer = "Project Timer"

    var id: String { rawValue }
}

struct MenuContentView: View {
    @ObservedObject var engine: PomodoroEngine

    var onPreferredHeightChange: (CGFloat) -> Void = { _ in }
    private let shellCornerRadius: CGFloat = 14
    private let shellNotchWidth: CGFloat = 22
    private let shellNotchHeight: CGFloat = 10

    @State private var selectedMode: WorkMode = .pomodoro
    @State private var showingSettings = false
    @State private var localTaskName = ""
    @State private var localFocus = 25
    @State private var localShort = 5
    @State private var localLong = 15
    @State private var pendingDeleteTask: TaskBucket?

    var body: some View {
        VStack(spacing: 10) {
            modeCard

            if selectedMode == .pomodoro {
                pomodoroCard
                durationsCard
            } else {
                projectTimerCard
                trackedTasksCard
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .padding(.top, 10 + shellNotchHeight)
        .frame(width: 356, alignment: .top)
        .background(
            PopupShellShape(
                cornerRadius: shellCornerRadius,
                notchWidth: shellNotchWidth,
                notchHeight: shellNotchHeight
            )
            .fill(.regularMaterial)
        )
        .overlay(
            PopupShellShape(
                cornerRadius: shellCornerRadius,
                notchWidth: shellNotchWidth,
                notchHeight: shellNotchHeight
            )
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(
            PopupShellShape(
                cornerRadius: shellCornerRadius,
                notchWidth: shellNotchWidth,
                notchHeight: shellNotchHeight
            )
        )
        .background(.clear)
        .onAppear {
            localTaskName = engine.activeTaskName
            localFocus = engine.focusMinutes
            localShort = engine.shortBreakMinutes
            localLong = engine.longBreakMinutes
            notifyPreferredHeight()
        }
        .onChange(of: selectedMode) { _ in
            notifyPreferredHeight()
        }
        .onChange(of: engine.topTrackedTasks.count) { _ in
            notifyPreferredHeight()
        }
        .alert(
            "Delete logged session?",
            isPresented: Binding(
                get: { pendingDeleteTask != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeleteTask = nil
                    }
                }
            ),
            presenting: pendingDeleteTask
        ) { bucket in
            Button("Delete", role: .destructive) {
                engine.deleteTrackedTask(bucket)
                pendingDeleteTask = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteTask = nil
            }
        } message: { bucket in
            if bucket.name == engine.activeTaskName {
                Text("This removes \"\(bucket.name)\" and ends its active timer session.")
            } else {
                Text("This removes \"\(bucket.name)\" from logged sessions.")
            }
        }
    }

    private var modeCard: some View {
        moduleCard {
            HStack(spacing: 8) {
                Picker("Mode", selection: $selectedMode) {
                    ForEach(WorkMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    showingSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Settings")
                .popover(isPresented: $showingSettings, arrowEdge: .top) {
                    settingsPopover
                }
            }
        }
    }

    private var pomodoroCard: some View {
        moduleCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(engine.phase.label, systemImage: phaseSymbol)
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(engine.currentDayFocusSessionCount) today")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Text(pomodoroClockText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()

                HStack(spacing: 8) {
                    Button(engine.isRunning ? "Pause" : "Start") {
                        engine.startPauseToggle()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Reset") {
                        engine.resetPhase()
                    }
                    .buttonStyle(.bordered)

                    Button("Skip") {
                        engine.skipPhase()
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.small)
            }
        }
    }

    private var projectTimerCard: some View {
        moduleCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Project Timer", systemImage: "stopwatch")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(engine.isTaskTimerRunning ? "Running" : "Idle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Text(engine.taskTimerClockText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text("Current: \(engine.activeTaskName) · \(engine.formatted(engine.activeTaskTotalSeconds)) total")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button(engine.isTaskTimerRunning ? "Pause Current" : "Continue Current") {
                        if engine.isTaskTimerRunning {
                            engine.pauseTaskTimer()
                        } else {
                            engine.startTaskTimer(engine.activeTaskName)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("End Session") {
                        engine.endTaskTimerSession()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()
                }

                HStack(spacing: 8) {
                    TextField("Task name", text: $localTaskName)
                        .textFieldStyle(.roundedBorder)

                    Button("Start New Project") {
                        engine.startTaskTimer(localTaskName)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(localTaskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var trackedTasksCard: some View {
        moduleCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tracked projects")
                    .font(.system(size: 12, weight: .semibold))

                if engine.topTrackedTasks.isEmpty {
                    Text("No tracked projects yet")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(engine.topTrackedTasks.prefix(3))) { bucket in
                        HStack(spacing: 8) {
                            Text(bucket.name)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .font(.system(size: 11, weight: .medium))

                            Spacer()

                            Text(engine.formatted(bucket.seconds))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)

                            Button("Resume") {
                                localTaskName = bucket.name
                                engine.resumeTask(bucket.name)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)

                            Button(role: .destructive) {
                                pendingDeleteTask = bucket
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.mini)
                            .help("Delete logged session")
                        }
                    }
                }
            }
        }
    }

    private var durationsCard: some View {
        moduleCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Durations")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    DurationEditor(title: "Focus", minutes: $localFocus, range: 10...90, step: 5)
                    DurationEditor(title: "Break", minutes: $localShort, range: 3...30, step: 1)
                    DurationEditor(title: "Long", minutes: $localLong, range: 10...45, step: 5)

                    Button("Apply") {
                        engine.setDurations(focus: localFocus, shortBreak: localShort, longBreak: localLong)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var settingsPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(engine.currentDayFocusSessionCount) today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Toggle("Phase notifications", isOn: Binding(
                get: { engine.notificationsEnabled },
                set: { engine.setNotificationsEnabled($0) }
            ))
            Toggle("Play sounds", isOn: Binding(
                get: { engine.soundEnabled },
                set: { engine.setSoundEnabled($0) }
            ))
            Toggle("Launch at login", isOn: Binding(
                get: { engine.launchAtLoginEnabled },
                set: { engine.setLaunchAtLoginEnabled($0) }
            ))

            if let launchAtLoginError = engine.launchAtLoginError {
                Text(launchAtLoginError)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.link)
                .font(.system(size: 11, weight: .semibold))
            }
        }
        .font(.system(size: 11))
        .padding(12)
        .frame(width: 250)
        .background(.regularMaterial)
    }

    private func moduleCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
    }

    private var preferredPopoverHeight: CGFloat {
        if selectedMode == .pomodoro {
            return 300
        }

        let visibleTaskRows = max(1, min(3, engine.topTrackedTasks.count))
        return 328 + (CGFloat(visibleTaskRows) * 22)
    }

    private func notifyPreferredHeight() {
        onPreferredHeightChange(preferredPopoverHeight)
    }

    private var phaseSymbol: String {
        switch engine.phase {
        case .focus: return "timer"
        case .shortBreak: return "cup.and.saucer"
        case .longBreak: return "moon.stars"
        }
    }

    private var pomodoroClockText: String {
        let minutes = engine.remainingSeconds / 60
        let seconds = engine.remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct DurationEditor: View {
    let title: String
    @Binding var minutes: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(title) \(minutes)m")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Stepper("", value: $minutes, in: range, step: step)
                .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PopupShellShape: Shape {
    let cornerRadius: CGFloat
    let notchWidth: CGFloat
    let notchHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, (rect.height - notchHeight) / 2, rect.width / 2)
        let top = rect.minY + notchHeight
        let left = rect.minX
        let right = rect.maxX
        let bottom = rect.maxY
        let centerX = rect.midX
        let halfNotch = min(notchWidth / 2, rect.width / 4)
        let notchTipRadius = min(max(2.5, notchHeight * 0.34), halfNotch * 0.6)
        let notchTipY = rect.minY + notchTipRadius

        var path = Path()
        path.move(to: CGPoint(x: left + radius, y: top))
        path.addLine(to: CGPoint(x: centerX - halfNotch, y: top))
        path.addCurve(
            to: CGPoint(x: centerX - notchTipRadius, y: notchTipY),
            control1: CGPoint(x: centerX - halfNotch * 0.62, y: top),
            control2: CGPoint(x: centerX - halfNotch * 0.28, y: notchTipY + notchHeight * 0.06)
        )
        path.addArc(
            center: CGPoint(x: centerX, y: notchTipY),
            radius: notchTipRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addCurve(
            to: CGPoint(x: centerX + halfNotch, y: top),
            control1: CGPoint(x: centerX + halfNotch * 0.28, y: notchTipY + notchHeight * 0.06),
            control2: CGPoint(x: centerX + halfNotch * 0.62, y: top)
        )
        path.addLine(to: CGPoint(x: right - radius, y: top))
        path.addQuadCurve(
            to: CGPoint(x: right, y: top + radius),
            control: CGPoint(x: right, y: top)
        )
        path.addLine(to: CGPoint(x: right, y: bottom - radius))
        path.addQuadCurve(
            to: CGPoint(x: right - radius, y: bottom),
            control: CGPoint(x: right, y: bottom)
        )
        path.addLine(to: CGPoint(x: left + radius, y: bottom))
        path.addQuadCurve(
            to: CGPoint(x: left, y: bottom - radius),
            control: CGPoint(x: left, y: bottom)
        )
        path.addLine(to: CGPoint(x: left, y: top + radius))
        path.addQuadCurve(
            to: CGPoint(x: left + radius, y: top),
            control: CGPoint(x: left, y: top)
        )
        path.closeSubpath()
        return path
    }
}
