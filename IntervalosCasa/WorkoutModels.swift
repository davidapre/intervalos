import Foundation

enum Exercise: String, CaseIterable, Codable, Identifiable {
    case burpees = "Burpees"
    case pushups = "Flexiones"
    case squats = "Sentadillas"
    case plank = "Plancha"
    case mountainClimbers = "Escaladores"
    case jumpingJacks = "Jumping jacks"

    var id: String { rawValue }

    var imageName: String {
        switch self {
        case .burpees: return "burpees"
        case .pushups: return "pushups"
        case .squats: return "squats"
        case .plank: return "plank"
        case .mountainClimbers: return "mountain-climbers"
        case .jumpingJacks: return "jumping-jacks"
        }
    }
}

struct WorkoutPlan: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var workSeconds: Int
    var restSeconds: Int
    var rounds: Int
    var exercises: [Exercise]
    var workSound: CueSound
    var restSound: CueSound

    var coverExercise: Exercise { exercises.first ?? .burpees }
    var totalDuration: Int {
        rounds * workSeconds + max(0, rounds - 1) * restSeconds
    }

    static let intensive = WorkoutPlan(
        id: UUID(),
        name: "Intensivo",
        workSeconds: 40,
        restSeconds: 20,
        rounds: 10,
        exercises: [.burpees, .pushups, .squats, .mountainClimbers, .jumpingJacks, .plank, .burpees, .pushups, .squats, .mountainClimbers],
        workSound: .double,
        restSound: .low
    )
}

@MainActor
final class WorkoutStore: ObservableObject {
    @Published private(set) var plans: [WorkoutPlan] = []
    private let storageKey = "saved-workouts-v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([WorkoutPlan].self, from: data) {
            plans = decoded
        } else {
            plans = [.intensive]
            persist()
        }
    }

    func save(_ plan: WorkoutPlan) {
        if let index = plans.firstIndex(where: { $0.id == plan.id || $0.name.localizedCaseInsensitiveCompare(plan.name) == .orderedSame }) {
            plans[index] = plan
        } else {
            plans.insert(plan, at: 0)
        }
        persist()
    }

    func delete(_ plan: WorkoutPlan) {
        plans.removeAll { $0.id == plan.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(plans) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
