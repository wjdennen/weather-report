#if os(iOS)
import SwiftUI
import WidgetKit

// Lock screen widgets (iPhone only): Now, Hourly and Best Beach. Each is its own widget in the gallery with its
// own location setting, and offers rectangular, circular and inline versions.
//
// A lock screen widget has a small fixed frame and the system draws it in its own monochrome style, so these use
// fixed point sizes instead of Dynamic Type (which overflowed the frame on phones set to larger text). Anything
// that can be long shrinks to fit rather than being cut off.

struct LockWidgetShell<Content: View>: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeatherEntry
    let content: (WeatherData) -> Content

    init(entry: WeatherEntry, @ViewBuilder content: @escaping (WeatherData) -> Content) {
        self.entry = entry
        self.content = content
    }

    var body: some View {
        Group {
            if let d = entry.data {
                framed(content(d))
            } else {
                framed(Label("Weather unavailable", systemImage: "cloud.slash").font(.system(size: 12)).lineLimit(2))
            }
        }
        .dynamicTypeSize(.large)
        .containerBackground(for: .widget) { Color.clear }
    }

    // The rectangular size gets the system's soft translucent backing, drawn inside the widget (a container
    // background is ignored for lock screen widgets), so the text stays readable over a bright wallpaper.
    // The circular views draw their own; the inline one has none.
    @ViewBuilder func framed<V: View>(_ view: V) -> some View {
        if family == .accessoryRectangular {
            ZStack {
                AccessoryWidgetBackground()
                view.padding(.horizontal, 8).padding(.vertical, 4)
            }
        } else {
            view
        }
    }
}

// An icon followed by one line of text that shrinks to fit.
func lockLine(_ icon: String, _ text: String, size: CGFloat, weight: Font.Weight = .regular) -> some View {
    HStack(spacing: 4) {
        Image(systemName: icon).font(.system(size: size - 2)).frame(width: 15)
        Text(text).font(.system(size: size, weight: weight)).lineLimit(1).minimumScaleFactor(0.6)
    }
}

// MARK: - Now

struct NowLockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WeatherNowLock", intent: LocationIntent.self, provider: Provider()) { entry in
            LockWidgetShell(entry: entry) { NowLockView(d: $0) }
        }
        .configurationDisplayName("Weather Now")
        .description("Current temperature and conditions, today's high and low, and wind.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct NowLockView: View {
    @Environment(\.widgetFamily) var family
    let d: WeatherData

    var body: some View {
        let c = d.current
        let symbol = WMO.symbol(c.weather_code, isDay: c.is_day == 1)
        switch family {
        case .accessoryInline:
            Label("\(deg(c.temperature_2m)) \(WMO.text(c.weather_code))", systemImage: symbol)
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: symbol).font(.system(size: 13))
                    Text(deg(c.temperature_2m)).font(.system(size: 17, weight: .bold)).minimumScaleFactor(0.7)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: symbol).font(.system(size: 15)).frame(width: 15)
                    Text(deg(c.temperature_2m)).font(.system(size: 22, weight: .bold)).lineLimit(1).fixedSize()
                    Text(WMO.text(c.weather_code)).font(.system(size: 14)).lineLimit(1).minimumScaleFactor(0.5)
                }
                if let today = d.days.first {
                    lockLine("arrow.up.arrow.down", "H \(deg(today.hi))  L \(deg(today.lo))", size: 14, weight: .semibold)
                }
                lockLine("wind", Wind.label(wind: c.wind_speed_10m, gust: c.wind_gusts_10m, dir: c.wind_direction_10m) + " mph", size: 13)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Hourly

