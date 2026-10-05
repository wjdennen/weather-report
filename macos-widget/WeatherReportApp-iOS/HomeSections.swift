import SwiftUI

// MARK: - Alerts

struct AlertsView: View {
    let alerts: [NWSAlert]
    let tz: TimeZone
    @Binding var expanded: Set<String>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            ForEach(alerts) { a in
                let open = expanded.contains(a.id)
                let color = tint(a.event)
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        if !a.description.isEmpty { toggle($expanded, a.id, reduceMotion: reduceMotion) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(a.event).font(.subheadline.weight(.bold))
                                Text(subtitle(a)).font(.caption).opacity(0.9)
                            }
                            Spacer(minLength: 0)
                            if !a.description.isEmpty {
                                Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 180 : 0)).accessibilityHidden(true)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(a.description.isEmpty ? "" : (open ? "Collapse details" : "Expand details"))
                    .accessibilityAddTraits(.isButton)
                    if open && !a.description.isEmpty {
                        Text(a.description).font(.footnote)
                    }
                }
                .foregroundStyle(color == .yellow ? Color.black : Color.white)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    func tint(_ event: String) -> Color {
        event.contains("Warning") ? .red : event.contains("Watch") ? .orange : .yellow
    }

    func subtitle(_ a: NWSAlert) -> String {
        var s = a.headline.components(separatedBy: " issued").first ?? ""
        if let end = a.ends {
            let cal = Calendar.current
            let day = cal.isDateInToday(end) ? "" : weekday(end, tz) + " "
            s += (s.isEmpty ? "" : " · ") + "until \(day)\(timeString(end, tz))"
        }
        return s
    }
}

// MARK: - Hero

struct HeroView: View {
    let w: AppWeather
    @ScaledMetric(relativeTo: .largeTitle) private var tempSize: CGFloat = 78

    var body: some View {
        let c = w.current
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(WMO.text(c.code)).font(.title3.weight(.semibold))
                    Image(systemName: WMO.symbol(c.code, isDay: c.isDay))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 44))
                        .accessibilityHidden(true)
                }
                Spacer()
                Text("\(Int(c.temp.rounded()))°")
                    .font(.system(size: tempSize, weight: .thin))
                    .minimumScaleFactor(0.5)
            }
            HStack {
                Label("Feels \(degrees(c.feelsLike))", systemImage: "thermometer.medium")
                Spacer()
                if let today = w.days.first {
                    Label("\(degrees(today.hi))", systemImage: "arrow.up")
                    Label("\(degrees(today.lo))", systemImage: "arrow.down")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(heroLabel)
    }

    var heroLabel: String {
        let c = w.current
        var s = "\(Int(c.temp.rounded())) degrees, \(WMO.text(c.code)). Feels like \(Int(c.feelsLike.rounded()))."
        if let t = w.days.first { s += " High \(Int(t.hi.rounded())), low \(Int(t.lo.rounded()))." }
        return s
    }
}

// MARK: - Hourly

struct HourlyView: View {
    let w: AppWeather
    @ScaledMetric(relativeTo: .body) private var chipWidth: CGFloat = 62

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(w.hours.enumerated()), id: \.element.id) { i, h in
                    chip(i, h)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
    }

    func chip(_ i: Int, _ h: HourChip) -> some View {
        let hour = w.calendar.component(.hour, from: h.date)
        let newDay = i > 0 && hour == 0
        let isDay = hour >= 6 && hour < 20
        return VStack(spacing: 6) {
            Text(newDay ? weekday(h.date, w.tz).uppercased() : " ")
                .font(.caption2.weight(.bold)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
            Text(i == 0 ? "Now" : timeString(h.date, w.tz, minutes: false)).font(.caption).opacity(0.8)
                .lineLimit(1).minimumScaleFactor(0.6)
            Image(systemName: WMO.symbol(h.code, isDay: isDay)).symbolRenderingMode(.multicolor).font(.title3)
                .frame(height: 24)
            Text(degrees(h.temp)).font(.headline).lineLimit(1).minimumScaleFactor(0.6)
            Text(windText(wind: h.wind, gust: h.gust, dir: h.dir))
                .font(.caption2).foregroundStyle(Wind.gustColor(h.gust)).lineLimit(1).minimumScaleFactor(0.5)
            precipBar(h)
            Text(h.precipChance > 0 ? "\(h.precipChance)%" : " ").font(.caption2).foregroundStyle(.cyan)
                .lineLimit(1).minimumScaleFactor(0.5)
        }
        .frame(width: chipWidth)
        .padding(.vertical, 10)
        .background(i == 0 ? .white.opacity(0.22) : .white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(i, h))
    }

    // Width = chance of precipitation; opacity = expected amount.
    func precipBar(_ h: HourChip) -> some View {
        let amount = 0.25 + min(1, h.precipAmount / 0.5) * 0.75
        return GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule().fill(Color.cyan.opacity(amount)).frame(width: g.size.width * CGFloat(h.precipChance) / 100)
            }
        }
        .frame(width: 44, height: 4)
    }

    func label(_ i: Int, _ h: HourChip) -> String {
        let when = i == 0 ? "Now" : "\(weekday(h.date, w.tz)) \(timeString(h.date, w.tz, minutes: false))"
        var s = "\(when): \(Int(h.temp.rounded())) degrees, \(WMO.text(h.code)), \(spokenWind(wind: h.wind, gust: h.gust, dir: h.dir))"
        if h.precipChance > 0 { s += ", \(h.precipChance) percent chance of precipitation" }
        return s
    }
}

