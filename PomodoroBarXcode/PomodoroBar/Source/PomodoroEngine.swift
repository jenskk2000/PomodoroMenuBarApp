import Foundation
import AppKit
import UserNotifications
import ServiceManagement

struct TaskBucket: Codable, Identifiable {
    let id: UUID
    var name: String
    var seconds: Int

    init(id: UUID = UUID(), name: String, seconds: Int) {
        self.id = id
        self.name = name
        self.seconds = seconds
    }
}

enum TimerPhase: String, Codable {
    case focus
    case shortBreak
    case longBreak

    var label: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }
}

enum ActiveTimerKind {
    case none
    case pomodoro
    case taskTimer
}

struct PersistedState: Codable {
    var focusMinutes: Int
    var shortBreakMinutes: Int
    var longBreakMinutes: Int
    var dailyGoalHours: Double
    var completedFocusSessions: Int
    var totalFocusSeconds: Int
    var taskBuckets: [TaskBucket]
    var dailySecondsByDate: [String: Int]
    var dailyFocusSessionsByDate: [String: Int]
    var activeTaskName: String
    var taskTimerCurrentRunSeconds: Int
    var notificationsEnabled: Bool
    var soundEnabled: Bool

    init(
        focusMinutes: Int,
        shortBreakMinutes: Int,
        longBreakMinutes: Int,
        dailyGoalHours: Double,
        completedFocusSessions: Int,
        totalFocusSeconds: Int,
        taskBuckets: [TaskBucket],
        dailySecondsByDate: [String: Int],
        dailyFocusSessionsByDate: [String: Int],
        activeTaskName: String,
        taskTimerCurrentRunSeconds: Int,
        notificationsEnabled: Bool,
        soundEnabled: Bool
    ) {
        self.focusMinutes = focusMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        self.dailyGoalHours = dailyGoalHours
        self.completedFocusSessions = completedFocusSessions
        self.totalFocusSeconds = totalFocusSeconds
        self.taskBuckets = taskBuckets
        self.dailySecondsByDate = dailySecondsByDate
        self.dailyFocusSessionsByDate = dailyFocusSessionsByDate
        self.activeTaskName = activeTaskName
        self.taskTimerCurrentRunSeconds = taskTimerCurrentRunSeconds
        self.notificationsEnabled = notificationsEnabled
        self.soundEnabled = soundEnabled
    }

    enum CodingKeys: String, CodingKey {
        case focusMinutes
        case shortBreakMinutes
        case longBreakMinutes
        case dailyGoalHours
        case completedFocusSessions
        case totalFocusSeconds
        case taskBuckets
        case dailySecondsByDate
        case dailyFocusSessionsByDate
        case activeTaskName
        case taskTimerCurrentRunSeconds
        case notificationsEnabled
        case soundEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        focusMinutes = try container.decode(Int.self, forKey: .focusMinutes)
        shortBreakMinutes = try container.decode(Int.self, forKey: .shortBreakMinutes)
        longBreakMinutes = try container.decode(Int.self, forKey: .longBreakMinutes)
        dailyGoalHours = try container.decode(Double.self, forKey: .dailyGoalHours)
        completedFocusSessions = try container.decode(Int.self, forKey: .completedFocusSessions)
        totalFocusSeconds = try container.decode(Int.self, forKey: .totalFocusSeconds)
        taskBuckets = try container.decode([TaskBucket].self, forKey: .taskBuckets)
        dailySecondsByDate = try container.decode([String: Int].self, forKey: .dailySecondsByDate)
        dailyFocusSessionsByDate = try container.decodeIfPresent([String: Int].self, forKey: .dailyFocusSessionsByDate) ?? [:]
        activeTaskName = try container.decode(String.self, forKey: .activeTaskName)
        taskTimerCurrentRunSeconds = try container.decodeIfPresent(Int.self, forKey: .taskTimerCurrentRunSeconds) ?? 0
        notificationsEnabled = try container.decode(Bool.self, forKey: .notificationsEnabled)
        soundEnabled = try container.decode(Bool.self, forKey: .soundEnabled)
    }
}

