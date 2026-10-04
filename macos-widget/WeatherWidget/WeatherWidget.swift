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

// Large-widget header: current wind plus next high/low tide, stacked and right-aligned.
struct HeaderStats: View {
    let current: Forecast.Current
    let tides: TideInfo?
    let tz: TimeZone
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            windItem
            if let t = tides { nextTide(t) }
        }
        .padding(.trailing, 8)
    }
    var windItem: some View {
        let showGust = Wind.showsGust(wind: current.wind_speed_10m, gust: current.wind_gusts_10m)
        let detail = "from \(Wind.compass(current.wind_direction_10m))" + (showGust ? " · g\(Int(current.wind_gusts_10m.rounded()))" : "")
        #if os(iOS)
        // One line instead of two: the iPhone widget has less height to spare.
        return Text("\(Wind.arrow(current.wind_direction_10m)) \(Int(current.wind_speed_10m.rounded())) mph \(detail)")
            .font(.subheadline.bold())
            .foregroundStyle(showGust ? Wind.gustColor(current.wind_gusts_10m) : .white)
            .lineLimit(1).minimumScaleFactor(0.7)
        #else
        return item("\(Wind.arrow(current.wind_direction_10m)) \(Int(current.wind_speed_10m.rounded())) mph", "wind", detail,
                    detailColor: showGust ? Wind.gustColor(current.wind_gusts_10m) : .white.opacity(0.85))
        #endif
    }
    func nextTide(_ t: TideInfo) -> some View {
        let day = t.dayMarker(tz: tz).map { " \($0)" } ?? ""
        return VStack(alignment: .trailing, spacing: 0) {
            #if !os(iOS)
            Text("NEXT TIDE").font(.caption2.weight(.semibold)).opacity(0.75)
            #endif
            Label("\(t.next.isHigh ? "High" : "Low") \(clock(t.next.date, tz, minutes: true))\(day)",
                  systemImage: t.next.isHigh ? "arrow.up" : "arrow.down").font(.headline)
            Text("Now: \(t.status())").font(.caption).opacity(0.9)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    func item(_ title: String, _ icon: String, _ detail: String? = nil, detailColor: Color = .white.opacity(0.85)) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Label(title, systemImage: icon).font(.headline)
            if let detail { Text(detail).font(.subheadline).foregroundStyle(detailColor) }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

extension BeachAdvice {
    var headline: String { anyBeachFine ? "Any beach is fine" : "Best: \(best.name)" }
    var detail: String {
        if anyBeachFine { return "Light wind (\(Int(avgSpeed.rounded())) mph avg)" }
        var s: String
        switch relation {
        case .atBack: s = "Wind at your back"
        case .fromSide: s = "Wind from the side"
        case .inFace: s = "Least wind in your face"
        }
        if strongOffshore { s += " · strong offshore, careful with floats" }
        else if !alsoGood.isEmpty { s += " · also " + alsoGood.map(\.name).joined(separator: ", ") }
        return s
    }
}

struct SunsetLine: View {
    let sunset: SunsetQuality
    var body: some View {
        let pct = Int((sunset.quality * 100).rounded())
        let strong = sunset.quality >= 0.6
        Label("\(sunset.tonight ? "Tonight's" : "Tomorrow's") sunset: \(sunset.quality_text ?? "") · \(pct)%", systemImage: "sunset.fill")
            .font(.caption.bold())
            .foregroundStyle(strong ? Color.orange : Color.white.opacity(sunset.quality >= 0.3 ? 1 : 0.8))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

struct BeachRow: View {
    let advice: BeachAdvice
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "beach.umbrella.fill").font(.title3)
            VStack(alignment: .leading, spacing: 0) {
                Text(advice.headline).font(.subheadline.bold())
                Text(advice.detail).font(.caption2).opacity(0.9).lineLimit(1).minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct TideLine: View {
    let tides: TideInfo
    let tz: TimeZone
    var body: some View {
        let day = tides.dayMarker(tz: tz).map { " \($0)" } ?? ""
        Label("\(tides.next.isHigh ? "High" : "Low") \(clock(tides.next.date, tz, minutes: true))\(day) · Now: \(tides.status())",
              systemImage: tides.next.isHigh ? "arrow.up" : "arrow.down")
            .labelStyle(.titleAndIcon)
            .font(.caption2)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
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
    var showWind = true
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
                    if showWind {
                        Text(Wind.label(wind: h.wind, gust: h.gust, dir: h.dir))
                            .font(.system(size: 9)).foregroundStyle(Wind.gustColor(h.gust))
                    }
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
                if let b = d.beach {
                    Label(b.anyBeachFine ? "Any beach" : b.best.name, systemImage: "beach.umbrella.fill")
                        .font(.caption2.bold()).lineLimit(1).minimumScaleFactor(0.7)
                }
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
    // The iPhone's large widget is shorter than the Mac's, so show fewer days and tighter spacing there.
    // The beach row (near Aquidneck Island) takes another day's worth of height.
    #if os(iOS)
    var dayCount: Int { d.beach == nil ? 4 : 2 }
    var showHourlyWind: Bool { d.beach == nil }
    var tempSize: CGFloat { d.beach == nil ? 40 : 36 }
    let spacing: CGFloat = 3
    #else
    let dayCount = 5, showHourlyWind = true, spacing: CGFloat = 5, tempSize: CGFloat = 46
    #endif
    var body: some View {
        let c = d.current
        VStack(alignment: .leading, spacing: spacing) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Header(d: d)
                    Text(deg(c.temperature_2m)).font(.system(size: tempSize, weight: .light))
                    Text("\(WMO.text(c.weather_code)) · Feels \(deg(c.apparent_temperature))").font(.caption)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    #if !os(iOS)
                    if let sun = d.sunset { SunsetLine(sunset: sun) }
                    #endif
                }
                Spacer(minLength: 4)
                HeaderStats(current: c, tides: d.tides, tz: d.timeZone)
                #if !os(iOS)
                Image(systemName: WMO.symbol(c.weather_code, isDay: c.is_day == 1))
                    .symbolRenderingMode(.multicolor).font(.system(size: 40))
                #endif
            }
            #if os(iOS)
            // The iPhone widget is narrower than the Mac one, so the sunset line gets its own full-width row.
            if let sun = d.sunset { SunsetLine(sunset: sun) }
            #endif
            if let a = d.alert { AlertBanner(alert: a) }
            HourStrip(hours: Array(d.hours.prefix(6)), tz: d.timeZone, showWind: showHourlyWind)
            if let b = d.beach { BeachRow(advice: b) }
            #if !os(iOS)
            Divider().overlay(.white.opacity(0.4))
            #endif
            let days = Array(d.days.prefix(dayCount))
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
