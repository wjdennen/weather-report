import SwiftUI

struct HomeView: View {
    @Environment(Store.self) private var store
    @State private var expandedAlerts: Set<String> = []
    @State private var expandedDays: Set<String> = []
    let openLocations: () -> Void
    let openWebVersion: () -> Void

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            if let w = store.weather {
                ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 14) {
                        if case .failed(let message) = store.phase { notice(message) }
                        if !w.alerts.isEmpty { AlertsView(alerts: w.alerts, tz: w.tz, expanded: $expandedAlerts) }
                        HeroView(w: w)
                        HourlyView(w: w)
                        DetailedForecastView(w: w)
                        ConditionsView(w: w)
                        if let beach = w.beach {
                            SectionTitle("Beach Pick").id("beach")
                            BeachView(advice: beach)
                        }
                        SectionTitle("7-Day Forecast").id("forecast")
                        ForecastView(w: w, expanded: $expandedDays)
                        SectionTitle("Sun").id("sun")
                        SunView(w: w)
                        SectionTitle("Moon").id("moon")
                        MoonView()
                        SectionTitle("Tides").id("tides")
                        TidesView(w: w)
                        credits(w).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    // Pin the content to exactly the screen width so nothing (a long word, a rounding
                    // remainder) can make the page pan sideways; only the hourly strip scrolls horizontally.
                    .containerRelativeFrame(.horizontal)
                    .background(NoHorizontalPan())   // inside the scroll view, so it can find it
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                // SwiftUI cancels a refreshable task when the refresh itself changes on-screen state, which would
                // abort the network calls mid-flight. An unstructured Task isn't cancelled along with it.
                .refreshable { await Task { await store.refresh() }.value }
                #if DEBUG
                // Screenshot helper: SIMCTL_CHILD_SCROLL_TO=<section id> jumps to that section at launch.
                .task {
                    guard let id = ProcessInfo.processInfo.environment["SCROLL_TO"] else { return }
                    try? await Task.sleep(for: .seconds(1))
                    proxy.scrollTo(id, anchor: id == "bottom" ? .bottom : .top)
                }
                #endif
                }
            } else {
                placeholder
            }
        }
        .foregroundStyle(.white)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                // A tappable view rather than a Button: with iOS's "Button Shapes" setting on, a text Button
                // in the toolbar gets underlined.
                HStack(spacing: 8) {
                    Image(systemName: store.selection == .gps ? "location.fill" : "mappin.and.ellipse")
                    // Fixed to the text's natural width (capped), because the iOS 26 toolbar can otherwise
                    // collapse a non-Button item to just its icon.
                    Text(store.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        .frame(maxWidth: 230, alignment: .leading)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .dynamicTypeSize(...DynamicTypeSize.xLarge)   // keep the nav bar from outgrowing its space
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
                .onTapGesture(perform: openLocations)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Change location")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: openLocations) { Image(systemName: "plus") }
                    .accessibilityLabel("Search locations")
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    var background: some View {
        let c = store.weather?.current
        return AtmosphereGradient.make(code: c?.code ?? 3, isDay: c?.isDay ?? true)
            .animation(.easeInOut(duration: 0.8), value: c?.code)
    }

    @ViewBuilder var placeholder: some View {
        switch store.phase {
        case .failed(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).accessibilityHidden(true)
                Text(message).multilineTextAlignment(.center)
                Button("Try Again") { Task { await store.refresh() } }.buttonStyle(.borderedProminent).tint(.white.opacity(0.25))
                Button("Search for a Location", action: openLocations).buttonStyle(.bordered).tint(.white)
                if store.weatherRequestFailed {
                    Button("Use Web Version", action: openWebVersion).buttonStyle(.bordered).tint(.white)
                }
            }
            .padding(32)
        default:
            VStack(spacing: 16) {
                ProgressView().controlSize(.large).tint(.white)
                Text(store.title == "Locating…" ? "Locating you…" : "Loading weather…")
            }
            .accessibilityElement(children: .combine)
        }
    }

    func notice(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.footnote)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    var isLoading: Bool {
        if case .loading = store.phase { return true }
        return false
    }

    func credits(_ w: AppWeather) -> some View {
        var s = "Weather by Open-Meteo · Forecast text and alerts by NOAA NWS"
        if w.tides != nil { s += " · Tides by NOAA CO-OPS" }
        if w.sunset != nil { s += " · Sunset forecast by Sunsethue" }
        // When the data was fetched is a real-world moment, so show it in the phone's time zone
        // (unlike forecast and tide times, which belong to the location's time zone).
        let updated = w.fetched.formatted(date: .omitted, time: .shortened)
        return VStack(spacing: 10) {
            Button {
                // Same unstructured Task as pull-to-refresh, so SwiftUI can't cancel the requests.
                Task { await Task { await store.refresh() }.value }
            } label: {
                HStack(spacing: 6) {
                    if isLoading { ProgressView().controlSize(.small).tint(.white) }
                    else { Image(systemName: "arrow.clockwise") }
                    Text(isLoading ? "Updating…" : "Updated \(updated) · Refresh")
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.white.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .accessibilityLabel(isLoading ? "Updating weather" : "Refresh weather")
            .accessibilityHint("Last updated at \(updated)")
            Text(s)
                .font(.caption2).foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 8)
    }
}

// Finds the enclosing UIScrollView and locks it to one axis at a time, so a drag that starts
// vertical can't also nudge the page sideways.
private struct NoHorizontalPan: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { UIView() }
    func updateUIView(_ view: UIView, context: Context) {
        DispatchQueue.main.async {
            var v: UIView? = view
            while let current = v, !(current is UIScrollView) { v = current.superview }
            (v as? UIScrollView)?.isDirectionalLockEnabled = true
            (v as? UIScrollView)?.alwaysBounceHorizontal = false
        }
    }
}

// Same background gradients as the web app (atmoGradient in public/index.html): dark, fading to the
// app surface color at the bottom.
enum AtmosphereGradient {
    static func make(code: Int, isDay: Bool) -> LinearGradient {
        func stops(_ list: [(String, Double)]) -> LinearGradient {
            LinearGradient(stops: list.map { .init(color: Color(hex: $0.0), location: $0.1) }, startPoint: .top, endPoint: .bottom)
        }
        let surface = "0f1418"
        if !isDay { return stops([("060c1a", 0), ("0a1020", 0.4), (surface, 1)]) }
        switch code {
        case ...1: return stops([("0c3a6e", 0), ("163d6a", 0.3), ("0f2240", 0.6), (surface, 1)])
        case 2: return stops([("162840", 0), ("1a3050", 0.3), ("0f1c30", 0.6), (surface, 1)])
        case 3: return stops([("1a2230", 0), ("151e28", 0.4), (surface, 1)])
        case 95...: return stops([("080c14", 0), ("0d1220", 0.4), (surface, 1)])
        case 60...: return stops([("101c2c", 0), ("162030", 0.4), (surface, 1)])
        default: return stops([("161e2c", 0), (surface, 1)])
        }
    }
}

extension Color {
    init(hex: String) {
        let v = UInt32(hex, radix: 16) ?? 0
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
}
