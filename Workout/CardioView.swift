import SwiftUI

/// Simple cardio logging: pick an activity, then time it live or enter the details afterwards.
struct CardioView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private enum Stage { case setup, running, details, saved }

    @State private var stage = Stage.setup
    @State private var activity = CardioActivity.running
    @State private var effort = CardioEffort.moderate
    @State private var startedAt = Date()
    @State private var minutes = ""
    @State private var distance = ""
    @State private var incline = ""
    @State private var confirmDiscard = false
    @State private var saved: CardioSession?

    private var units: Units { store.profile.units }
    private func number(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private var durationSeconds: TimeInterval { (number(minutes) ?? 0) * 60 }
    private var distanceValue: Double? { activity.hasDistance ? number(distance) : nil }
    private var inclineValue: Double? { activity.hasIncline ? number(incline) : nil }

    private var estimate: CardioSession {
        CardioSession(activity: activity, date: Date().addingTimeInterval(-durationSeconds),
                      duration: durationSeconds, distance: distanceValue, incline: inclineValue,
                      effort: effort,
                      calories: Calories.cardio(activity, effort: effort, duration: durationSeconds,
                                                profile: store.profile),
                      units: units)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch stage {
            case .setup: setup
            case .running: running
            case .details: details
            case .saved: CardioSummary(session: saved ?? estimate) { dismiss() }
            }
        }
        .confirmationDialog("Discard this session?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Going", role: .cancel) {}
        }
    }

    // MARK: Stages

    private var setup: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Button("Cancel") { dismiss() }.foregroundStyle(Theme.secondary)
                Spacer()
            }
            Text("Cardio").font(Theme.title())
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                        ForEach(CardioActivity.allCases) { a in
                            Button { activity = a } label: {
                                HStack {
                                    Text(a.rawValue).font(Theme.body()).lineLimit(1)
                                    Spacer(minLength: 0)
                                    if a == activity { Image(systemName: "checkmark").font(Theme.caption()) }
                                }
                                .foregroundStyle(Theme.text)
                                .padding(.horizontal, 14).padding(.vertical, 16)
                                .background(Theme.card)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                                .overlay(RoundedRectangle(cornerRadius: Theme.radius)
                                    .stroke(a == activity ? Theme.text : Theme.line,
                                            lineWidth: a == activity ? 1.5 : 1))
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Effort").font(Theme.caption()).foregroundStyle(Theme.secondary)
                        effortPicker
                    }
                }
            }
            Button("Start timer") {
                startedAt = Date()
                stage = .running
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("Enter details manually") { stage = .details }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(Theme.spacing)
    }

    /// Easy / Moderate / Hard / Very Hard.
    private var effortPicker: some View {
        HStack(spacing: 8) {
            ForEach(CardioEffort.allCases) { e in
                Button { effort = e } label: {
                    Text(e.rawValue)
                        .font(Theme.caption())
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(e == effort ? Color.white : Theme.text)
                        .background(e == effort ? Theme.text : Theme.card)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.line))
                }
            }
        }
    }

    private var running: some View {
        VStack(spacing: 24) {
            HStack {
                Button("Cancel") { confirmDiscard = true }.foregroundStyle(Theme.secondary)
                Spacer()
            }
            Spacer()
            Text(activity.rawValue).font(Theme.headline()).foregroundStyle(Theme.secondary)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(TimeFormat.clock(context.date.timeIntervalSince(startedAt)))
                    .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
            }
            Spacer()
            Button("Finish") {
                let secs = Date().timeIntervalSince(startedAt)
                minutes = String(max(Int((secs / 60).rounded()), 1))
                stage = .details
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(Theme.spacing)
    }

    private var details: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.secondary)
                    Spacer()
                }
                Text(activity.rawValue).font(Theme.title())

                Card {
                    VStack(spacing: 14) {
                        field("Duration", unit: "min", text: $minutes)
                        if activity.hasDistance {
                            field("Distance", unit: units == .metric ? "km" : "mi", text: $distance)
                        }
                        if activity.hasIncline {
                            field("Incline", unit: "%", text: $incline)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Effort").font(Theme.caption()).foregroundStyle(Theme.secondary)
                    effortPicker
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        if let reading = readout(estimate) {
                            row(reading.0, reading.1)
                        }
                        row("Estimated calories", caloriesText)
                        Text("Estimate based on activity, effort, duration and your weight.")
                            .font(Theme.caption()).foregroundStyle(Theme.secondary)
                    }
                }

                Button("Save") { save() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(durationSeconds <= 0)
                    .opacity(durationSeconds <= 0 ? 0.3 : 1)
            }
            .padding(Theme.spacing)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var caloriesText: String {
        if durationSeconds <= 0 { return "—" }
        return estimate.calories.map { "~\($0) kcal" } ?? "Add your weight in You › Settings"
    }

    // MARK: Pieces

    private func field(_ title: String, unit: String, text: Binding<String>) -> some View {
        HStack {
            Text(title).font(Theme.body())
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(Theme.headline())
                .frame(width: 100)
            Text(unit).font(Theme.caption()).foregroundStyle(Theme.secondary)
                .frame(width: 32, alignment: .leading)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(Theme.body()).foregroundStyle(Theme.secondary)
            Spacer()
            Text(value).font(Theme.headline())
        }
    }

    private func save() {
        guard durationSeconds > 0, stage == .details else { return }
        let session = estimate
        store.cardio.insert(session, at: 0)
        saved = session
        stage = .saved
    }
}

/// Pace or speed text for a cardio session, if it has a distance.
func readout(_ s: CardioSession) -> (String, String)? {
    let u = s.units
    if s.activity.showsPace, let p = s.paceMinutes {
        let total = Int((p * 60).rounded())
        return ("Pace", String(format: "%d:%02d /%@", total / 60, total % 60, u == .metric ? "km" : "mi"))
    }
    if let v = s.speed {
        return ("Speed", String(format: "%.1f %@", v, u == .metric ? "km/h" : "mph"))
    }
    return nil
}

struct CardioSummary: View {
    let session: CardioSession
    let done: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "checkmark.circle").font(.system(size: 56))
            Text("\(session.activity.rawValue) saved").font(Theme.title())
            HStack(spacing: 32) {
                stat(TimeFormat.short(session.duration), "Time")
                if let d = session.distance {
                    stat(String(format: "%.1f", d), session.units == .metric ? "km" : "mi")
                }
                stat(session.calories.map { "~\($0)" } ?? "—", "est. kcal")
            }
            if let e = session.effort {
                Text("\(e.rawValue) effort").font(Theme.caption()).foregroundStyle(Theme.secondary)
            }
            Spacer()
            Button("Done", action: done).buttonStyle(PrimaryButtonStyle())
        }
        .padding(Theme.spacing)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(Theme.headline())
            Text(label).font(Theme.caption()).foregroundStyle(Theme.secondary)
        }
    }
}