struct HourlyLockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WeatherHourlyLock", intent: LocationIntent.self, provider: Provider()) { entry in
            LockWidgetShell(entry: entry) { HourlyLockView(d: $0) }
        }
        .configurationDisplayName("Weather Hourly")
        .description("The next few hours: temperature, sky and chance of rain.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct HourlyLockView: View {
    @Environment(\.widgetFamily) var family
    let d: WeatherData

    var body: some View {
        let hours = Array(d.hours.prefix(3))   // three columns: four did not fit the frame
        switch family {
        case .accessoryInline:
            if let later = d.hours.count > 3 ? d.hours[3] : d.hours.last {
                Label("\(deg(d.current.temperature_2m)) → \(deg(later.temp)) by \(clock(later.date, d.timeZone))", systemImage: "clock")
            } else {
                Label(deg(d.current.temperature_2m), systemImage: "clock")
            }
        case .accessoryCircular:
            // Chance of rain at its highest over the next three hours.
            let chance = d.hours.prefix(3).map(\.precip).max() ?? 0
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "cloud.rain.fill").font(.system(size: 12))
                    Text("\(chance)%").font(.system(size: 16, weight: .bold)).minimumScaleFactor(0.7)
                }
            }
        default:
            HStack(spacing: 0) {
                ForEach(Array(hours.enumerated()), id: \.element.id) { i, h in
                    VStack(spacing: 1) {
                        Text(i == 0 ? "Now" : clock(h.date, d.timeZone)).font(.system(size: 11)).lineLimit(1).minimumScaleFactor(0.7)
                        Image(systemName: WMO.symbol(h.code, isDay: isDay(h.date))).font(.system(size: 15))
                        Text(deg(h.temp)).font(.system(size: 15, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                        Text(h.precip >= 10 ? "\(h.precip)%" : " ").font(.system(size: 11)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    func isDay(_ date: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = d.timeZone
        let hour = cal.component(.hour, from: date)
        return hour >= 6 && hour < 20
    }
}

// MARK: - Best beach (near Aquidneck Island / Little Compton, RI)

struct BeachLockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WeatherBeachLock", intent: LocationIntent.self, provider: Provider()) { entry in
            LockWidgetShell(entry: entry) { BeachLockView(d: $0) }
        }
        .configurationDisplayName("Best Beach")
        .description("Which beach has the least wind in your face right now (Aquidneck Island / Little Compton, RI).")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct BeachLockView: View {
    @Environment(\.widgetFamily) var family
    let d: WeatherData

    var body: some View {
        let c = d.current
        let wind = Wind.label(wind: c.wind_speed_10m, gust: c.wind_gusts_10m, dir: c.wind_direction_10m) + " mph"
        switch family {
        case .accessoryInline:
            Label(d.beach?.headline ?? "No beach data here", systemImage: "beach.umbrella.fill")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                if d.beach != nil {
                    VStack(spacing: 0) {
                        Text(Wind.arrow(c.wind_direction_10m)).font(.system(size: 20, weight: .bold))
                        Text("\(Int(c.wind_speed_10m.rounded()))").font(.system(size: 14, weight: .bold))
                    }
                } else {
                    Image(systemName: "beach.umbrella").font(.system(size: 20))
                }
            }
        default:
            VStack(alignment: .leading, spacing: 1) {
                if let b = d.beach {
                    lockLine("beach.umbrella.fill", b.headline, size: 15, weight: .bold)
                    lockLine("water.waves", relation(b), size: 13)
                    lockLine("wind", wind, size: 13)
                } else {
                    lockLine("beach.umbrella", "No beach data here", size: 14, weight: .semibold)
                    Text("The beach pick covers Aquidneck Island and Little Compton, RI.")
                        .font(.system(size: 11)).lineLimit(2).minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    func relation(_ b: BeachAdvice) -> String {
        if b.anyBeachFine { return "Light wind · \(Int(b.avgSpeed.rounded())) mph avg" }
        if b.strongOffshore { return "Strong offshore wind" }
        switch b.relation {
        case .atBack: return "Wind at your back"
        case .fromSide: return "Wind from the side"
        case .inFace: return "Least wind in your face"
        }
    }
}
#endif
