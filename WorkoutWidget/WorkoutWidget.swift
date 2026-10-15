import SwiftUI
import WidgetKit

struct StartEntry: TimelineEntry {
    let date: Date
    let workouts: [RecentWorkout]
}

struct StartProvider: TimelineProvider {
    func placeholder(in context: Context) -> StartEntry {
        StartEntry(date: Date(), workouts: [
            RecentWorkout(id: UUID(), name: "Push Day", exerciseCount: 5),
            RecentWorkout(id: UUID(), name: "Pull Day", exerciseCount: 5),
            RecentWorkout(id: UUID(), name: "Leg Day", exerciseCount: 4),
        ])
    }
    func getSnapshot(in context: Context, completion: @escaping (StartEntry) -> Void) {
        completion(StartEntry(date: Date(), workouts: SharedWorkouts.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StartEntry>) -> Void) {
        let entry = StartEntry(date: Date(), workouts: SharedWorkouts.load())
        completion(Timeline(entries: [entry], policy: .never))   // the app reloads it when data changes
    }
}

private func startURL(_ w: RecentWorkout?) -> URL {
    guard let w else { return URL(string: "workout://start")! }
    return URL(string: "workout://start?id=\(w.id.uuidString)")!
}

private let widgetBackground = Color(red: 0.98, green: 0.98, blue: 0.97)

struct StartWorkoutView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StartEntry

    var body: some View {
        Group {
            if family == .systemSmall { small } else { medium }
        }
        .foregroundStyle(.black)
        .containerBackground(widgetBackground, for: .widget)
    }

    private var small: some View {
        let first = entry.workouts.first
        return VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "dumbbell.fill").font(.system(size: 26))
            Spacer()
            Text(first?.name ?? "Start workout")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .lineLimit(2)
            Text("Tap to start")
                .font(.system(size: 12, weight: .medium, design: .rounded)).opacity(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(startURL(first))
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start a workout")
                .font(.system(size: 13, weight: .semibold, design: .rounded)).opacity(0.5)
            if entry.workouts.isEmpty {
                Link(destination: startURL(nil)) {
                    row(title: "Start workout", subtitle: "Open the app")
                }
            } else {
                ForEach(entry.workouts) { w in
                    Link(destination: startURL(w)) {
                        row(title: w.name, subtitle: w.exerciseCount == 1 ? "1 exercise" : "\(w.exerciseCount) exercises")
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func row(title: String, subtitle: String) -> some View {
        HStack {
            Text(title).font(.system(size: 16, weight: .bold, design: .rounded)).lineLimit(1)
            Spacer()
            Text(subtitle).font(.system(size: 12, weight: .medium, design: .rounded)).opacity(0.5)
            Image(systemName: "play.fill").font(.system(size: 12))
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 32)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

@main
struct WorkoutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StartWorkout", provider: StartProvider()) { entry in
            StartWorkoutView(entry: entry)
        }
        .configurationDisplayName("Start Workout")
        .description("Jump into one of your last three workouts.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
