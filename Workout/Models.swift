import Foundation

enum Units: String, Codable, CaseIterable {
    case metric, imperial
    var weightLabel: String { self == .metric ? "kg" : "lb" }
    var heightLabel: String { self == .metric ? "cm" : "in" }
}

/// An exercise in a saved workout (the plan, not the log).
struct PlannedExercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var sets: Int = 3
}

struct WorkoutTemplate: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String = ""
    var exercises: [PlannedExercise] = []
}

struct LoggedSet: Identifiable, Codable, Hashable {
    var id = UUID()
    var weight: Double = 0
    var reps: Int = 10
    var done = false
}

struct LoggedExercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var sets: [LoggedSet]
}

/// A finished workout stored in history.
struct CompletedWorkout: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var date: Date
    var duration: TimeInterval
    var exercises: [LoggedExercise]
    var calories: Int?
    var units: Units

    var volume: Double {
        exercises.flatMap(\.sets).filter(\.done).reduce(0) { $0 + $1.weight * Double($1.reps) }
    }
    var setCount: Int { exercises.flatMap(\.sets).filter(\.done).count }
}

struct Profile: Codable, Equatable {
    var age: Int?
    var height: Double?   // cm or in, depending on units
    var weight: Double?   // kg or lb, depending on units
    var units: Units = .metric
    var restSeconds: Int = 90
    var weeklyCalorieGoal: Int = 3000

    init() {}

    // Older save files lack newer keys, so every field is optional on decode.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        age = try c.decodeIfPresent(Int.self, forKey: .age)
        height = try c.decodeIfPresent(Double.self, forKey: .height)
        weight = try c.decodeIfPresent(Double.self, forKey: .weight)
        units = try c.decodeIfPresent(Units.self, forKey: .units) ?? .metric
        restSeconds = try c.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90
        if let weekly = try c.decodeIfPresent(Int.self, forKey: .weeklyCalorieGoal) {
            weeklyCalorieGoal = weekly
        } else if let legacyDaily = try c.decodeIfPresent(Int.self, forKey: .legacyDailyGoal) {
            weeklyCalorieGoal = legacyDaily * 7       // goal used to be per day
        }
    }

    // `legacyDailyGoal` is only read from older save files and never written.
    private enum CodingKeys: String, CodingKey {
        case age, height, weight, units, restSeconds, weeklyCalorieGoal
        case legacyDailyGoal = "calorieGoal"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(age, forKey: .age)
        try c.encodeIfPresent(height, forKey: .height)
        try c.encodeIfPresent(weight, forKey: .weight)
        try c.encode(units, forKey: .units)
        try c.encode(restSeconds, forKey: .restSeconds)
        try c.encode(weeklyCalorieGoal, forKey: .weeklyCalorieGoal)
    }

    var isComplete: Bool { (age ?? 0) > 0 && (height ?? 0) > 0 && (weight ?? 0) > 0 }
    /// Goal used by the activity wheel (falls back to 3000 if cleared).
    var effectiveWeeklyGoal: Int { weeklyCalorieGoal > 0 ? weeklyCalorieGoal : 3000 }
}

enum Calories {
    /// Rough estimate: resting energy (Mifflin-St Jeor, sex-neutral) scaled by
    /// the MET value of weight training (~5) over the workout duration.
    static func estimate(duration: TimeInterval, profile: Profile) -> Int? {
        guard profile.isComplete, let age = profile.age,
              let height = profile.height, let weight = profile.weight else { return nil }
        let kg = profile.units == .metric ? weight : weight * 0.45359237
        let cm = profile.units == .metric ? height : height * 2.54
        let bmr = 10 * kg + 6.25 * cm - 5 * Double(age) - 78
        let met = 5.0
        let kcal = max(bmr, 0) / 24 * met * (duration / 3600)
        return Int(kcal.rounded())
    }
}

enum MuscleGroup: String, CaseIterable, Identifiable {
    case chest = "Chest", back = "Back", shoulders = "Shoulders", biceps = "Biceps"
    case triceps = "Triceps", legs = "Legs", core = "Core", custom = "Custom"
    var id: String { rawValue }
}

struct LibraryExercise: Identifiable, Hashable {
    let name: String
    let group: MuscleGroup
    let equipment: String
    var id: String { name }
}

enum ExerciseLibrary {
    private static func ex(_ group: MuscleGroup, _ items: [(String, String)]) -> [LibraryExercise] {
        items.map { LibraryExercise(name: $0.0, group: group, equipment: $0.1) }
    }

