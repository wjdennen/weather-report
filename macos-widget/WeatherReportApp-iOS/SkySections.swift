import Charts
import SwiftUI

// MARK: - Sun

struct SunView: View {
    let w: AppWeather

    var body: some View {
        if let today = w.days.first {
            let daylight = today.sunset.timeIntervalSince(today.sunrise)
            let noon = today.sunrise.addingTimeInterval(daylight / 2)
            VStack(alignment: .leading, spacing: 14) {
                SunArc(sunrise: today.sunrise, sunset: today.sunset)
                    .frame(height: 90)
                    .accessibilityHidden(true)
                HStack {
                    timeBlock("Sunrise", today.sunrise, .leading)
                    Spacer()
                    timeBlock("Sunset", today.sunset, .trailing)
                }
                if let q = w.sunset { SunsetQualityView(q: q, tz: w.tz) }
                Divider().overlay(.white.opacity(0.15))
                HStack {
                    stat("Daylight", "\(Int(daylight) / 3600)h \(Int(daylight) % 3600 / 60)m", "sun.max")
                    Spacer()
                    stat("Solar Noon", timeString(noon, w.tz), "clock")
                }
            }
            .glass()
        }
    }

    func timeBlock(_ title: String, _ d: Date, _ align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 2) {
            Label(title, systemImage: title == "Sunrise" ? "sunrise.fill" : "sunset.fill")
                .font(.footnote).foregroundStyle(.white.opacity(0.7))
            Text(timeString(d, w.tz)).font(.title3.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }

    func stat(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: icon).font(.footnote).foregroundStyle(.white.opacity(0.7))
            Text(value).font(.headline)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SunArc: View {
    let sunrise: Date
    let sunset: Date

    var body: some View {
        Canvas { ctx, size in
            // Quadratic bezier (same shape as the web app's sun arc), scaled to the available space.
            let p0 = CGPoint(x: 10, y: size.height - 10)
            let p1 = CGPoint(x: size.width / 2, y: -size.height * 0.25)
            let p2 = CGPoint(x: size.width - 10, y: size.height - 10)
            func point(_ t: Double) -> CGPoint {
                let u = 1 - t
                return CGPoint(x: u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
                               y: u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y)
            }
            func path(to end: Double) -> Path {
                var p = Path()
                p.move(to: point(0))
                for i in 1...60 { p.addLine(to: point(end * Double(i) / 60)) }
                return p
            }
            let now = Date()
            let total = sunset.timeIntervalSince(sunrise)
            let t = max(0, min(1, now.timeIntervalSince(sunrise) / total))
            let isDay = now >= sunrise && now <= sunset

            var base = Path()
            base.move(to: CGPoint(x: 0, y: size.height - 10)); base.addLine(to: CGPoint(x: size.width, y: size.height - 10))
            ctx.stroke(base, with: .color(.white.opacity(0.2)), lineWidth: 1)
            ctx.stroke(path(to: 1), with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
            if isDay { ctx.stroke(path(to: t), with: .color(.orange), style: StrokeStyle(lineWidth: 3, lineCap: .round)) }
            let c = point(isDay ? t : (now < sunrise ? 0 : 1))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 8, y: c.y - 8, width: 16, height: 16)),
                     with: .color(isDay ? .yellow : .gray))
        }
    }
}

struct SunsetQualityView: View {
    let q: SunsetQuality
    let tz: TimeZone

    var body: some View {
        let level = q.quality >= 0.6 ? Color.orange : q.quality >= 0.3 ? Color.yellow : Color.white.opacity(0.7)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("\(q.tonight ? "Tonight's" : "Tomorrow's") sunset", systemImage: "sunset.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(q.quality_text ?? "") · \(Int((q.quality * 100).rounded()))%")
                    .font(.footnote.weight(.bold)).foregroundStyle(level)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(level.opacity(0.18), in: Capsule())
            }
            if !detail.isEmpty { Text(detail).font(.footnote).foregroundStyle(.white.opacity(0.75)) }
            if let light = bestLight { Text(light).font(.footnote).foregroundStyle(.white.opacity(0.75)) }
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    var detail: String {
        var parts: [String] = []
        if let c = q.cloud_cover { parts.append("Cloud cover \(Int((c * 100).rounded()))%") }
        if let d = q.direction { parts.append("sets toward \(Wind.compass(d))") }
        return parts.joined(separator: " · ")
    }

    var bestLight: String? {
        guard let g = q.golden_hour, g.count == 2, let a = parse(g[0]), let b = parse(g[1]) else { return nil }
        return "Best light \(timeString(a, tz)) – \(timeString(b, tz))"
    }

    func parse(_ s: String) -> Date? {
        let plain = ISO8601DateFormatter()
        if let d = plain.date(from: s) { return d }
        let frac = ISO8601DateFormatter()
        frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return frac.date(from: s)
    }
}

// MARK: - Moon

