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
    #if DEBUG
    @State private var showWebVersion = ProcessInfo.processInfo.environment["SHOW_WEB"] != nil   // screenshot helper
    #else
    @State private var showWebVersion = false
    #endif
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if showWebVersion {
                    WebFallbackView(retryNative: {
                        showWebVersion = false
                        Task { await store.refresh() }
                    })
                } else {
                    NavigationStack {
                        HomeView(openLocations: { showLocations = true }, openWebVersion: { showWebVersion = true })
                    }
                }
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