    static let all: [LibraryExercise] =
        ex(.chest, [
            ("Barbell Bench Press", "Barbell"), ("Barbell Incline Press", "Barbell"),
            ("Dumbbell Bench Press", "Dumbbell"), ("Incline Dumbbell Press", "Dumbbell"),
            ("Machine Chest Press", "Machine"), ("Machine Incline Press", "Machine"),
            ("Dumbbell Fly", "Dumbbell"), ("Cable Fly", "Cable"), ("Push-Up", "Bodyweight"),
        ]) +
        ex(.back, [
            ("Deadlift", "Barbell"), ("Barbell Row", "Barbell"), ("Dumbbell Row", "Dumbbell"),
            ("Pull-Up", "Bodyweight"), ("Chin-Up", "Bodyweight"), ("Lat Pulldown", "Cable"),
            ("Seated Cable Row", "Cable"), ("Machine Row", "Machine"), ("T-Bar Row", "Barbell"),
        ]) +
        ex(.shoulders, [
            ("Overhead Press", "Barbell"), ("Barbell Shoulder Press", "Barbell"),
            ("Dumbbell Shoulder Press", "Dumbbell"), ("Machine Shoulder Press", "Machine"),
            ("Lateral Raise", "Dumbbell"), ("Cable Lateral Raise", "Cable"),
            ("Front Raise", "Dumbbell"), ("Face Pull", "Cable"), ("Rear Delt Fly", "Dumbbell"),
            ("Shrug", "Dumbbell"),
        ]) +
        ex(.biceps, [
            ("Barbell Curl", "Barbell"), ("Dumbbell Curl", "Dumbbell"), ("Hammer Curl", "Dumbbell"),
            ("Preacher Curl", "Machine"), ("Cable Curl", "Cable"),
        ]) +
        ex(.triceps, [
            ("Tricep Pushdown", "Cable"), ("Skull Crusher", "Barbell"),
            ("Overhead Tricep Extension", "Dumbbell"), ("Close-Grip Bench Press", "Barbell"),
            ("Dip", "Bodyweight"),
        ]) +
        ex(.legs, [
            ("Back Squat", "Barbell"), ("Front Squat", "Barbell"), ("Leg Press", "Machine"),
            ("Hack Squat", "Machine"), ("Romanian Deadlift", "Barbell"), ("Lunge", "Dumbbell"),
            ("Bulgarian Split Squat", "Dumbbell"), ("Leg Extension", "Machine"),
            ("Leg Curl", "Machine"), ("Hip Thrust", "Barbell"), ("Calf Raise", "Machine"),
            ("Seated Calf Raise", "Machine"),
        ]) +
        ex(.core, [
            ("Plank", "Bodyweight"), ("Crunch", "Bodyweight"), ("Hanging Leg Raise", "Bodyweight"),
            ("Cable Crunch", "Cable"), ("Russian Twist", "Bodyweight"), ("Ab Wheel Rollout", "Ab wheel"),
        ])

    static var builtIn: [String] { all.map(\.name).sorted() }

    static func info(for name: String) -> LibraryExercise? { all.first { $0.name == name } }
}

/// Ready-made routines. Picking one makes an editable copy; the user saves their own version.
enum StarterRoutines {
    private static func routine(_ name: String, _ items: [(String, Int)]) -> WorkoutTemplate {
        WorkoutTemplate(name: name, exercises: items.map { PlannedExercise(name: $0.0, sets: $0.1) })
    }

    static var all: [WorkoutTemplate] {
        [
            routine("Push", [("Barbell Bench Press", 4), ("Incline Dumbbell Press", 3), ("Overhead Press", 3),
                             ("Lateral Raise", 3), ("Tricep Pushdown", 3), ("Overhead Tricep Extension", 3)]),
            routine("Pull", [("Pull-Up", 3), ("Barbell Row", 4), ("Lat Pulldown", 3), ("Seated Cable Row", 3),
                             ("Face Pull", 3), ("Barbell Curl", 3), ("Hammer Curl", 3)]),
            routine("Legs", [("Back Squat", 4), ("Romanian Deadlift", 3), ("Leg Press", 3),
                             ("Leg Curl", 3), ("Leg Extension", 3), ("Calf Raise", 4)]),
            routine("Upper Body", [("Barbell Bench Press", 3), ("Barbell Row", 3), ("Overhead Press", 3),
                                   ("Lat Pulldown", 3), ("Dumbbell Curl", 3), ("Tricep Pushdown", 3)]),
            routine("Lower Body", [("Back Squat", 4), ("Romanian Deadlift", 3), ("Lunge", 3),
                                   ("Leg Curl", 3), ("Hip Thrust", 3), ("Calf Raise", 4)]),
            routine("Full Body", [("Back Squat", 3), ("Barbell Bench Press", 3), ("Barbell Row", 3),
                                  ("Overhead Press", 3), ("Romanian Deadlift", 3), ("Plank", 3)]),
        ]
    }
}

