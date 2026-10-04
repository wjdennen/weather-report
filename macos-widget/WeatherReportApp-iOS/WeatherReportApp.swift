import SwiftUI

// Native iPhone app. The widget extension ships inside it; both share the weather, tide and beach logic.
@main
struct WeatherReportApp: App {
    @State private var store = Store()
    #if DEBUG
    @State private var showLocations = ProcessInfo.processInfo.environment["SHOW_LOCATIONS"] != nil   // screenshot helper
    #else
    @State private var showLocations = false
    #endif
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView(openLocations: { showLocations = true })
            }
            .environment(store)
            .tint(.white)
            .preferredColorScheme(.dark)    // the design is a dark, atmospheric gradient with light text
            .sheet(isPresented: $showLocations) {
                LocationsView().environment(store)
            }
            .task { await store.start() }
            .onChange(of: scenePhase) { _, phase in
                // Coming back after a while: refresh stale data.
                if phase == .active, let w = store.weather, Date().timeIntervalSince(w.fetched) > 30 * 60 {
                    Task { await store.refresh() }
                }
            }
        }
    }
}
