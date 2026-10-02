import SwiftUI

// Same WMO code table as the web app (public/index.html).
enum WMO {
    static func text(_ code: Int) -> String {
        switch code {
        case 0: "Clear Sky"
        case 1: "Mainly Clear"
        case 2: "Partly Cloudy"
        case 3: "Overcast"
        case 45: "Foggy"
        case 48: "Icy Fog"
        case 51: "Light Drizzle"
        case 53: "Drizzle"
        case 55: "Heavy Drizzle"
        case 56, 57: "Freezing Drizzle"
        case 61: "Light Rain"
        case 63: "Rain"
        case 65: "Heavy Rain"
        case 66, 67: "Freezing Rain"
        case 71: "Light Snow"
        case 73: "Snow"
        case 75: "Heavy Snow"
        case 77: "Snow Grains"
        case 80: "Light Showers"
        case 81: "Showers"
        case 82: "Heavy Showers"
        case 85: "Snow Showers"
        case 86: "Heavy Snow Showers"
        case 95: "Thunderstorm"
        case 96, 99: "T-Storm + Hail"
        default: "Unknown"
        }
    }

    static func symbol(_ code: Int, isDay: Bool = true) -> String {
        switch code {
        case 0, 1: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51, 53, 55, 61, 80: "cloud.drizzle.fill"
        case 63, 81: "cloud.rain.fill"
        case 65, 82: "cloud.heavyrain.fill"
        case 56, 57, 66, 67, 85, 86: "cloud.sleet.fill"
        case 71, 73, 77: "cloud.snow.fill"
        case 75: "wind.snow"
        case 95: "cloud.bolt.fill"
        case 96, 99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }

    static func background(_ code: Int, isDay: Bool) -> [Color] {
        func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r / 255, green: g / 255, blue: b / 255) }
        switch code {
        case 0, 1, 2: return isDay ? [c(52, 120, 200), c(110, 170, 230)] : [c(12, 20, 50), c(35, 50, 100)]
        case 95, 96, 99: return [c(35, 35, 55), c(70, 60, 95)]
        case 71...77, 85, 86: return [c(110, 125, 145), c(170, 185, 200)]
        case 45, 48: return [c(95, 105, 115), c(140, 150, 160)]
        default: return isDay ? [c(80, 95, 115), c(125, 140, 160)] : [c(22, 28, 40), c(45, 55, 75)]
        }
    }
}

// Wind formatting mirrors the app: gusts only when 10+ mph above steady wind, amber at 30+, red at 45+.
enum Wind {
    static func arrow(_ dirFrom: Double) -> String {
        let heading = (dirFrom + 180).truncatingRemainder(dividingBy: 360)
        let arrows = ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]
        return arrows[Int((heading + 22.5) / 45) % 8]
    }

    // Direction the wind is blowing FROM, as a 16-point compass name.
    static func compass(_ dirFrom: Double) -> String {
        let names = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        return names[Int((dirFrom + 11.25).truncatingRemainder(dividingBy: 360) / 22.5)]
    }

    static func gustColor(_ gust: Double) -> Color {
        gust >= 45 ? .red : gust >= 30 ? .orange : .white.opacity(0.85)
    }

    static func showsGust(wind: Double, gust: Double) -> Bool { gust - wind >= 10 }

    static func label(wind: Double, gust: Double, dir: Double) -> String {
        var s = "\(arrow(dir)) \(Int(wind.rounded()))"
        if showsGust(wind: wind, gust: gust) { s += " g\(Int(gust.rounded()))" }
        return s
    }
}
