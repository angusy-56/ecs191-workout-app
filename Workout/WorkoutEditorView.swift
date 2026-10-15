import SwiftUI

struct WorkoutEditorView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var template: WorkoutTemplate
    let isNew: Bool
    @State private var picking = false

    private var canSave: Bool {
        !template.name.trimmingCharacters(in: .whitespaces).isEmpty && !template.exercises.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                List {
                    Section {
                        TextField("Workout name", text: $template.name)
                            .font(Theme.headline())
                    }
                    Section("Exercises") {
                        ForEach($template.exercises) { $ex in
                            HStack {
                                Text(ex.name)
                                Spacer()
                                Stepper("\(ex.sets) sets", value: $ex.sets, in: 1...10)
                                    .fixedSize()
                                    .font(Theme.caption())
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { template.exercises.remove(atOffsets: $0) }
                        .onMove { template.exercises.move(fromOffsets: $0, toOffset: $1) }
                        Button { picking = true } label: {
                            Label("Add exercise", systemImage: "plus")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }
            .navigationTitle(isNew ? "New Workout" : "Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        template.name = template.name.trimmingCharacters(in: .whitespaces)
                        store.upsert(template)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $picking) {
                ExercisePicker { name in
                    template.exercises.append(PlannedExercise(name: name))
                }
            }
        }
    }
}

struct ExercisePicker: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let onPick: (String) -> Void
    @State private var query = ""
    @State private var filter: MuscleGroup?

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }

    private func matches(_ name: String) -> Bool {
        trimmed.isEmpty || name.localizedCaseInsensitiveContains(trimmed)
    }

    /// Sections to show: each muscle group's library exercises, then the user's custom ones.
    private var sections: [(MuscleGroup, [(name: String, equipment: String)])] {
        var result: [(MuscleGroup, [(name: String, equipment: String)])] = []
        for group in MuscleGroup.allCases where filter == nil || filter == group {
            let items: [(name: String, equipment: String)]
            if group == .custom {
                items = store.customExercises.sorted().filter(matches).map { ($0, "Custom") }
            } else {
                items = ExerciseLibrary.all.filter { $0.group == group && matches($0.name) }
                    .map { ($0.name, $0.equipment) }
            }
            if !items.isEmpty { result.append((group, items)) }
        }
        return result
    }

    private var canCreate: Bool {
        !trimmed.isEmpty && !store.allExercises.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("All", selected: filter == nil) { filter = nil }
                        ForEach(MuscleGroup.allCases) { g in
                            chip(g.rawValue, selected: filter == g) { filter = g }
                        }
                    }
                    .padding(.horizontal, Theme.spacing)
                    .padding(.vertical, 10)
                }
                List {
                    if canCreate {
                        Button {
                            store.addCustomExercise(trimmed)
                            onPick(trimmed)
                            dismiss()
                        } label: {
                            Label("Create \"\(trimmed)\"", systemImage: "plus.circle")
                        }
                    }
                    ForEach(sections, id: \.0) { group, items in
                        Section(group.rawValue) {
                            ForEach(items, id: \.name) { item in
                                Button {
                                    onPick(item.name)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(item.name)
                                        Spacer()
                                        Text(item.equipment)
                                            .font(Theme.caption()).foregroundStyle(Theme.secondary)
                                    }
                                }
                                .swipeActions {
                                    if group == .custom {
                                        Button("Delete", role: .destructive) {
                                            store.customExercises.removeAll { $0 == item.name }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(Theme.background)
            .searchable(text: $query, prompt: "Search or type a new exercise")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.caption())
                .padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(selected ? Color.white : Theme.text)
                .background(selected ? Theme.text : Theme.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.line))
        }
    }
}
