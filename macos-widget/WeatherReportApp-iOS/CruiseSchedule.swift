import Foundation

// Cruise ships calling at Newport, RI: the Newport Harbormaster's published Perrotti Park schedule (via
// Discover Newport), the same data as the web app's public/cruise-newport.json. A copy is bundled with the
// app; when the phone is online the site's copy is used instead if it's newer, so the card stays current
// between app reinstalls. Dates and ship names only (the source has no times).

struct CruiseCall: Decodable, Identifiable {
    let date: String          // yyyy-MM-dd, Newport local
    let ship: String
    let cancelled: Bool?
    var id: String { date + ship }
}

struct CruiseSchedule: Decodable {
    let updated: String       // yyyy-MM-dd of the source PDF
    let calls: [CruiseCall]
}

struct CruiseDay: Identifiable {
    let id: String            // yyyy-MM-dd
    let label: String         // "Today · 10/7"
    let isToday: Bool
    let calls: [CruiseCall]
}

enum CruiseSchedules {
    static let center = (lat: 41.4901, lon: -71.3128)   // Newport harbor
    static let maxMiles = 20.0
    static let windowDays = 5                            // today plus the next four
    static let liveURL = URL(string: "https://weather.dennen.dev/cruise-newport.json")!

    static func isNearPort(_ place: Place) -> Bool {
        BeachAdvisor.miles(place.lat, place.lon, center.lat, center.lon) <= maxMiles
    }

    // The newer of the bundled and live copies; nil only if neither could be read.
    static func load() async -> CruiseSchedule? {
        let bundled: CruiseSchedule? = Bundle.main.url(forResource: "cruise-newport", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(CruiseSchedule.self, from: $0) }
        var request = URLRequest(url: liveURL)
        request.timeoutInterval = 5
        if let (data, resp) = try? await URLSession.shared.data(for: request),
           (resp as? HTTPURLResponse)?.statusCode == 200,
           let live = try? JSONDecoder().decode(CruiseSchedule.self, from: data),
           live.updated >= (bundled?.updated ?? "") {
            return live
        }
        return bundled
    }
}

extension AppWeather {
    // Days in the window that have at least one call; empty (so no card) when nothing is scheduled.
    var cruiseDays: [CruiseDay] {
        guard let cruise else { return [] }
        let cal = calendar
        let fmt = AppService.timeParser(tz, "yyyy-MM-dd")
        let shortDate = Date.FormatStyle(timeZone: tz).month(.defaultDigits).day()
        let now = Date()
        var days: [CruiseDay] = []
        for offset in 0..<CruiseSchedules.windowDays {
            guard let date = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            let key = fmt.string(from: date)
            let calls = cruise.calls.filter { $0.date == key }
                .sorted { ($0.cancelled ?? false ? 1 : 0) < ($1.cancelled ?? false ? 1 : 0) }
            if calls.isEmpty { continue }
            let name = offset == 0 ? "Today" : offset == 1 ? "Tomorrow" : weekday(date, tz, long: true)
            days.append(CruiseDay(id: key, label: "\(name) · \(date.formatted(shortDate))", isToday: offset == 0, calls: calls))
        }
        return days
    }
}