// MARK: - Cardio

enum CardioEffort: String, Codable, CaseIterable, Identifiable {
    case easy = "Easy", moderate = "Moderate", hard = "Hard", veryHard = "Very Hard"
    var id: String { rawValue }
    var index: Int { CardioEffort.allCases.firstIndex(of: self) ?? 1 }
}

enum CardioActivity: String, Codable, CaseIterable, Identifiable {
    // Raw values of the first five match older save files.
    case running = "Running"
    case walking = "Walking"
    case inclineWalk = "Incline Walk"
    case cycling = "Cycling"
    case stairMaster = "StairMaster"
    case hiking = "Hiking"
    case swimming = "Swimming"
    case rowing = "Rowing"
    case basketball = "Basketball"
    case pickleball = "Pickleball"
    case soccer = "Soccer"
    case tennis = "Tennis"

    var id: String { rawValue }
    /// Distance is only asked for where it is easy to record in km/mi.
    var hasDistance: Bool {
        switch self {
        case .running, .walking, .inclineWalk, .cycling, .hiking: return true
        default: return false
        }
    }
    var hasIncline: Bool { self == .inclineWalk }
    /// Foot activities read best as pace; the rest as speed.
    var showsPace: Bool { self == .running || self == .walking || self == .hiking }

    /// MET values (from the Compendium of Physical Activities, rounded) for
    /// Easy / Moderate / Hard / Very Hard effort.
    var mets: [Double] {
        switch self {
        case .running:     return [8.0, 9.8, 11.5, 14.5]
        case .walking:     return [2.8, 3.5, 4.3, 5.0]
        case .inclineWalk: return [4.5, 6.0, 7.5, 9.0]
        case .cycling:     return [4.0, 6.8, 8.8, 11.0]
        case .stairMaster: return [6.0, 8.8, 10.5, 12.0]
        case .hiking:      return [4.5, 5.3, 6.5, 7.8]
        case .swimming:    return [4.8, 5.8, 8.3, 9.8]
        case .rowing:      return [4.8, 7.0, 8.5, 12.0]
        case .basketball:  return [4.5, 6.5, 8.0, 9.5]
        case .pickleball:  return [3.5, 4.5, 6.0, 7.5]
        case .soccer:      return [5.0, 7.0, 9.0, 10.5]
        case .tennis:      return [4.5, 6.5, 7.8, 9.5]
        }
    }
}

struct CardioSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var activity: CardioActivity
    var date: Date                // when it started
    var duration: TimeInterval
    var distance: Double?         // km or mi, per `units`
    var incline: Double?          // percent
    var effort: CardioEffort?     // nil for sessions saved before effort levels existed
    var calories: Int?
    var units: Units

    var endDate: Date { date.addingTimeInterval(duration) }
    /// Speed in km/h or mph (per `units`).
    var speed: Double? {
        guard let d = distance, d > 0, duration > 0 else { return nil }
        return d / (duration / 3600)
    }
    /// Minutes per km or mi.
    var paceMinutes: Double? {
        guard let d = distance, d > 0, duration > 0 else { return nil }
        return duration / 60 / d
    }
}

extension CompletedWorkout {
    var endDate: Date { date.addingTimeInterval(duration) }
}

extension Calories {
    /// Estimate = MET (by activity and effort) x body weight (kg) x hours.
    /// Needs the user's weight; returns nil without it.
    static func cardio(_ activity: CardioActivity, effort: CardioEffort,
                       duration: TimeInterval, profile: Profile) -> Int? {
        guard let weight = profile.weight, weight > 0, duration > 0 else { return nil }
        let kg = profile.units == .metric ? weight : weight * 0.45359237
        let met = activity.mets[effort.index]
        return Int((met * kg * duration / 3600).rounded())
    }
}

enum HistoryEntry: Identifiable, Hashable {
    case strength(CompletedWorkout)
    case cardio(CardioSession)

    var id: UUID {
        switch self {
        case .strength(let w): return w.id
        case .cardio(let c): return c.id
        }
    }
    var date: Date {
        switch self {
        case .strength(let w): return w.date
        case .cardio(let c): return c.date
        }
    }
}
