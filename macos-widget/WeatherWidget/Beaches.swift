import Foundation

// Which way each beach faces (compass heading you look toward the water), measured from OpenStreetMap
// coastline geometry. Wind FROM that heading blows in your face; wind from the opposite side is at your back.
// Listed in tie-break order: when several beaches are equally good, the earlier one wins.
struct Beach {
    let name: String
    let facing: Double
}

struct BeachAdvice {
    enum Relation { case atBack, fromSide, inFace }
    let anyBeachFine: Bool
    let best: Beach
    let relation: Relation
    let alsoGood: [Beach]
    let strongOffshore: Bool
    let avgSpeed: Double
}

enum BeachAdvisor {
    static let beaches: [Beach] = [
        Beach(name: "Second Beach", facing: 195),
        Beach(name: "Third Beach", facing: 80),
        Beach(name: "Easton's Beach", facing: 157),
        Beach(name: "Sandy Point", facing: 85),
        Beach(name: "Gooseberry Beach", facing: 220),
        Beach(name: "Island Park Beach", facing: 155),
        Beach(name: "South Shore Beach", facing: 140),
        Beach(name: "Goosewing Beach", facing: 160),
        Beach(name: "Teddy's Beach", facing: 155),
        Beach(name: "King Park Beach", facing: 300),
    ]

    static let center = (lat: 41.52, lon: -71.25)   // Aquidneck Island / Little Compton
    static let maxMiles = 40.0
    static let lightWind = 8.0       // average mph below which any beach is fine
    static let windowHours = 4       // look at the next few hours, not just right now
    static let goodOnshore = 3.0     // mph of wind in your face still counted as "good"

    static func miles(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = Double.pi / 180
        let a = pow(sin((lat2 - lat1) * r / 2), 2) + cos(lat1 * r) * cos(lat2 * r) * pow(sin((lon2 - lon1) * r / 2), 2)
        return 3958.8 * 2 * asin(min(1, sqrt(a)))
    }

    static func advice(place: Place, hours: [HourSlice]) -> BeachAdvice? {
        guard miles(place.lat, place.lon, center.lat, center.lon) <= maxMiles else { return nil }
        let window = Array(hours.prefix(windowHours))
        guard !window.isEmpty else { return nil }
        let avgSpeed = window.map(\.wind).reduce(0, +) / Double(window.count)

        // signed = wind speed pushing onto the beach (positive = in your face, negative = at your back)
        func signed(_ b: Beach) -> Double {
            window.map { h in h.wind * cos((h.dir - b.facing) * .pi / 180) }.reduce(0, +) / Double(window.count)
        }
        let scored = beaches.map { (beach: $0, signed: signed($0), onshore: max(0, signed($0))) }
        let minOnshore = scored.map(\.onshore).min() ?? 0
        let best = scored.first { $0.onshore <= minOnshore + 1 } ?? scored[0]

        let ratio = avgSpeed > 0 ? best.signed / avgSpeed : 0
        let relation: BeachAdvice.Relation = ratio > 0.5 ? .inFace : ratio < -0.35 ? .atBack : .fromSide
        let also = scored
            .filter { $0.beach.name != best.beach.name && $0.onshore <= max(goodOnshore, minOnshore + 1) }
            .sorted { $0.onshore < $1.onshore }
            .prefix(3).map(\.beach)
        return BeachAdvice(anyBeachFine: avgSpeed < lightWind, best: best.beach, relation: relation,
                           alsoGood: Array(also), strongOffshore: relation == .atBack && avgSpeed >= 20,
                           avgSpeed: avgSpeed)
    }
}
