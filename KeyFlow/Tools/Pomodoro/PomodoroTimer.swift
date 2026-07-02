import AppKit
import Foundation
import UserNotifications

enum PomodoroPhase: Equatable {
    case focus
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .focus:
            "Focus"
        case .shortBreak:
            "Short Break"
        case .longBreak:
            "Long Break"
        }
    }

    var notificationTitle: String {
        switch self {
        case .focus:
            "Focus Complete"
        case .shortBreak:
            "Break Complete"
        case .longBreak:
            "Long Break Complete"
        }
    }
}

enum PomodoroTimerMode: Equatable {
    case idle
    case running
    case paused
}

struct PomodoroConfiguration: Equatable {
    var focusDuration: Int
    var shortBreakDuration: Int
    var longBreakDuration: Int
    var focusSessionsBeforeLongBreak: Int

    static let `default` = PomodoroConfiguration(
        focusDuration: 25 * 60,
        shortBreakDuration: 5 * 60,
        longBreakDuration: 15 * 60,
        focusSessionsBeforeLongBreak: 4
    )
}

@MainActor
final class PomodoroTimer: ObservableObject {
    static let shared = PomodoroTimer()

    @Published private(set) var mode: PomodoroTimerMode = .idle
    @Published private(set) var phase: PomodoroPhase?
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var durationSeconds: Int
    @Published private(set) var completedFocusCount = 0

    private let configuration: PomodoroConfiguration
    private var timer: Timer?
    private var endDate: Date?
    private var focusSessionsInCycle = 0

    init(configuration: PomodoroConfiguration = .default) {
        self.configuration = configuration
        remainingSeconds = configuration.focusDuration
        durationSeconds = configuration.focusDuration
    }

    var isActive: Bool {
        mode != .idle
    }

    var phaseTitle: String {
        phase?.title ?? "Pomodoro"
    }

    var formattedRemaining: String {
        Self.format(seconds: remainingSeconds)
    }

    var progressFraction: Double {
        guard durationSeconds > 0 else {
            return 0
        }

        let elapsedSeconds = max(durationSeconds - remainingSeconds, 0)
        return min(max(Double(elapsedSeconds) / Double(durationSeconds), 0), 1)
    }

    var primaryActionTitle: String {
        switch mode {
        case .idle:
            "Start"
        case .running:
            "Pause"
        case .paused:
            "Resume"
        }
    }

    var primaryActionSystemImage: String {
        switch mode {
        case .idle, .paused:
            "play.fill"
        case .running:
            "pause.fill"
        }
    }

    var statusItemTitle: String? {
        isActive ? "\(statusItemPhaseToken) \(formattedRemaining)" : nil
    }

    var statusItemSystemImage: String {
        switch mode {
        case .paused:
            "pause.circle"
        case .idle:
            "timer"
        case .running:
            phase == .focus ? "timer" : "cup.and.saucer.fill"
        }
    }

    var statusItemAccessibilityDescription: String {
        "\(phaseTitle) \(formattedRemaining)"
    }

    private var statusItemPhaseToken: String {
        switch phase {
        case .focus:
            "F"
        case .shortBreak:
            "B"
        case .longBreak:
            "L"
        case nil:
            "P"
        }
    }

    func togglePrimaryAction() {
        switch mode {
        case .idle:
            startFocus()
        case .running:
            pause()
        case .paused:
            resume()
        }
    }

    func startFocus() {
        begin(.focus)
    }

    func pause() {
        guard mode == .running else {
            return
        }

        tick()
        timer?.invalidate()
        timer = nil
        endDate = nil
        mode = .paused
    }

    func resume() {
        guard mode == .paused else {
            return
        }

        mode = .running
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        startTicker()
    }

    func skip() {
        completeCurrentPhase(shouldNotify: false)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        focusSessionsInCycle = 0
        phase = nil
        mode = .idle
        durationSeconds = configuration.focusDuration
        remainingSeconds = configuration.focusDuration
    }

    private func begin(_ phase: PomodoroPhase) {
        let duration = duration(for: phase)

        timer?.invalidate()
        timer = nil

        self.phase = phase
        durationSeconds = duration
        remainingSeconds = duration
        mode = .running
        endDate = Date().addingTimeInterval(TimeInterval(duration))
        startTicker()
    }

    private func startTicker() {
        timer?.invalidate()
        let scheduledTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(scheduledTimer, forMode: .common)
        timer = scheduledTimer
    }

    private func tick() {
        guard mode == .running, let endDate else {
            return
        }

        remainingSeconds = max(Int(ceil(endDate.timeIntervalSinceNow)), 0)

        if remainingSeconds <= 0 {
            completeCurrentPhase(shouldNotify: true)
        }
    }

    private func completeCurrentPhase(shouldNotify: Bool) {
        guard let phase else {
            stop()
            return
        }

        timer?.invalidate()
        timer = nil
        endDate = nil

        switch phase {
        case .focus:
            completedFocusCount += 1
            focusSessionsInCycle += 1

            let nextPhase: PomodoroPhase
            if focusSessionsInCycle >= configuration.focusSessionsBeforeLongBreak {
                focusSessionsInCycle = 0
                nextPhase = .longBreak
            } else {
                nextPhase = .shortBreak
            }

            if shouldNotify {
                PomodoroNotificationService.deliver(
                    title: phase.notificationTitle,
                    body: "\(Self.minutes(for: duration(for: nextPhase))) min break"
                )
            }

            begin(nextPhase)
        case .shortBreak, .longBreak:
            if shouldNotify {
                PomodoroNotificationService.deliver(
                    title: phase.notificationTitle,
                    body: "Ready for the next focus session"
                )
            }

            self.phase = nil
            mode = .idle
            durationSeconds = configuration.focusDuration
            remainingSeconds = configuration.focusDuration
        }
    }

    private func duration(for phase: PomodoroPhase) -> Int {
        switch phase {
        case .focus:
            configuration.focusDuration
        case .shortBreak:
            configuration.shortBreakDuration
        case .longBreak:
            configuration.longBreakDuration
        }
    }

    private static func minutes(for seconds: Int) -> Int {
        max(seconds / 60, 1)
    }

    private static func format(seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let seconds = max(seconds, 0) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

}

@MainActor
private enum PomodoroNotificationService {
    private static let delegate = PomodoroNotificationDelegate()

    static func deliver(title: String, body: String) {
        NSApp.requestUserAttention(.informationalRequest)

        Task {
            let center = UNUserNotificationCenter.current()
            center.delegate = delegate

            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])

                guard granted else {
                    NSSound.beep()
                    return
                }

                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
                try await center.add(request)
            } catch {
                NSSound.beep()
            }
        }
    }
}

private final class PomodoroNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