// MARK: - NWS text forecast

struct DetailedForecastView: View {
    let w: AppWeather

    var body: some View {
        if let p = w.periods.first(where: { $0.start <= Date() && Date() < $0.end }) ?? w.periods.first {
            VStack(alignment: .leading, spacing: 6) {
                Label(p.name, systemImage: "text.alignleft").font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                Text(p.detailedForecast).font(.callout)
                Text("National Weather Service").font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
            .glass()
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Conditions

struct ConditionsView: View {
    let w: AppWeather

    var body: some View {
        let c = w.current
        let uv = w.days.first?.uv ?? 0
        let vis = c.visibilityMiles.map { $0 >= 10 ? "10+ mi" : "\(Int($0.rounded())) mi" } ?? "—"
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            card("wind", "Wind", "\(Int(c.wind.rounded())) mph",
                 "\(Wind.compass(c.windDir)) · Gusts \(Int(c.gust.rounded())) mph")
            card("humidity.fill", "Humidity", c.humidity.map { "\(Int($0.rounded()))%" } ?? "—", "")
            card("sun.max.fill", "UV Index", "\(Int(uv.rounded()))", uvText(uv), valueColor: uvColor(uv))
            card("eye.fill", "Visibility", vis,
                 c.precipToday > 0 ? String(format: "%.2f\" today", c.precipToday) : "No precipitation")
        }
    }

    func card(_ icon: String, _ name: String, _ value: String, _ sub: String, valueColor: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(name, systemImage: icon).font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
            Text(value).font(.title.weight(.medium)).foregroundStyle(valueColor).minimumScaleFactor(0.7).lineLimit(1)
            Text(sub.isEmpty ? " " : sub).font(.caption).foregroundStyle(.white.opacity(0.7)).lineLimit(2)
        }
        .glass()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name): \(value)\(sub.isEmpty ? "" : ", \(sub)")")
    }
}

// MARK: - Beach pick (near Aquidneck Island / Little Compton, RI)

extension BeachAdvice {
    var summaryTitle: String { anyBeachFine ? "Any beach is fine" : "Best: \(best.name)" }
    var summaryDetail: String {
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

struct BeachView: View {
    let advice: BeachAdvice
    @State private var open = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                if reduceMotion { open.toggle() } else { withAnimation(.easeInOut(duration: 0.2)) { open.toggle() } }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "beach.umbrella.fill").font(.title).foregroundStyle(Color(red: 0.56, green: 0.84, blue: 1))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(advice.summaryTitle).font(.headline)
                        Text(advice.summaryDetail).font(.footnote).foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 180 : 0)).accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(open ? "Hide all beaches" : "Show all beaches")

            if open {
                VStack(spacing: 8) {
                    ForEach(advice.ranked, id: \.beach.name) { r in
                        HStack {
                            Text(r.beach.name).font(.subheadline)
                            Spacer()
                            Text(text(r.relation)).font(.footnote.weight(.semibold)).foregroundStyle(color(r.relation))
                        }
                    }
                    Text("Based on the next \(BeachAdvisor.windowHours) hours of forecast wind and which way each beach faces. Wind at the water's edge can differ from the forecast.")
                        .font(.caption).foregroundStyle(.white.opacity(0.6)).padding(.top, 4)
                }
            }
        }
        .glass()
    }

    func text(_ r: BeachAdvice.Relation) -> String {
        switch r { case .atBack: "At your back"; case .fromSide: "From the side"; case .inFace: "In your face" }
    }
    func color(_ r: BeachAdvice.Relation) -> Color {
        switch r { case .atBack: .green; case .fromSide: .white.opacity(0.85); case .inFace: .orange }
    }
}

