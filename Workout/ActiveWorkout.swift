import UIKit

/// State of a workout currently being performed: sets, total timer, rest timer.
final class ActiveWorkout: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    let startedAt = Date()
    @Published var exercises: [LoggedExercise]
    @Published var now = Date()
    @Published private(set) var restEndsAt: Date?
    /// True for a few seconds after a rest timer runs out while the app is open.
    @Published private(set) var restFinished = false
    let restSeconds: Int

    private var timer: Timer?

    init(template: WorkoutTemplate, store: Store) {
        name = template.name
        restSeconds = store.profile.restSeconds
        exercises = template.exercises.map { planned in
            let previous = store.lastSets(for: planned.name) ?? []
            let sets = (0..<max(planned.sets, 1)).map { i -> LoggedSet in
                let p = i < previous.count ? previous[i] : previous.last
                return LoggedSet(weight: p?.weight ?? 0, reps: p?.reps ?? 10)
            }
            return LoggedExercise(name: planned.name, sets: sets)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    deinit {
        timer?.invalidate()
        RestNotifications.shared.cancel()
    }

    var elapsed: TimeInterval { now.timeIntervalSince(startedAt) }
    var restRemaining: Int? {
        guard let end = restEndsAt else { return nil }
        let r = Int(end.timeIntervalSince(now).rounded(.up))
        return r > 0 ? r : nil
    }

    private func tick() {
        now = Date()
        if let end = restEndsAt, end <= now {
            restEndsAt = nil
            RestNotifications.shared.cancel()
            // Only flash the alert if the rest ended just now (not while backgrounded).
            if now.timeIntervalSince(end) < 3 { showRestFinished() }
        }
    }

    func toggle(_ exerciseID: UUID, _ setID: UUID) {
        guard let e = exercises.firstIndex(where: { $0.id == exerciseID }),
              let s = exercises[e].sets.firstIndex(where: { $0.id == setID }) else { return }
        exercises[e].sets[s].done.toggle()
        if exercises[e].sets[s].done { startRest(restSeconds) } else { skipRest() }
    }

    /// Sets a value on one set and copies it to the not-yet-completed sets below it.
    func update(_ exerciseID: UUID, _ setID: UUID, weight: Double? = nil, reps: Int? = nil) {
        guard let e = exercises.firstIndex(where: { $0.id == exerciseID }),
              let s = exercises[e].sets.firstIndex(where: { $0.id == setID }) else { return }
        for i in s..<exercises[e].sets.count where i == s || !exercises[e].sets[i].done {
            if let weight { exercises[e].sets[i].weight = weight }
            if let reps { exercises[e].sets[i].reps = reps }
        }
    }

    func addSet(to exerciseID: UUID) {
        guard let e = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        var new = LoggedSet()
        if let last = exercises[e].sets.last { new.weight = last.weight; new.reps = last.reps }
        exercises[e].sets.append(new)
    }

    func removeSet(_ exerciseID: UUID, _ setID: UUID) {
        guard let e = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[e].sets.removeAll { $0.id == setID }
    }

    func startRest(_ seconds: Int) {
        now = Date()
        restFinished = false
        let end = now.addingTimeInterval(TimeInterval(seconds))
        restEndsAt = end
        RestNotifications.shared.schedule(at: end)
    }

    func adjustRest(_ delta: Int) {
        guard let end = restEndsAt else { return }
        let newEnd = end.addingTimeInterval(TimeInterval(delta))
        if newEnd.timeIntervalSince(Date()) <= 0 { skipRest(); return }
        restEndsAt = newEnd
        RestNotifications.shared.schedule(at: newEnd)
    }

    func skipRest() {
        restEndsAt = nil
        restFinished = false
        RestNotifications.shared.cancel()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        restEndsAt = nil
        RestNotifications.shared.cancel()
    }

    private func showRestFinished() {
        restFinished = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.restFinished = false
        }
    }

    var hasCompletedSets: Bool { exercises.contains { $0.sets.contains(where: \.done) } }

    /// Builds the history record, keeping only completed sets.
    func result(profile: Profile) -> CompletedWorkout {
        let duration = Date().timeIntervalSince(startedAt)
        let logged = exercises.compactMap { ex -> LoggedExercise? in
            let done = ex.sets.filter(\.done)
            return done.isEmpty ? nil : LoggedExercise(name: ex.name, sets: done)
        }
        return CompletedWorkout(name: name, date: startedAt, duration: duration, exercises: logged,
                                calories: Calories.estimate(duration: duration, profile: profile),
                                units: profile.units)
    }
}

enum TimeFormat {
    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(Int(seconds), 0)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }
    static func short(_ seconds: TimeInterval) -> String {
        let m = Int(seconds / 60)
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(max(m, 1)) min"
    }
}

func formatWeight(_ w: Double) -> String {
    w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w)
}
