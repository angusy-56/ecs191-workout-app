import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            WorkoutsView()
                .tabItem { Label("Workouts", systemImage: "dumbbell") }
                .tag(0)
            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
                .tag(1)
            YouView()
                .tabItem { Label("You", systemImage: "person") }
                .tag(2)
        }
        .font(Theme.body())
        .foregroundStyle(Theme.text)
        .onOpenURL { url in
            guard url.scheme == "workout", url.host == "start" else { return }
            tab = 0
            store.startRequestID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "id" }?.value.flatMap(UUID.init)
            store.startRequested = true
        }
    }
}
