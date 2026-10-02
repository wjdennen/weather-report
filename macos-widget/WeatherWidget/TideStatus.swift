import Foundation

// Where "now" sits in the tide cycle, in plain words. Mirrored in public/index.html (tideStatus).
// Extremes are ~6 h apart: within 30 min of one it's "High/Low tide"; within 90 min after it's
// "just past"; within 90 min before the next it's "nearly"; otherwise "mid-tide".
extension TideInfo {
    func status(now: Date = Date()) -> String {
        let toNext = next.date.timeIntervalSince(now) / 60
        let sincePrev = previous.map { now.timeIntervalSince($0.date) / 60 }
        func name(_ high: Bool) -> String { high ? "high" : "low" }
        if let p = previous, let s = sincePrev, s <= 30 { return "\(name(p.isHigh).capitalized) tide" }
        if toNext <= 30 { return "\(name(next.isHigh).capitalized) tide" }
        let dir = next.isHigh ? "Rising" : "Falling"
        if let p = previous, let s = sincePrev, s <= 90 { return "\(dir) · just past \(name(p.isHigh))" }
        if toNext <= 90 { return "\(dir) · nearly \(name(next.isHigh))" }
        return previous == nil ? dir : "\(dir) · mid-tide"
    }

    // Weekday abbreviation when the next tide isn't today in the forecast location's time zone.
    func dayMarker(now: Date = Date(), tz: TimeZone) -> String? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        if cal.isDate(next.date, inSameDayAs: now) { return nil }
        return next.date.formatted(Date.FormatStyle(timeZone: tz).weekday(.abbreviated))
    }
}