struct MoonView: View {
    var body: some View {
        let m = MoonInfo.at()
        HStack(spacing: 16) {
            Group {
                if let e = m.emoji { Text(e).font(.system(size: 44)) }
                else { Circle().strokeBorder(.white.opacity(0.6), lineWidth: 2).frame(width: 40, height: 40) }
            }
            .frame(width: 52, height: 52)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(m.name).font(.headline)
                Text("Illumination \(m.illumination)%  ·  Day \(m.age) of 29")
                    .font(.footnote).foregroundStyle(.white.opacity(0.75))
            }
            Spacer(minLength: 0)
        }
        .glass()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tides

struct TidesView: View {
    let w: AppWeather
    @ScaledMetric(relativeTo: .headline) private var timeWidth: CGFloat = 100   // fits "10:18 PM"; scales with text size

    var body: some View {
        if let tides = w.tides {
            VStack(alignment: .leading, spacing: 12) {
                if let info = tides.info { nextTide(info) }
                chart(tides)
                list(tides)
                Text(tides.stationName).font(.caption).foregroundStyle(.white.opacity(0.55))
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "water.waves").font(.title).accessibilityHidden(true)
                Text("No NOAA tide station found within 150 miles of this location.").multilineTextAlignment(.center)
                Text("Tide data covers US coastal areas.").font(.footnote).foregroundStyle(.white.opacity(0.7))
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .glass()
        }
    }

    func nextTide(_ t: TideInfo) -> some View {
        let day = t.dayMarker(tz: w.tz).map { " \($0)" } ?? ""
        return HStack(spacing: 12) {
            Image(systemName: t.next.isHigh ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.title).foregroundStyle(Color.cyan).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("NEXT TIDE").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                Text("\(t.next.isHigh ? "High" : "Low") \(timeString(t.next.date, w.tz))\(day)").font(.title3.weight(.semibold))
                Text("Now: \(t.status())").font(.footnote).foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .glass()
        .accessibilityElement(children: .combine)
    }

    func chart(_ tides: TideData) -> some View {
        let points = tides.curve(for: w)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Today's tide curve").font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
            Chart {
                ForEach(points) { p in
                    AreaMark(x: .value("Time", p.date), y: .value("Height", p.height))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [.cyan.opacity(0.35), .cyan.opacity(0.03)], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Time", p.date), y: .value("Height", p.height))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color(red: 0.56, green: 0.84, blue: 1))
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                RuleMark(x: .value("Now", Date()))
                    .foregroundStyle(.white.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                    AxisValueLabel(format: .dateTime.hour().locale(.current), anchor: .top)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .environment(\.timeZone, w.tz)
            .frame(height: 110)
            .accessibilityLabel("Tide curve for today")
            .accessibilityValue(summary(tides))
        }
        .glass()
    }

    func summary(_ tides: TideData) -> String {
        let events = todaysEvents(tides)
        return events.map { "\($0.isHigh ? "High" : "Low") at \(timeString($0.date, w.tz))" }.joined(separator: ", ")
    }

    func todaysEvents(_ tides: TideData) -> [TideEvent] {
        tides.events.filter { w.calendar.isDate($0.date, inSameDayAs: Date()) }
    }

    // Upcoming tides only, through the end of tomorrow. Past ones are covered by the curve above and
    // by the "Now: ..." status on the next-tide card.
    func list(_ tides: TideData) -> some View {
        let cal = w.calendar
        let now = Date()
        let end = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: now)) ?? now
        let events = tides.events.filter { $0.date > now && $0.date < end }
        return Group {
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.offset) { i, e in
                        let label = dayLabel(e.date, w)
                        // A "Today" / "Tomorrow" header whenever the day changes.
                        if i == 0 || label != dayLabel(events[i - 1].date, w) {
                            Text(label.uppercased()).font(.caption.weight(.semibold)).tracking(0.8)
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.top, i == 0 ? 0 : 14).padding(.bottom, 4)
                                .accessibilityAddTraits(.isHeader)
                        } else {
                            Divider().overlay(.white.opacity(0.12))
                        }
                        HStack(spacing: 12) {
                            Image(systemName: e.isHigh ? "arrow.up" : "arrow.down")
                                .frame(width: 32, height: 32)
                                .background((e.isHigh ? Color.cyan : Color.blue).opacity(0.25), in: Circle())
                                .accessibilityHidden(true)
                            Text(timeString(e.date, w.tz)).font(.headline).lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(width: timeWidth, alignment: .leading)
                            VStack(alignment: .leading, spacing: 0) {
                                Text("\(e.isHigh ? "High" : "Low") Tide").font(.subheadline).lineLimit(1).minimumScaleFactor(0.6)
                                Text(String(format: "%.1f ft", e.height)).font(.caption).foregroundStyle(.white.opacity(0.65))
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(label): \(e.isHigh ? "High" : "Low") tide at \(timeString(e.date, w.tz)), \(String(format: "%.1f", e.height)) feet")
                    }
                }
                .glass()
            }
        }
    }
}
