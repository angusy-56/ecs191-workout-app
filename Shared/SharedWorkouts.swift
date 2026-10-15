import Foundation

/// A routine the widget can start. Written by the app, read by the widget
/// through the shared App Group.
struct RecentWorkout: Codable, Identifiable, Hashable {
    var id: UUID          // the routine's id
    var name: String
    var exerciseCount: Int
}

enum SharedWorkouts {
    static let group = "group.com.angusy.Workout"
    private static let key = "recentWorkouts"

    static func save(_ workouts: [RecentWorkout]) {
        guard let defaults = UserDefaults(suiteName: group),
              let data = try? JSONEncoder().encode(workouts) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> [RecentWorkout] {
        guard let data = UserDefaults(suiteName: group)?.data(forKey: key),
              let list = try? JSONDecoder().decode([RecentWorkout].self, from: data) else { return [] }
        return list
    }
}
