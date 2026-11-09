import Foundation
import UIKit

@MainActor
final class IntervalTimer: ObservableObject {
    enum Phase { case setup, countdown, work, rest, finished }

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
    @Published var workSound: CueSound = .double
    @Published var restSound: CueSound = .low
    @Published var countdownValue = 3
    @Published var countdownIsGo = false
    @Published var workoutName = "Mi entrenamiento"
    @Published var roundExercises: [Exercise] = [.burpees, .pushups, .squats, .plank, .mountainClimbers, .jumpingJacks, .burpees, .pushups]
    @Published var loadedPlanID: UUID?

    private var deadline: Date?
    private let audio = AudioCuePlayer()

    var workDuration: Int { workMinutes * 60 + workSeconds }
    var restDuration: Int { restMinutes * 60 + restSeconds }
    var totalWorkoutDuration: Int {
        totalRounds * workDuration + max(0, totalRounds - 1) * restDuration
    }
    var workoutElapsed: TimeInterval {
        switch phase {
        case .setup, .countdown:
            return 0
        case .finished:
            return TimeInterval(totalWorkoutDuration)
        case .work:
            let completedRounds = max(0, currentRound - 1)
            let beforeCurrent = completedRounds * (workDuration + restDuration)
            return TimeInterval(beforeCurrent) + max(0, TimeInterval(workDuration) - remaining)
        case .rest:
            let completedRounds = max(0, currentRound - 1)
            let beforeCurrent = completedRounds * (workDuration + restDuration) + workDuration
            return TimeInterval(beforeCurrent) + max(0, TimeInterval(restDuration) - remaining)
        }
    }
    var workoutRemaining: TimeInterval {
        max(0, TimeInterval(totalWorkoutDuration) - workoutElapsed)
    }
    var isRunning: Bool { phase == .work || phase == .rest }
    var currentExercise: Exercise { exercise(at: currentRound) }
    var nextExercise: Exercise { exercise(at: min(totalRounds, currentRound + 1)) }

    var phaseTitle: String {
        if isPaused { return "PAUSA" }
        switch phase {
        case .countdown: return "PREPÁRATE"
        case .work: return "EJERCICIO"
        case .rest: return "DESCANSO"
        case .finished: return "¡TERMINADO!"
        case .setup: return ""
        }
    }

    var displayValue: String {
        if phase == .countdown { return countdownIsGo ? "¡YA!" : "\(countdownValue)" }
        return format(remaining)
    }

    var nextLabel: String {
        switch phase {
        case .countdown: return countdownIsGo ? "¡Empieza!" : "El entrenamiento está a punto de comenzar"
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
        countdownValue = 3
        countdownIsGo = false
        phase = .countdown
        phaseDuration = 1
        remaining = 1
        deadline = Date().addingTimeInterval(1)
        if soundEnabled { audio.playCountdownTick() }
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func tick(now: Date = Date()) {
        guard let deadline else { return }

        if phase == .countdown {
            remaining = max(0, deadline.timeIntervalSince(now))
            guard remaining <= 0 else { return }
            if countdownIsGo {
                startPhase(.work, seconds: workDuration, playCue: false)
            } else if countdownValue > 1 {
                countdownValue -= 1
                remaining = 1
                self.deadline = now.addingTimeInterval(1)
                if soundEnabled { audio.playCountdownTick() }
            } else {
                countdownIsGo = true
                remaining = 0.7
                self.deadline = now.addingTimeInterval(0.7)
                if soundEnabled { audio.play(workSound) }
            }
            return
        }

        guard isRunning, !isPaused else { return }
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

    func skip() {
        if phase == .countdown {
            startPhase(.work, seconds: workDuration)
        } else if isRunning {
            advance()
        }
    }

    func restart() { start() }

    func edit() {
        deadline = nil
        phase = .setup
        isPaused = false
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func adjustRounds(_ amount: Int) {
        totalRounds = min(99, max(1, totalRounds + amount))
        syncExerciseCount()
    }

    func setExercise(_ exercise: Exercise, for round: Int) {
        syncExerciseCount()
        guard round >= 1, round <= roundExercises.count else { return }
        roundExercises[round - 1] = exercise
    }

    func load(_ plan: WorkoutPlan) {
        loadedPlanID = plan.id
        workoutName = plan.name
        workMinutes = plan.workSeconds / 60
        workSeconds = plan.workSeconds % 60
        restMinutes = plan.restSeconds / 60
        restSeconds = plan.restSeconds % 60
        totalRounds = max(1, plan.rounds)
        roundExercises = plan.exercises
        workSound = plan.workSound
        restSound = plan.restSound
        syncExerciseCount()
    }

    func makePlan() -> WorkoutPlan {
        syncExerciseCount()
        let cleanName = workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        return WorkoutPlan(
            id: loadedPlanID ?? UUID(),
            name: cleanName.isEmpty ? "Mi entrenamiento" : cleanName,
            workSeconds: workDuration,
            restSeconds: restDuration,
            rounds: totalRounds,
            exercises: Array(roundExercises.prefix(totalRounds)),
            workSound: workSound,
            restSound: restSound
        )
    }

    func previewWorkSound() { if soundEnabled { audio.play(workSound) } }
    func previewRestSound() { if soundEnabled { audio.play(restSound) } }

    func format(_ value: Int) -> String { format(TimeInterval(value)) }

    func format(_ value: TimeInterval) -> String {
        let seconds = max(0, Int(ceil(value)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func formatElapsed(_ value: TimeInterval) -> String {
        let seconds = max(0, Int(floor(value)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func advance() {
        if phase == .work {
            if restDuration > 0 && currentRound < totalRounds {
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

    private func startPhase(_ nextPhase: Phase, seconds: Int, playCue: Bool = true) {
        phase = nextPhase
        phaseDuration = TimeInterval(seconds)
        remaining = phaseDuration
        deadline = Date().addingTimeInterval(phaseDuration)
        if soundEnabled && playCue { audio.play(nextPhase == .work ? workSound : restSound) }
    }

    private func finish() {
        phase = .finished
        remaining = 0
        deadline = nil
        isPaused = false
        UIApplication.shared.isIdleTimerDisabled = false
        if soundEnabled { audio.playFinish() }
    }

    private func exercise(at round: Int) -> Exercise {
        guard !roundExercises.isEmpty else { return .burpees }
        return roundExercises[max(0, min(roundExercises.count - 1, round - 1))]
    }

    private func syncExerciseCount() {
        if roundExercises.isEmpty { roundExercises = [.burpees] }
        while roundExercises.count < totalRounds {
            let next = Exercise.allCases[roundExercises.count % Exercise.allCases.count]
            roundExercises.append(next)
        }
        if roundExercises.count > totalRounds {
            roundExercises = Array(roundExercises.prefix(totalRounds))
        }
    }
}
