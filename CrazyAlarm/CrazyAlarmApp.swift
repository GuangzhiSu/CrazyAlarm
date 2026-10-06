import SwiftUI

@main
struct CrazyAlarmApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AlarmHomeView(store: store)
                .preferredColorScheme(.dark)
                .tint(Theme.cyan)
                .task { store.observe(); store.becameActive() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { store.becameActive() } }
        }
    }
}
