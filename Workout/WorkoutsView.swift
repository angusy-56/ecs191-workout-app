import SwiftUI

struct WorkoutsView: View {
    @EnvironmentObject var store: Store
    @State private var editing: WorkoutTemplate?
    @State private var active: ActiveWorkout?
    @State private var choosing = false
    @State private var pendingTemplate: WorkoutTemplate?
    @State private var showCardio = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        StreakBar()
                        if store.templates.isEmpty {
                            empty
                        } else {
                            ForEach(store.templates) { t in row(t) }
                        }
                        cardioCard
                    }
                    .padding(Theme.spacing)
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { choosing = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New workout")
                }
            }
            .sheet(isPresented: $choosing, onDismiss: {
                // Open the editor only after the chooser has fully closed.
                if let t = pendingTemplate { editing = t; pendingTemplate = nil }
            }) {
                NewWorkoutSheet { template in
                    pendingTemplate = template
                    choosing = false
                }
            }
            .sheet(item: $editing) { t in
                WorkoutEditorView(template: t, isNew: !store.templates.contains(where: { $0.id == t.id }))
            }
            .fullScreenCover(item: $active) { w in
                ActiveWorkoutView(workout: w)
            }
            .fullScreenCover(isPresented: $showCardio) {
                CardioView()
            }
            .onChange(of: store.startRequested) { _, requested in
                if requested { quickStart() }
            }
            .onAppear { if store.startRequested { quickStart() } }
        }
    }

    private func quickStart() {
        store.startRequested = false
        let id = store.startRequestID
        store.startRequestID = nil
        guard active == nil, editing == nil, let t = store.quickStartTemplate(id: id) else { return }
        active = ActiveWorkout(template: t, store: store)
    }

    private var empty: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("No workouts yet").font(Theme.headline())
                Text("Start from a routine like Push or Pull, or build your own.")
                    .font(Theme.body()).foregroundStyle(Theme.secondary)
                Button("New Workout") { choosing = true }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var cardioCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cardio").font(Theme.headline())
                Text("Running, walking, cycling, stairs.")
                    .font(Theme.caption()).foregroundStyle(Theme.secondary)
                Button("Start cardio") { showCardio = true }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func row(_ t: WorkoutTemplate) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(t.name).font(Theme.headline())
                    Spacer()
                    Menu {
                        Button("Edit") { editing = t }
                        Button("Delete", role: .destructive) {
                            store.templates.removeAll { $0.id == t.id }
                        }
                    } label: {
                        Image(systemName: "ellipsis").padding(8)
                    }
                }
                Text(t.exercises.isEmpty ? "No exercises"
                     : t.exercises.map(\.name).joined(separator: " · "))
                    .font(Theme.caption())
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(2)
                Button("Start") {
                    active = ActiveWorkout(template: t, store: store)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(t.exercises.isEmpty)
                .opacity(t.exercises.isEmpty ? 0.3 : 1)
            }
        }
    }
}

/// Choose a blank workout or a starter routine to customise.
struct NewWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (WorkoutTemplate) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { onPick(WorkoutTemplate()) } label: {
                        Label("Blank workout", systemImage: "plus")
                    }
                }
                Section("Starter routines") {
                    ForEach(StarterRoutines.all) { r in
                        Button {
                            // A fresh copy with new ids, so saving never alters the starter.
                            var copy = r
                            copy.id = UUID()
                            copy.exercises = r.exercises.map {
                                PlannedExercise(name: $0.name, sets: $0.sets)
                            }
                            onPick(copy)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(r.name).font(Theme.headline())
                                Text("\(r.exercises.count) exercises")
                                    .font(Theme.caption()).foregroundStyle(Theme.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