// MARK: - 7-day forecast

struct ForecastView: View {
    let w: AppWeather
    @Binding var expanded: Set<String>
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let days = Array(w.days.prefix(7))
        let allMin = days.map(\.lo).min() ?? 0
        let allMax = days.map(\.hi).max() ?? 1
        let byDay = Dictionary(grouping: w.periods) { dayKey($0.start) }
        VStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { i, d in
                let periods = byDay[d.id] ?? []
                let open = expanded.contains(d.id)
                let label = i == 0 ? "Today" : weekday(d.date, w.tz)
                let cond = periods.first(where: { $0.isDaytime })?.shortForecast ?? WMO.text(d.code)
                VStack(spacing: 0) {
                    Button {
                        toggle($expanded, d.id, reduceMotion: reduceMotion)
                    } label: {
                        row(label: label, d: d, cond: cond, allMin: allMin, allMax: allMax, hasDetail: !periods.isEmpty, open: open)
                    }
                    .buttonStyle(.plain)
                    .disabled(periods.isEmpty)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(rowLabel(label, d, cond))
                    .accessibilityHint(periods.isEmpty ? "" : (open ? "Collapse details" : "Expand details"))
                    .accessibilityAddTraits(periods.isEmpty ? [] : .isButton)

                    if open && !periods.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(periods) { p in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).font(.footnote.weight(.bold))
                                    Text(p.detailedForecast).font(.footnote).foregroundStyle(.white.opacity(0.85))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.bottom, 14)
                    }
                    if i < days.count - 1 { Divider().overlay(.white.opacity(0.12)) }
                }
            }
            if w.periodsFailed {
                Divider().overlay(.white.opacity(0.12))
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("Detailed forecast unavailable. Tap to retry.", systemImage: "arrow.clockwise")
                        .font(.footnote)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.13)))
    }

    func dayKey(_ d: Date) -> String {
        AppService.timeParser(w.tz, "yyyy-MM-dd").string(from: d)
    }

    func row(label: String, d: DayRow, cond: String, allMin: Double, allMax: Double, hasDetail: Bool, open: Bool) -> some View {
        let chevron = Image(systemName: "chevron.down").font(.caption).opacity(hasDetail ? 0.7 : 0)
            .rotationEffect(.degrees(open ? 180 : 0)).accessibilityHidden(true)
        let wind = Text("\(windText(wind: d.wind, gust: d.gust, dir: d.dir)) mph").foregroundStyle(Wind.gustColor(d.gust))
        return Group {
            if typeSize.isAccessibilitySize {
                // Large text: one item per line instead of squeezing a row of columns.
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(label).font(.headline)
                        Image(systemName: WMO.symbol(d.code)).symbolRenderingMode(.multicolor)
                        Spacer()
                        chevron
                    }
                    Text("\(degrees(d.lo)) – \(degrees(d.hi))").font(.subheadline.weight(.semibold))
                    Text(cond).font(.caption).foregroundStyle(.white.opacity(0.85))
                    wind.font(.caption)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(label).font(.subheadline.weight(.semibold)).lineLimit(1).frame(width: 52, alignment: .leading)
                        Image(systemName: WMO.symbol(d.code)).symbolRenderingMode(.multicolor).font(.title3).frame(width: 32)
                        Spacer(minLength: 4)
                        Text(degrees(d.lo)).font(.footnote).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                            .frame(width: 40, alignment: .trailing)
                        tempBar(d, allMin, allMax).frame(width: 70, height: 4)
                        Text(degrees(d.hi)).font(.footnote.weight(.semibold)).lineLimit(1).frame(width: 40, alignment: .leading)
                        chevron
                    }
                    HStack(spacing: 6) {
                        Text(cond).foregroundStyle(.white.opacity(0.85)).lineLimit(2)
                        Spacer(minLength: 4)
                        wind
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    func tempBar(_ d: DayRow, _ allMin: Double, _ allMax: Double) -> some View {
        GeometryReader { g in
            let span = max(allMax - allMin, 1)
            let x = (d.lo - allMin) / span * g.size.width
            let width = max((d.hi - d.lo) / span * g.size.width, 6)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule().fill(LinearGradient(colors: [.cyan, .yellow, .orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: width).offset(x: x)
            }
        }
    }

    func rowLabel(_ label: String, _ d: DayRow, _ cond: String) -> String {
        "\(label): \(cond). High \(Int(d.hi.rounded())), low \(Int(d.lo.rounded())). \(spokenWind(wind: d.wind, gust: d.gust, dir: d.dir))"
    }
}
