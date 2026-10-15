import Foundation
import WidgetKit

/// All saved data. Persisted as a single JSON file in the app's Documents folder.
final class Store: ObservableObject {
    @Published var templates: [WorkoutTemplate] = [] { didSet { save() } }
    @Published var customExercises: [String] = [] { didSet { save() } }
    @Published var history: [CompletedWorkout] = [] { didSet { save() } }
    @Published var cardio: [CardioSession] = [] { didSet { save() } }
    @Published var profile = Profile() { didSet { save() } }

    private struct Snapshot: Codable {
        var templates: [WorkoutTemplate]
        var customExercises: [String]
        var history: [CompletedWorkout]
        var cardio: [CardioSession]?     // optional so older save files still load
        var profile: Profile
    }

    /// Set when the widget (or a link) asks the app to start a workout right away.
    @Published var startRequested = false
    /// Which routine to start (nil = most recent one).
    var startRequestID: UUID?

    private let url: URL

    init(filename: String = "workout-data.json") {
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        load()
    }

    var allExercises: [String] {
        Array(Set(ExerciseLibrary.builtIn + customExercises)).sorted()
    }

    func addCustomExercise(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              !allExercises.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
        else { return }
        customExercises.append(trimmed)
    }

    /// The routine to start from the widget: the most recently completed one, else the first.
    func quickStartTemplate(id: UUID?) -> WorkoutTemplate? {
        if let id, let t = templates.first(where: { $0.id == id && !$0.exercises.isEmpty }) { return t }
        return quickStartTemplate
    }

    /// The last 3 distinct routines that were logged (falling back to saved routines).
    private var recentWorkouts: [RecentWorkout] {
        var seen = Set<UUID>()
        var result: [RecentWorkout] = []
        for w in history.sorted(by: { $0.date > $1.date }) {
            guard let t = templates.first(where: { $0.name == w.name && !$0.exercises.isEmpty }),
                  seen.insert(t.id).inserted else { continue }
            result.append(RecentWorkout(id: t.id, name: t.name, exerciseCount: t.exercises.count))
            if result.count == 3 { return result }
        }
        for t in templates where !t.exercises.isEmpty && !seen.contains(t.id) && result.count < 3 {
            result.append(RecentWorkout(id: t.id, name: t.name, exerciseCount: t.exercises.count))
        }
        return result
    }

    private func publishToWidget() {
        SharedWorkouts.save(recentWorkouts)
        WidgetCenter.shared.reloadAllTimelines()
    }

    var quickStartTemplate: WorkoutTemplate? {
        for w in history.sorted(by: { $0.date > $1.date }) {
            if let t = templates.first(where: { $0.name == w.name && !$0.exercises.isEmpty }) { return t }
        }
        return templates.first { !$0.exercises.isEmpty }
    }

    /// Every strength workout and cardio session, newest first.
    var entries: [HistoryEntry] {
        (history.map(HistoryEntry.strength) + cardio.map(HistoryEntry.cardio)).sorted { $0.date > $1.date }
    }

    /// When each saved session was completed (used by the weekly streak).
    var completionDates: [Date] {
        history.map(\.endDate) + cardio.map(\.endDate)
    }

    /// Calories from sessions completed in [start, end). Sessions are de-duplicated by id.
    func calories(from start: Date, to end: Date) -> Int {
        var seen = Set<UUID>()
        var total = 0
        for w in history where w.endDate >= start && w.endDate < end && seen.insert(w.id).inserted {
            total += w.calories ?? 0
        }
        for c in cardio where c.endDate >= start && c.endDate < end && seen.insert(c.id).inserted {
            total += c.calories ?? 0
        }
        return total
    }

    /// Calories burned on a given calendar day.
    func calories(on day: Date) -> Int {
        let cal = Streak.calendar
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return calories(from: start, to: end)
    }

    /// Calories burned in the Monday–Sunday week containing `date`.
    func caloriesInWeek(containing date: Date) -> Int {
        let cal = Streak.calendar
        guard let first = Streak.weekDays(containing: date).first,
              let end = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: first)) else { return 0 }
        return calories(from: cal.startOfDay(for: first), to: end)
    }

    func upsert(_ template: WorkoutTemplate) {
        if let i = templates.firstIndex(where: { $0.id == template.id }) {
            templates[i] = template
        } else {
            templates.append(template)
        }
    }

    /// Most recent logged sets for an exercise, used to prefill a new session.
    func lastSets(for exercise: String) -> [LoggedSet]? {
        for workout in history.sorted(by: { $0.date > $1.date }) {
            if let ex = workout.exercises.first(where: { $0.name == exercise }) {
                let done = ex.sets.filter(\.done)
                if !done.isEmpty { return done }
            }
        }
        return nil
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        templates = snap.templates
        customExercises = snap.customExercises
        history = snap.history
        cardio = snap.cardio ?? []
        profile = snap.profile
    }

    private func save() {
        let snap = Snapshot(templates: templates, customExercises: customExercises,
                            history: history, cardio: cardio, profile: profile)
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: url, options: .atomic)
        }
        publishToWidget()
    }
}