@MainActor
final class PomodoroEngine: ObservableObject {
    @Published var focusMinutes = 25
    @Published var shortBreakMinutes = 5
    @Published var longBreakMinutes = 15
    @Published var dailyGoalHours = 4.0

    @Published var phase: TimerPhase = .focus
    @Published var remainingSeconds: Int = 25 * 60
    @Published var isRunning = false
    @Published var isTaskTimerRunning = false
    @Published var activeTimerKind: ActiveTimerKind = .none
    @Published var taskTimerCurrentRunSeconds = 0
    @Published var completedFocusSessions = 0
    @Published var totalFocusSeconds = 0
    @Published var activeTaskName = "Study"
    @Published var taskBuckets: [TaskBucket] = []
    @Published var notificationsEnabled = false
    @Published var soundEnabled = true
    @Published var launchAtLoginEnabled = false
    @Published var launchAtLoginError: String?

    var onTick: (() -> Void)?

    private let defaults = UserDefaults.standard
    private let stateKey = "pomodoro.state.v1"
    private let isoDateFormatter: DateFormatter
    private var ticker: Timer?
    private var autosaveTickCounter = 0
    private let defaultTaskName = "Study"
    private let maxTaskNameLength = 48
    private let maxStoredTasks = 200
    private let maxStoredDayEntries = 365
    private let maxTaskSeconds = 60 * 60 * 24 * 365
    private let maxCurrentRunSeconds = 60 * 60 * 24 * 31
    private let maxDailyFocusSeconds = 60 * 60 * 24
    private let maxDailyFocusSessions = 200
    private let maxCompletedFocusSessions = 200_000
    private let maxTotalFocusSeconds = 60 * 60 * 24 * 365 * 20
    private let focusRange = 10...180
    private let shortBreakRange = 3...45
    private let longBreakRange = 10...90
    private let dailyGoalRange = 0.5...16.0

    private var dailySecondsByDate: [String: Int] = [:]
    private var dailyFocusSessionsByDate: [String: Int] = [:]

    private var currentPhaseDuration: Int {
        switch phase {
        case .focus: return focusMinutes * 60
        case .shortBreak: return shortBreakMinutes * 60
        case .longBreak: return longBreakMinutes * 60
        }
    }

    init() {
        isoDateFormatter = DateFormatter()
        isoDateFormatter.calendar = Calendar.current
        isoDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        isoDateFormatter.dateFormat = "yyyy-MM-dd"
        isoDateFormatter.isLenient = false
        restore()
        ensureTaskExists()
        remainingSeconds = min(remainingSeconds, currentPhaseDuration)
        syncLaunchAtLoginState()
    }

    var todayFocusSeconds: Int {
        dailySecondsByDate[todayKey] ?? 0
    }

    var weekFocusSeconds: Int {
        let calendar = Calendar.current
        let now = Date()
        return (0..<7).reduce(0) { acc, offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else {
                return acc
            }
            return acc + (dailySecondsByDate[dateKey(for: day)] ?? 0)
        }
    }

    var currentWeekFocusSessionCount: Int {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }

        var total = 0
        var day = interval.start
        while day < interval.end {
            total += dailyFocusSessionsByDate[dateKey(for: day)] ?? 0
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? interval.end
        }
        return total
    }

    var currentDayFocusSessionCount: Int {
        dailyFocusSessionsByDate[todayKey] ?? 0
    }

    var dailyGoalSeconds: Int {
        Int(dailyGoalHours * 3600)
    }

    var menuBarPomodoroClockText: String {
        formatCountdownClock(remainingSeconds)
    }

    var menuBarTaskClockText: String {
        formatElapsedClock(taskTimerCurrentRunSeconds)
    }

    var taskTimerClockText: String {
        formatElapsedClock(taskTimerCurrentRunSeconds)
    }

    var activeTaskTotalSeconds: Int {
        totalSeconds(for: activeTaskName)
    }

    var topTrackedTasks: [TaskBucket] {
        Array(taskBuckets.prefix(5))
    }

    var phaseProgress: Double {
        let elapsed = max(0, currentPhaseDuration - remainingSeconds)
        guard currentPhaseDuration > 0 else { return 0 }
        return min(1, max(0, Double(elapsed) / Double(currentPhaseDuration)))
    }

    var dayProgress: Double {
        guard dailyGoalSeconds > 0 else { return 0 }
        return min(1, Double(todayFocusSeconds) / Double(dailyGoalSeconds))
    }

    var weekProgress: Double {
        let weeklyGoal = dailyGoalSeconds * 7
        guard weeklyGoal > 0 else { return 0 }
        return min(1, Double(weekFocusSeconds) / Double(weeklyGoal))
    }

    var sessionSubtitle: String {
        "\(formatCountdownClock(max(0, currentPhaseDuration - remainingSeconds))) elapsed"
    }

    func startPauseToggle() {
        isRunning ? pause() : start()
    }

    func startTask(_ name: String) {
        guard let cleaned = normalizedTaskName(name) else { return }
        updateTaskName(cleaned)
        pause()
        phase = .focus
        remainingSeconds = focusMinutes * 60
        start()
    }

    func start() {
        guard !isRunning else { return }
        if isTaskTimerRunning {
            pauseTaskTimer()
        }
        isRunning = true
        activeTimerKind = .pomodoro
        ensureTickerRunning()
        save()
        onTick?()
    }

    func pause() {
        guard isRunning else { return }
        isRunning = false
        stopTickerIfIdle()
        save()
        onTick?()
    }

    func resetPhase() {
        pause()
        remainingSeconds = currentPhaseDuration
        activeTimerKind = .none
        onTick?()
        save()
    }

    func skipPhase() {
        pause()
        completePhase(advanceOnly: true)
        activeTimerKind = .pomodoro
        onTick?()
        save()
    }

    func endPomodoroSession() {
        pause()
        phase = .focus
        remainingSeconds = focusMinutes * 60
        activeTimerKind = .none
        onTick?()
        save()
    }

    func startTaskTimer(_ name: String) {
        guard let cleaned = normalizedTaskName(name) else { return }

        if isRunning {
            pause()
        }

        if activeTaskName != cleaned {
            activeTaskName = cleaned
            ensureTaskExists()
            taskTimerCurrentRunSeconds = 0
        }

        isTaskTimerRunning = true
        activeTimerKind = .taskTimer
        ensureTickerRunning()
        save()
        onTick?()
    }

    func toggleTaskTimer(with name: String) {
        if isTaskTimerRunning {
            pauseTaskTimer()
        } else {
            let taskName = normalizedTaskName(name) ?? activeTaskName
            startTaskTimer(taskName)
        }
    }

    func pauseTaskTimer() {
        guard isTaskTimerRunning else { return }
        isTaskTimerRunning = false
        stopTickerIfIdle()
        save()
        onTick?()
    }

    func resetTaskTimerSession() {
        endTaskTimerSession()
    }

    func endTaskTimerSession() {
        pauseTaskTimer()
        taskTimerCurrentRunSeconds = 0
        activeTimerKind = .none
        save()
        onTick?()
    }

    func resumeTask(_ name: String) {
        taskTimerCurrentRunSeconds = 0
        startTaskTimer(name)
    }

    func updateTaskName(_ name: String) {
        guard let cleaned = normalizedTaskName(name) else { return }
        activeTaskName = cleaned
        ensureTaskExists()
        save()
    }

    func totalSeconds(for taskName: String) -> Int {
        taskBuckets.first(where: { $0.name == taskName })?.seconds ?? 0
    }

    func deleteTrackedTask(_ bucket: TaskBucket) {
        guard let idx = taskBuckets.firstIndex(where: { $0.id == bucket.id }) else { return }

        let removed = taskBuckets.remove(at: idx)
        let removedActiveTask = removed.name == activeTaskName

        guard removedActiveTask else {
            save()
            onTick?()
            return
        }

        isTaskTimerRunning = false
        taskTimerCurrentRunSeconds = 0
        if activeTimerKind == .taskTimer {
            activeTimerKind = .none
        }

        if let replacementTask = taskBuckets.first {
            activeTaskName = replacementTask.name
        } else {
            activeTaskName = defaultTaskName
            taskBuckets.append(TaskBucket(name: activeTaskName, seconds: 0))
        }

        stopTickerIfIdle()
        save()
        onTick?()
    }

    func formatted(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }

    func phaseDurationDescription() -> String {
        switch phase {
        case .focus:
            return "Focus block: \(focusMinutes)m"
        case .shortBreak:
            return "Short break: \(shortBreakMinutes)m"
        case .longBreak:
            return "Long break: \(longBreakMinutes)m"
        }
    }

    func setDurations(focus: Int, shortBreak: Int, longBreak: Int) {
        focusMinutes = clamp(focus, within: focusRange)
        shortBreakMinutes = clamp(shortBreak, within: shortBreakRange)
        longBreakMinutes = clamp(longBreak, within: longBreakRange)
        if !isRunning {
            remainingSeconds = currentPhaseDuration
        }
        save()
    }

    func setNotificationsEnabled(_ isEnabled: Bool) {
        if isEnabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
                Task { @MainActor in
                    self?.notificationsEnabled = granted
                    self?.save()
                }
            }
        } else {
            notificationsEnabled = false
            save()
        }
    }

    func setSoundEnabled(_ isEnabled: Bool) {
        soundEnabled = isEnabled
        save()
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginEnabled = isEnabled
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Launch at login is only available from a bundled app in /Applications."
            syncLaunchAtLoginState()
        }
    }

    private func ensureTickerRunning() {
        guard ticker == nil else { return }
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        if let ticker {
            RunLoop.current.add(ticker, forMode: .common)
        }
    }

    private func stopTickerIfIdle() {
        guard !isRunning && !isTaskTimerRunning else { return }
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard isRunning || isTaskTimerRunning else { return }

        if isRunning {
            if phase == .focus {
                totalFocusSeconds = min(maxTotalFocusSeconds, totalFocusSeconds + 1)
                let todayFocus = dailySecondsByDate[todayKey, default: 0]
                dailySecondsByDate[todayKey] = min(maxDailyFocusSeconds, todayFocus + 1)
            }

            remainingSeconds -= 1
            if remainingSeconds <= 0 {
                completePhase(advanceOnly: false)
            }
        }

        if isTaskTimerRunning {
            taskTimerCurrentRunSeconds = min(maxCurrentRunSeconds, taskTimerCurrentRunSeconds + 1)
            updateCurrentTask(seconds: 1)
        }

        autosaveTickCounter += 1
        if autosaveTickCounter >= 10 {
            autosaveTickCounter = 0
            save()
        }

        onTick?()
    }

    private func completePhase(advanceOnly: Bool) {
        if phase == .focus && !advanceOnly {
            completedFocusSessions = min(maxCompletedFocusSessions, completedFocusSessions + 1)
            let todaySessions = dailyFocusSessionsByDate[todayKey, default: 0]
            dailyFocusSessionsByDate[todayKey] = min(maxDailyFocusSessions, todaySessions + 1)
        }

        if phase == .focus {
            let shouldLongBreak = completedFocusSessions > 0 && completedFocusSessions % 4 == 0
            phase = shouldLongBreak ? .longBreak : .shortBreak
        } else {
            phase = .focus
        }

        remainingSeconds = currentPhaseDuration

        if !advanceOnly && soundEnabled {
            NSSound(named: NSSound.Name("Submarine"))?.play()
        }
        if !advanceOnly && notificationsEnabled {
            sendPhaseNotification()
        }
    }

    private func updateCurrentTask(seconds: Int) {
        guard seconds > 0 else { return }
        guard let idx = taskBuckets.firstIndex(where: { $0.name == activeTaskName }) else {
            taskBuckets.append(TaskBucket(name: activeTaskName, seconds: min(maxTaskSeconds, seconds)))
            taskBuckets.sort { $0.seconds > $1.seconds }
            enforceTaskBucketLimit()
            return
        }

        taskBuckets[idx].seconds = min(maxTaskSeconds, taskBuckets[idx].seconds + seconds)
        taskBuckets.sort { $0.seconds > $1.seconds }
    }

    private func ensureTaskExists() {
        activeTaskName = normalizedTaskName(activeTaskName) ?? defaultTaskName
        if !taskBuckets.contains(where: { $0.name == activeTaskName }) {
            taskBuckets.append(TaskBucket(name: activeTaskName, seconds: 0))
        }
        enforceTaskBucketLimit()
    }

    private var todayKey: String {
        dateKey(for: Date())
    }

    private func dateKey(for date: Date) -> String {
        isoDateFormatter.string(from: date)
    }

    private func formatCountdownClock(_ seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        let h = safeSeconds / 3600
        let m = (safeSeconds % 3600) / 60
        let s = safeSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func formatElapsedClock(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func save() {
        let sanitizedBuckets = sanitizeTaskBuckets(taskBuckets, preferredTask: activeTaskName)
        taskBuckets = sanitizedBuckets
        activeTaskName = normalizedTaskName(activeTaskName) ?? sanitizedBuckets.first?.name ?? defaultTaskName
        dailySecondsByDate = sanitizeDailyMap(dailySecondsByDate, maxValue: maxDailyFocusSeconds)
        dailyFocusSessionsByDate = sanitizeDailyMap(dailyFocusSessionsByDate, maxValue: maxDailyFocusSessions)
        taskTimerCurrentRunSeconds = clamp(taskTimerCurrentRunSeconds, min: 0, max: maxCurrentRunSeconds)

        let state = PersistedState(
            focusMinutes: focusMinutes,
            shortBreakMinutes: shortBreakMinutes,
            longBreakMinutes: longBreakMinutes,
            dailyGoalHours: dailyGoalHours,
            completedFocusSessions: completedFocusSessions,
            totalFocusSeconds: totalFocusSeconds,
            taskBuckets: taskBuckets,
            dailySecondsByDate: dailySecondsByDate,
            dailyFocusSessionsByDate: dailyFocusSessionsByDate,
            activeTaskName: activeTaskName,
            taskTimerCurrentRunSeconds: taskTimerCurrentRunSeconds,
            notificationsEnabled: notificationsEnabled,
            soundEnabled: soundEnabled
        )
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: stateKey)
        }
    }

    private func restore() {
        guard
            let data = defaults.data(forKey: stateKey),
            let saved = try? JSONDecoder().decode(PersistedState.self, from: data)
        else {
            phase = .focus
            remainingSeconds = 25 * 60
            return
        }

        focusMinutes = clamp(saved.focusMinutes, within: focusRange)
        shortBreakMinutes = clamp(saved.shortBreakMinutes, within: shortBreakRange)
        longBreakMinutes = clamp(saved.longBreakMinutes, within: longBreakRange)
        dailyGoalHours = clamp(saved.dailyGoalHours, within: dailyGoalRange)
        completedFocusSessions = clamp(saved.completedFocusSessions, min: 0, max: maxCompletedFocusSessions)
        totalFocusSeconds = clamp(saved.totalFocusSeconds, min: 0, max: maxTotalFocusSeconds)
        let preferredTask = normalizedTaskName(saved.activeTaskName) ?? defaultTaskName
        taskBuckets = sanitizeTaskBuckets(saved.taskBuckets, preferredTask: preferredTask)
        dailySecondsByDate = sanitizeDailyMap(saved.dailySecondsByDate, maxValue: maxDailyFocusSeconds)
        dailyFocusSessionsByDate = sanitizeDailyMap(saved.dailyFocusSessionsByDate, maxValue: maxDailyFocusSessions)
        activeTaskName = taskBuckets.first(where: { $0.name == preferredTask })?.name
            ?? taskBuckets.first?.name
            ?? defaultTaskName
        taskTimerCurrentRunSeconds = clamp(saved.taskTimerCurrentRunSeconds, min: 0, max: maxCurrentRunSeconds)
        notificationsEnabled = saved.notificationsEnabled
        soundEnabled = saved.soundEnabled

        // Avoid inaccurate elapsed time after relaunch.
        phase = .focus
        remainingSeconds = focusMinutes * 60
        isRunning = false
        isTaskTimerRunning = false
        activeTimerKind = .none
    }

    private func syncLaunchAtLoginState() {
        let status = SMAppService.mainApp.status
        launchAtLoginEnabled = status == .enabled
    }

    private func sendPhaseNotification() {
        let content = UNMutableNotificationContent()
        content.title = "PomodoroBar"
        content.body = "\(phase.label) started"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func clamp(_ value: Int, within range: ClosedRange<Int>) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }

    private func clamp(_ value: Double, within range: ClosedRange<Double>) -> Double {
        min(range.upperBound, max(range.lowerBound, value))
    }

    private func clamp(_ value: Int, min: Int, max: Int) -> Int {
        Swift.min(max, Swift.max(min, value))
    }

    private func normalizedTaskName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let collapsed = trimmed
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(maxTaskNameLength))
    }

    private func sanitizeTaskBuckets(_ buckets: [TaskBucket], preferredTask: String?) -> [TaskBucket] {
        var merged: [String: Int] = [:]
        var firstIdForName: [String: UUID] = [:]

        for bucket in buckets {
            guard let cleanName = normalizedTaskName(bucket.name) else { continue }
            let cleanSeconds = clamp(bucket.seconds, min: 0, max: maxTaskSeconds)
            merged[cleanName] = clamp((merged[cleanName] ?? 0) + cleanSeconds, min: 0, max: maxTaskSeconds)
            if firstIdForName[cleanName] == nil {
                firstIdForName[cleanName] = bucket.id
            }
        }

        if merged.isEmpty, let preferredTask, let cleanPreferredTask = normalizedTaskName(preferredTask) {
            merged[cleanPreferredTask] = 0
            firstIdForName[cleanPreferredTask] = UUID()
        }

        var sanitized = merged.map { name, seconds in
            TaskBucket(
                id: firstIdForName[name] ?? UUID(),
                name: name,
                seconds: seconds
            )
        }
        sanitized.sort {
            if $0.seconds == $1.seconds {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.seconds > $1.seconds
        }
        if sanitized.count > maxStoredTasks {
            sanitized = Array(sanitized.prefix(maxStoredTasks))
        }
        return sanitized
    }

    private func sanitizeDailyMap(_ map: [String: Int], maxValue: Int) -> [String: Int] {
        var sanitized: [String: Int] = [:]
        for (key, value) in map {
            guard isoDateFormatter.date(from: key) != nil else { continue }
            let cleanValue = clamp(value, min: 0, max: maxValue)
            guard cleanValue > 0 else { continue }
            sanitized[key] = cleanValue
        }

        let sortedKeys = sanitized.keys.sorted(by: >)
        if sortedKeys.count > maxStoredDayEntries {
            for key in sortedKeys.dropFirst(maxStoredDayEntries) {
                sanitized.removeValue(forKey: key)
            }
        }
        return sanitized
    }

    private func enforceTaskBucketLimit() {
        if taskBuckets.count > maxStoredTasks {
            taskBuckets = Array(taskBuckets.prefix(maxStoredTasks))
        }
    }
}
