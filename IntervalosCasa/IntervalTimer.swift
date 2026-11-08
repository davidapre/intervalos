import Foundation
import UIKit

@MainActor
final class IntervalTimer: ObservableObject {
    enum Phase { case setup, work, rest, finished }

    @Published var phase: Phase = .setup
    @Published var workMinutes = 1
    @Published var workSeconds = 0
    @Published var restMinutes = 0
    @Published var restSeconds = 20
    @Published var totalRounds = 8
    @Published var currentRound = 1
    @Published var remaining: TimeInterval = 60
    @Published var phaseDuration: TimeInterval = 60
    @Published var isPaused = false
    @Published var soundEnabled = true

    private var deadline: Date?
    private let audio = AudioCuePlayer()

    var workDuration: Int { workMinutes * 60 + workSeconds }
    var restDuration: Int { restMinutes * 60 + restSeconds }
    var isRunning: Bool { phase == .work || phase == .rest }

    var phaseTitle: String {
        if isPaused { return "PAUSA" }
        switch phase {
        case .work: return "EJERCICIO"
        case .rest: return "DESCANSO"
        case .finished: return "¡TERMINADO!"
        case .setup: return ""
        }
    }

    var colorName: String { phase == .rest ? "rest" : "work" }

    var nextLabel: String {
        switch phase {
        case .work:
            if restDuration > 0 { return "Después: descanso · \(format(restDuration))" }
            return currentRound < totalRounds ? "Después: siguiente ronda" : "Último intervalo"
        case .rest: return "Después: ejercicio · \(format(workDuration))"
        case .finished: return "\(totalRounds) rondas completadas"
        case .setup: return ""
        }
    }

    func start() {
        guard workDuration > 0 else { return }
        currentRound = 1
        isPaused = false
        startPhase(.work, seconds: workDuration)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func tick(now: Date = Date()) {
        guard isRunning, !isPaused, let deadline else { return }
        remaining = max(0, deadline.timeIntervalSince(now))
        if remaining <= 0 { advance() }
    }

    func togglePause() {
        guard isRunning else { return }
        if isPaused {
            deadline = Date().addingTimeInterval(remaining)
            isPaused = false
        } else {
            if let deadline { remaining = max(0, deadline.timeIntervalSinceNow) }
            self.deadline = nil
            isPaused = true
        }
    }

    func skip() { if isRunning { advance() } }

    func restart() {
        currentRound = 1
        isPaused = false
        startPhase(.work, seconds: workDuration)
    }

    func edit() {
        deadline = nil
        phase = .setup
        isPaused = false
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func adjustRounds(_ amount: Int) {
        totalRounds = min(99, max(1, totalRounds + amount))
    }

    func format(_ value: Int) -> String { format(TimeInterval(value)) }

    func format(_ value: TimeInterval) -> String {
        let seconds = max(0, Int(ceil(value)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func advance() {
        if phase == .work {
            if restDuration > 0 {
                startPhase(.rest, seconds: restDuration)
            } else if currentRound < totalRounds {
                currentRound += 1
                startPhase(.work, seconds: workDuration)
            } else { finish() }
        } else if currentRound < totalRounds {
            currentRound += 1
            startPhase(.work, seconds: workDuration)
        } else { finish() }
    }

    private func startPhase(_ nextPhase: Phase, seconds: Int) {
        phase = nextPhase
        phaseDuration = TimeInterval(seconds)
        remaining = phaseDuration
        deadline = Date().addingTimeInterval(phaseDuration)
        if soundEnabled { audio.play(work: nextPhase == .work) }
    }

    private func finish() {
        phase = .finished
        remaining = 0
        deadline = nil
        isPaused = false
        UIApplication.shared.isIdleTimerDisabled = false
        if soundEnabled { audio.playFinish() }
    }
}
