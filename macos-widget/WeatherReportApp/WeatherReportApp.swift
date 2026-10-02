import SwiftUI

// The widget extension has to ship inside an app. This is that app: it only
// explains how to add the widget.
@main
struct WeatherReportApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 48))
                    .symbolRenderingMode(.multicolor)
                Text("Weather Report").font(.title2.bold())
                Text("Right-click the desktop, choose Edit Widgets, and add Weather Report.\nThen right-click the widget and choose Edit to set your location.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .frame(width: 420)
        }
        .windowResizability(.contentSize)
    }
}
