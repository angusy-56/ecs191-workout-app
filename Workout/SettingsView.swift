import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Form {
                Section("Units") {
                    Picker("Units", selection: $store.profile.units) {
                        Text("Metric (kg, cm)").tag(Units.metric)
                        Text("Imperial (lb, in)").tag(Units.imperial)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    numberRow("Age", unit: "yrs", value: Binding(
                        get: { store.profile.age.map(Double.init) },
                        set: { store.profile.age = $0.map { Int($0) } }))
                    numberRow("Height", unit: store.profile.units.heightLabel, value: $store.profile.height)
                    numberRow("Weight", unit: store.profile.units.weightLabel, value: $store.profile.weight)
                } header: {
                    Text("About you")
                } footer: {
                    Text("Used for calorie estimates. Stays on this device.")
                }
                Section {
                    numberRow("Weekly calorie goal", unit: "kcal", value: Binding(
                        get: { Double(store.profile.weeklyCalorieGoal) },
                        set: { store.profile.weeklyCalorieGoal = Int($0 ?? 0) }))
                } header: {
                    Text("Goal")
                } footer: {
                    Text("Calories to burn from Monday to Sunday. Shown as the ring on the You screen.")
                }
                Section("Rest timer") {
                    Stepper("\(store.profile.restSeconds) seconds",
                            value: $store.profile.restSeconds, in: 15...600, step: 15)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
    }

    private func numberRow(_ title: String, unit: String, value: Binding<Double?>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
            Text(unit).foregroundStyle(Theme.secondary).frame(width: 36, alignment: .leading)
        }
    }
}
