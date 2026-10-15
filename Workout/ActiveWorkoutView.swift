import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var workout: ActiveWorkout
    @State private var confirmFinish = false
    @State private var confirmCancel = false
    @State private var summary: CompletedWorkout?

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()
            if let summary {
                SummaryView(workout: summary) { dismiss() }
            } else {
                VStack(spacing: 0) {
                    header
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(workout.exercises) { ex in exerciseCard(ex) }
                        }
                        .padding(Theme.spacing)
                        .padding(.bottom, 90)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                if workout.restRemaining != nil || workout.restFinished { restBar }
            }
        }
        .confirmationDialog("Finish workout?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish & Save") { finish() }
            Button("Keep Going", role: .cancel) {}
        }
        .confirmationDialog("Discard this workout?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { workout.stop(); dismiss() }
            Button("Keep Going", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            Button("Cancel") { confirmCancel = true }
                .foregroundStyle(Theme.secondary)
            Spacer()
            VStack(spacing: 2) {
                Text(workout.name).font(Theme.caption()).foregroundStyle(Theme.secondary)
                Text(TimeFormat.clock(workout.elapsed))
                    .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
            }
            Spacer()
            Button("Finish") {
                if workout.hasCompletedSets { confirmFinish = true } else { confirmCancel = true }
            }
            .font(Theme.headline())
        }
        .padding(.horizontal, Theme.spacing)
        .padding(.vertical, 12)
        .background(Theme.card)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private func exerciseCard(_ ex: LoggedExercise) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(ex.name).font(Theme.headline())
                HStack {
                    Text("SET").frame(width: 36, alignment: .leading)
                    Text(store.profile.units.weightLabel.uppercased()).frame(maxWidth: .infinity)
                    Text("REPS").frame(maxWidth: .infinity)
                    Spacer().frame(width: 44)
                }
                .font(Theme.caption())
                .foregroundStyle(Theme.secondary)
                ForEach(Array(ex.sets.enumerated()), id: \.element.id) { i, set in
                    SetRow(index: i + 1, set: set,
                           onWeight: { workout.update(ex.id, set.id, weight: $0) },
                           onReps: { workout.update(ex.id, set.id, reps: Int($0)) }) {
                        workout.toggle(ex.id, set.id)
                    }
                    .contextMenu {
                        Button("Remove set", role: .destructive) { workout.removeSet(ex.id, set.id) }
                    }
                }
                Button { workout.addSet(to: ex.id) } label: {
                    Label("Add set", systemImage: "plus").font(Theme.caption())
                }
            }
        }
    }

    private var restBar: some View {
        HStack(spacing: 16) {
            if let remaining = workout.restRemaining {
                Text("Rest").font(Theme.caption()).foregroundStyle(.white.opacity(0.7))
                Text(TimeFormat.clock(TimeInterval(remaining)))
                    .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                Spacer()
                Button("−15") { workout.adjustRest(-15) }
                Button("+15") { workout.adjustRest(15) }
                Button("Skip") { workout.skipRest() }
            } else {
                Text("Rest is over — next set!")
                Spacer()
                Button("OK") { workout.skipRest() }
            }
        }
        .font(Theme.headline())
        .foregroundStyle(.white)
        .padding(.horizontal, Theme.spacing)
        .padding(.vertical, 14)
        .background(Theme.text)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .padding(Theme.spacing)
    }

    private func finish() {
        workout.stop()
        let result = workout.result(profile: store.profile)
        store.history.insert(result, at: 0)
        summary = result
    }
}

private struct SetRow: View {
    let index: Int
    let set: LoggedSet
    let onWeight: (Double) -> Void
    let onReps: (Double) -> Void
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index)").font(Theme.headline()).frame(width: 36, alignment: .leading)
            NumberField(value: set.weight, decimal: true, onChange: onWeight)
                .frame(height: 44)
                .background(Theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            NumberField(value: Double(set.reps), decimal: false, onChange: onReps)
                .frame(height: 44)
                .background(Theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Button(action: toggle) {
                Image(systemName: set.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 30))
                    .foregroundStyle(set.done ? Theme.done : Theme.text.opacity(0.25))
            }
            .frame(width: 44)
        }
        .opacity(set.done ? 0.6 : 1)
    }
}

/// Number entry that selects the existing value when tapped, so typing replaces it.
private struct NumberField: UIViewRepresentable {
    let value: Double
    let decimal: Bool
    let onChange: (Double) -> Void

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.textAlignment = .center
        tf.placeholder = "0"
        tf.keyboardType = decimal ? .decimalPad : .numberPad
        tf.textColor = .black
        let base = UIFont.systemFont(ofSize: 18, weight: .semibold)
        tf.font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 18) } ?? base
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        context.coordinator.parent = self
        if !tf.isFirstResponder { tf.text = value == 0 ? "" : formatWeight(value) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate, UIGestureRecognizerDelegate {
        var parent: NumberField
        private weak var window: UIWindow?
        private var outsideTap: UITapGestureRecognizer?

        init(_ parent: NumberField) { self.parent = parent }

        func textFieldDidBeginEditing(_ tf: UITextField) {
            DispatchQueue.main.async { tf.selectAll(nil) }
            // Tapping anywhere that isn't a text field ends editing (hides keyboard and caret).
            if let window = tf.window, outsideTap == nil {
                let tap = UITapGestureRecognizer(target: self, action: #selector(tappedOutside))
                tap.cancelsTouchesInView = false
                tap.delegate = self
                window.addGestureRecognizer(tap)
                self.window = window
                outsideTap = tap
            }
        }

        func textFieldDidEndEditing(_ tf: UITextField) {
            tf.text = parent.value == 0 ? "" : formatWeight(parent.value)
            if let tap = outsideTap { window?.removeGestureRecognizer(tap) }
            outsideTap = nil
        }

        @objc func tappedOutside() { window?.endEditing(true) }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            !(touch.view is UITextField)
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        @objc func changed(_ tf: UITextField) {
            let text = (tf.text ?? "").replacingOccurrences(of: ",", with: ".")
            parent.onChange(Double(text) ?? 0)
        }
    }
}

struct SummaryView: View {
    let workout: CompletedWorkout
    let done: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "checkmark.circle").font(.system(size: 56))
            Text("Workout complete").font(Theme.title())
            HStack(spacing: 32) {
                stat(TimeFormat.short(workout.duration), "Time")
                stat("\(workout.setCount)", "Sets")
                stat(workout.calories.map { "~\($0)" } ?? "—", "kcal")
            }
            if workout.calories == nil {
                Text("Add your age, height and weight in Settings to estimate calories.")
                    .font(Theme.caption()).foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
            }
            Spacer()
            Button("Done", action: done).buttonStyle(PrimaryButtonStyle()).padding(Theme.spacing)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(Theme.headline())
            Text(label).font(Theme.caption()).foregroundStyle(Theme.secondary)
        }
    }
}
