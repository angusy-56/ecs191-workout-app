import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                if store.entries.isEmpty {
                    VStack(spacing: 8) {
                        Text("No workouts yet").font(Theme.headline())
                        Text("Finished workouts show up here.").foregroundStyle(Theme.secondary)
                    }
                } else {
                    List {
                        Section {
                            ForEach(store.entries) { entry in
                                NavigationLink(value: entry) { row(entry) }
                            }
                            .onDelete { offsets in
                                let entries = store.entries
                                for i in offsets {
                                    switch entries[i] {
                                    case .strength(let w): store.history.removeAll { $0.id == w.id }
                                    case .cardio(let c): store.cardio.removeAll { $0.id == c.id }
                                    }
                                }
                            }
                        } header: {
                            Text("\(store.entries.count) sessions · \(thisWeek) this week")
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: HistoryEntry.self) { entry in
                switch entry {
                case .strength(let w): HistoryDetailView(workout: w)
                case .cardio(let c): CardioDetailView(session: c)
                }
            }
        }
    }

    private var thisWeek: Int {
        let start = Streak.weekDays(containing: Date()).first ?? Date()
        return store.entries.filter { $0.date >= start }.count
    }

    @ViewBuilder
    private func row(_ entry: HistoryEntry) -> some View {
        switch entry {
        case .strength(let w):
            rowLayout(title: w.name, date: w.date,
                      detail: "\(TimeFormat.short(w.duration)) · \(w.setCount) \(w.setCount == 1 ? "set" : "sets") · \(formatWeight(w.volume)) \(w.units.weightLabel)")
        case .cardio(let c):
            rowLayout(title: c.activity.rawValue, date: c.date, detail: cardioDetail(c))
        }
    }

    private func cardioDetail(_ c: CardioSession) -> String {
        var parts = [TimeFormat.short(c.duration)]
        if let d = c.distance { parts.append(String(format: "%.1f %@", d, c.units == .metric ? "km" : "mi")) }
        if let k = c.calories { parts.append("~\(k) kcal") }
        return parts.joined(separator: " · ")
    }

    private func rowLayout(title: String, date: Date, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(Theme.headline())
                Spacer()
                Text(date, format: .dateTime.month(.abbreviated).day())
                    .font(Theme.caption()).foregroundStyle(Theme.secondary)
            }
            Text(detail).font(Theme.caption()).foregroundStyle(Theme.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct HistoryDetailView: View {
    let workout: CompletedWorkout

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Card {
                        HStack {
                            stat(TimeFormat.short(workout.duration), "Time")
                            Spacer()
                            stat("\(workout.setCount)", "Sets")
                            Spacer()
                            stat("\(formatWeight(workout.volume))", "Volume (\(workout.units.weightLabel))")
                            Spacer()
                            stat(workout.calories.map { "~\($0)" } ?? "—", "kcal")
                        }
                    }
                    ForEach(workout.exercises) { ex in
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(ex.name).font(Theme.headline())
                                ForEach(Array(ex.sets.enumerated()), id: \.element.id) { i, s in
                                    Text("\(i + 1)   \(formatWeight(s.weight)) \(workout.units.weightLabel) × \(s.reps)")
                                        .font(Theme.body())
                                }
                            }
                        }
                    }
                }
                .padding(Theme.spacing)
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(Theme.headline())
            Text(label).font(Theme.caption()).foregroundStyle(Theme.secondary)
        }
    }
}

struct CardioDetailView: View {
    let session: CardioSession

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        row("Time", TimeFormat.short(session.duration))
                        if let d = session.distance {
                            row("Distance", String(format: "%.2f %@", d, session.units == .metric ? "km" : "mi"))
                        }
                        if let r = readout(session) { row(r.0, r.1) }
                        if let i = session.incline { row("Incline", String(format: "%.1f%%", i)) }
                        if let e = session.effort { row("Effort", e.rawValue) }
                        row("Est. calories", session.calories.map { "~\($0) kcal" } ?? "—")
                    }
                }
                .padding(Theme.spacing)
            }
        }
        .navigationTitle(session.activity.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(Theme.body()).foregroundStyle(Theme.secondary)
            Spacer()
            Text(value).font(Theme.headline())
        }
    }
}
