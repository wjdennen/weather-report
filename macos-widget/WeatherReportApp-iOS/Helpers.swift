import SwiftUI

// MARK: - Formatting (times are shown in the forecast location's time zone, not the phone's)

func degrees(_ v: Double) -> String { "\(Int(v.rounded()))°" }

func timeString(_ d: Date, _ tz: TimeZone, minutes: Bool = true) -> String {
    let style = Date.FormatStyle(timeZone: tz)
    return d.formatted(minutes ? style.hour().minute() : style.hour())
}

func weekday(_ d: Date, _ tz: TimeZone, long: Bool = false) -> String {
    d.formatted(Date.FormatStyle(timeZone: tz).weekday(long ? .wide : .abbreviated))
}

// "Today" / "Tomorrow" / weekday, relative to the location's calendar.
func dayLabel(_ d: Date, _ w: AppWeather) -> String {
    let cal = w.calendar
    if cal.isDateInToday(d) || cal.isDate(d, inSameDayAs: Date()) { return "Today" }
    if let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()), cal.isDate(d, inSameDayAs: tomorrow) { return "Tomorrow" }
    return weekday(d, w.tz)
}

func uvText(_ v: Double) -> String { v <= 2 ? "Low" : v <= 5 ? "Moderate" : v <= 7 ? "High" : v <= 10 ? "Very High" : "Extreme" }
func uvColor(_ v: Double) -> Color {
    v <= 2 ? Color(red: 0.56, green: 0.84, blue: 1) : v <= 5 ? Color(red: 1, green: 0.76, blue: 0.46)
        : v <= 7 ? .orange : v <= 10 ? .red : .purple
}

// Open-Meteo hourly/daily wind: mirrors the web app and widget (gust only when 10+ mph above steady wind).
func windText(wind: Double, gust: Double, dir: Double) -> String { Wind.label(wind: wind, gust: gust, dir: dir) }

func spokenWind(wind: Double, gust: Double, dir: Double) -> String {
    var s = "wind \(Int(wind.rounded())) miles per hour from \(Wind.compass(dir))"
    if Wind.showsGust(wind: wind, gust: gust) { s += ", gusts to \(Int(gust.rounded()))" }
    return s
}

// MARK: - Moon (calculated locally, as in the web app)

struct MoonInfo {
    let name: String
    let emoji: String?     // nil = new moon, drawn as an outlined circle
    let illumination: Int
    let age: Int

    static func at(_ date: Date = Date()) -> MoonInfo {
        let synodic = 29.53058770576
        let known = Date(timeIntervalSince1970: 947182440) // 2000-01-06 18:14 UTC, a known new moon
        let days = date.timeIntervalSince(known) / 86400
        let age = (days.truncatingRemainder(dividingBy: synodic) + synodic).truncatingRemainder(dividingBy: synodic)
        let fraction = age / synodic
        let illumination = Int(((1 - cos(fraction * 2 * .pi)) / 2 * 100).rounded())
        let phases: [(String, String?)] = [
            ("New Moon", nil), ("Waxing Crescent", "🌒"), ("First Quarter", "🌓"), ("Waxing Gibbous", "🌔"),
            ("Full Moon", "🌕"), ("Waning Gibbous", "🌖"), ("Last Quarter", "🌗"), ("Waning Crescent", "🌘"),
        ]
        let p = phases[Int((fraction * 8).rounded()) % 8]
        return MoonInfo(name: p.0, emoji: p.1, illumination: illumination, age: Int(age.rounded()))
    }
}

// MARK: - Tide curve

struct TidePoint: Identifiable {
    var id: Date { date }
    let date: Date
    let height: Double
}

extension TideData {
    // Hourly heights across the location's current calendar day. Cosine interpolation between consecutive
    // high/low predictions, the same approach the web app uses for stations that only publish hi/lo.
    func curve(for w: AppWeather) -> [TidePoint] {
        let cal = w.calendar
        let start = cal.startOfDay(for: Date())
        var points: [TidePoint] = []
        for h in 0...24 {
            guard let t = cal.date(byAdding: .hour, value: h, to: start),
                  let next = events.firstIndex(where: { $0.date > t }), next > 0 else { continue }
            let a = events[next - 1], b = events[next]
            let frac = t.timeIntervalSince(a.date) / b.date.timeIntervalSince(a.date)
            let v = (a.height + b.height) / 2 + (a.height - b.height) / 2 * cos(.pi * frac)
            points.append(TidePoint(date: t, height: v))
        }
        return points
    }

    var info: TideInfo? {
        let now = Date()
        guard let next = events.first(where: { $0.date > now }) else { return nil }
        return TideInfo(station: stationName, previous: events.last { $0.date <= now }, next: next)
    }
}

// MARK: - Look

struct Glass: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.13)))
    }
}

extension View {
    func glass() -> some View { modifier(Glass()) }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.footnote.weight(.semibold))
            .tracking(1)
            .foregroundStyle(.white.opacity(0.7))
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 8)
    }
}

// Expand/collapse that respects Reduce Motion.
func toggle(_ set: Binding<Set<String>>, _ key: String, reduceMotion: Bool) {
    func flip() {
        if set.wrappedValue.contains(key) { set.wrappedValue.remove(key) } else { set.wrappedValue.insert(key) }
    }
    if reduceMotion { flip() } else { withAnimation(.easeInOut(duration: 0.2)) { flip() } }
}
