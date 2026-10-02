import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Configuration (right-click the widget > Edit Widget)

struct LocationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Location"
    static var description = IntentDescription("City name or US zip code.")

    @Parameter(title: "City or zip", default: "New York")
    var query: String
}

// MARK: - Timeline

struct WeatherEntry: TimelineEntry {
    let date: Date
    let data: WeatherData?
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry { WeatherEntry(date: .now, data: nil) }

    func snapshot(for configuration: LocationIntent, in context: Context) async -> WeatherEntry {
        WeatherEntry(date: .now, data: try? await WeatherService.load(query: configuration.query))
    }

    func timeline(for configuration: LocationIntent, in context: Context) async -> Timeline<WeatherEntry> {
        let data = try? await WeatherService.load(query: configuration.query)
        // Retry sooner after a failure; otherwise refresh every 30 minutes.
        let next = Date().addingTimeInterval(data == nil ? 300 : 1800)
        return Timeline(entries: [WeatherEntry(date: .now, data: data)], policy: .after(next))
    }
}

// MARK: - Views

struct WeatherWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: WeatherEntry

    var body: some View {
        Group {
            if let d = entry.data {
                switch family {
                case .systemSmall: SmallView(d: d)
                case .systemMedium: MediumView(d: d)
                default: LargeView(d: d)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "cloud.slash")
                    Text("Weather unavailable").font(.caption)
                    Text("Check the location in Edit Widget").font(.caption2).opacity(0.7)
                }
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) {
            let c = entry.data?.current
            LinearGradient(colors: WMO.background(c?.weather_code ?? 3, isDay: (c?.is_day ?? 1) == 1),
                           startPoint: .top, endPoint: .bottom)
        }
    }
}

func deg(_ v: Double) -> String { "\(Int(v.rounded()))°" }

// Times are shown in the forecast location's time zone, not the Mac's.
func clock(_ date: Date, _ tz: TimeZone, minutes: Bool = false) -> String {
    let style = Date.FormatStyle(timeZone: tz)
    return date.formatted(minutes ? style.hour().minute() : style.hour())
}

// Large-widget header version: bigger, stacked.
struct TideBlock: View {
    let tides: TideInfo
    let tz: TimeZone
    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if let h = tides.nextHigh { item("High", "arrow.up", h) }
            if let l = tides.nextLow { item("Low", "arrow.down", l) }
        }
        .padding(.trailing, 8)
    }
    func item(_ label: String, _ icon: String, _ e: TideEvent) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Label("\(label) \(clock(e.date, tz, minutes: true))", systemImage: icon)
                .font(.headline)
            Text("\(String(format: "%.1f", e.height)) ft").font(.subheadline).opacity(0.85)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

struct TideLine: View {
    let tides: TideInfo
    let tz: TimeZone
    var body: some View {
        HStack(spacing: 10) {
            if let h = tides.nextHigh { item("High", h) }
            if let l = tides.nextLow { item("Low", l) }
        }
        .font(.caption2)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    func item(_ label: String, _ e: TideEvent) -> some View {
        Label("\(label) \(clock(e.date, tz, minutes: true)) · \(String(format: "%.1f", e.height)) ft",
              systemImage: label == "High" ? "arrow.up" : "arrow.down")
            .labelStyle(.titleAndIcon)
    }
}

struct AlertBanner: View {
    let alert: WeatherAlert
    var body: some View {
        let color: Color = alert.event.contains("Warning") ? .red : alert.event.contains("Watch") ? .orange : .yellow
        Label(alert.event, systemImage: "exclamationmark.triangle.fill")
            .font(.caption2.bold())
            .lineLimit(1)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.85), in: Capsule())
            .foregroundStyle(color == .yellow ? .black : .white)
    }
}

struct Header: View {
    let d: WeatherData
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill").font(.system(size: 9))
            Text(d.place.name).font(.caption.bold()).lineLimit(1)
        }
    }
}

