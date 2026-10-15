import SwiftUI

@main
struct WorkoutApp: App {
    @StateObject private var store = Store()

    init() { RestNotifications.shared.configure() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.text)
        }
    }
}