struct SmallView: View {
    let d: WeatherData
    var body: some View {
        let c = d.current
        VStack(alignment: .leading, spacing: 2) {
            Header(d: d)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline) {
                Text(deg(c.temperature_2m)).font(.system(size: 42, weight: .light))
                Spacer()
                Image(systemName: WMO.symbol(c.weather_code, isDay: c.is_day == 1))
                    .symbolRenderingMode(.multicolor).font(.title2)
            }
            Text(WMO.text(c.weather_code)).font(.caption.bold())
            if let t = d.days.first {
                Text("H \(deg(t.hi))  L \(deg(t.lo))").font(.caption2).opacity(0.85)
            }
            if let a = d.alert { AlertBanner(alert: a) }
            else {
                Text(Wind.label(wind: c.wind_speed_10m, gust: c.wind_gusts_10m, dir: c.wind_direction_10m) + " mph")
                    .font(.caption2).foregroundStyle(Wind.gustColor(c.wind_gusts_10m))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HourStrip: View {
    let hours: [HourSlice]
    let tz: TimeZone
    var showPrecip: Bool { hours.contains { $0.precip >= 10 } }
    var body: some View {
        HStack(spacing: 0) {
            ForEach(hours) { h in
                VStack(spacing: 3) {
                    Text(clock(h.date, tz)).font(.caption2).opacity(0.8)
                    Image(systemName: WMO.symbol(h.code)).symbolRenderingMode(.multicolor)
                    Text(deg(h.temp)).font(.caption.bold())
                    if showPrecip {
                        Text(h.precip >= 10 ? "\(h.precip)%" : " ").font(.system(size: 9)).foregroundStyle(.cyan)
                    }
                    Text(Wind.label(wind: h.wind, gust: h.gust, dir: h.dir))
                        .font(.system(size: 9)).foregroundStyle(Wind.gustColor(h.gust))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct MediumView: View {
    let d: WeatherData
    var body: some View {
        let c = d.current
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Header(d: d)
                Text(deg(c.temperature_2m)).font(.system(size: 44, weight: .light))
                Text(WMO.text(c.weather_code)).font(.caption.bold())
                Text("Feels \(deg(c.apparent_temperature))").font(.caption2).opacity(0.85)
                if let t = d.days.first { Text("H \(deg(t.hi))  L \(deg(t.lo))").font(.caption2).opacity(0.85) }
            }
            .frame(width: 110, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                if let a = d.alert { AlertBanner(alert: a) }
                Spacer(minLength: 0)
                HourStrip(hours: Array(d.hours.prefix(5)), tz: d.timeZone)
                if let t = d.tides { TideLine(tides: t, tz: d.timeZone) }
            }
        }
    }
}

struct LargeView: View {
    let d: WeatherData
    var body: some View {
        let c = d.current
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Header(d: d)
                    Text(deg(c.temperature_2m)).font(.system(size: 52, weight: .light))
                    Text("\(WMO.text(c.weather_code)) · Feels \(deg(c.apparent_temperature))").font(.caption)
                }
                Spacer(minLength: 4)
                if let t = d.tides { TideBlock(tides: t, tz: d.timeZone) }
                Image(systemName: WMO.symbol(c.weather_code, isDay: c.is_day == 1))
                    .symbolRenderingMode(.multicolor).font(.system(size: 40))
            }
            if let a = d.alert { AlertBanner(alert: a) }
            HourStrip(hours: Array(d.hours.prefix(6)), tz: d.timeZone)
            Divider().overlay(.white.opacity(0.4))
            let days = Array(d.days.prefix(5))
            let lo = days.map(\.lo).min() ?? 0
            let hi = days.map(\.hi).max() ?? 1
            ForEach(days) { day in
                HStack(spacing: 8) {
                    Text(day.date.formatted(Date.FormatStyle(timeZone: d.timeZone).weekday(.abbreviated))).font(.caption.bold()).frame(width: 34, alignment: .leading)
                    Image(systemName: WMO.symbol(day.code)).symbolRenderingMode(.multicolor).frame(width: 24)
                    Text(deg(day.lo)).font(.caption).opacity(0.75).frame(width: 32, alignment: .trailing)
                    RangeBar(lo: day.lo, hi: day.hi, minAll: lo, maxAll: hi)
                    Text(deg(day.hi)).font(.caption.bold()).frame(width: 32, alignment: .leading)
                    Text(day.gust >= 30 ? "g\(Int(day.gust.rounded()))" : "")
                        .font(.caption2).foregroundStyle(Wind.gustColor(day.gust)).frame(width: 30, alignment: .trailing)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct RangeBar: View {
    let lo: Double, hi: Double, minAll: Double, maxAll: Double
    var body: some View {
        GeometryReader { g in
            let span = max(maxAll - minAll, 1)
            let x = (lo - minAll) / span * g.size.width
            let w = max((hi - lo) / span * g.size.width, 6)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25))
                Capsule().fill(LinearGradient(colors: [.cyan, .yellow, .orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: w).offset(x: x)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Widget

struct WeatherWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WeatherReportWidget", intent: LocationIntent.self, provider: Provider()) { entry in
            WeatherWidgetView(entry: entry)
        }
        .configurationDisplayName("Weather Report")
        .description("Current conditions, hourly forecast and wind for a location.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct WeatherWidgetBundle: WidgetBundle {
    var body: some Widget { WeatherWidget() }
}
