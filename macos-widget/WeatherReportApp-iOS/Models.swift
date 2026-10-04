import Foundation

// MARK: - Open-Meteo response (fields the app screen needs; the widget's Forecast has fewer)

struct FullForecast: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let relative_humidity_2m: Double?
        let apparent_temperature: Double
        let is_day: Int
        let weather_code: Int
        let wind_speed_10m: Double
        let wind_direction_10m: Double
        let wind_gusts_10m: Double
        let precipitation: Double?
        let visibility: Double?          // meters
    }
    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double?]
        let weather_code: [Int?]
        let precipitation_probability: [Int?]
        let precipitation: [Double?]
        let wind_speed_10m: [Double?]
        let wind_gusts_10m: [Double?]
        let wind_direction_10m: [Double?]
    }
    struct Daily: Decodable {
        let time: [String]
        let weather_code: [Int?]
        let temperature_2m_max: [Double?]
        let temperature_2m_min: [Double?]
        let precipitation_sum: [Double?]
        let wind_speed_10m_max: [Double?]
        let wind_gusts_10m_max: [Double?]
        let wind_direction_10m_dominant: [Double?]
        let uv_index_max: [Double?]
        let sunrise: [String]
        let sunset: [String]
    }
    let utc_offset_seconds: Int
    let current: Current
    let hourly: Hourly
    let daily: Daily
}

// MARK: - App-facing models

struct HourChip: Identifiable {
    let id: Int
    let date: Date
    let temp: Double
    let code: Int
    let precipChance: Int
    let precipAmount: Double
    let wind: Double
    let gust: Double
    let dir: Double
}

struct DayRow: Identifiable {
    let id: String               // yyyy-MM-dd in the location's time zone
    let date: Date
    let code: Int
    let hi: Double
    let lo: Double
    let wind: Double
    let gust: Double
    let dir: Double
    let uv: Double
    let precipSum: Double
    let sunrise: Date
    let sunset: Date
}

struct NWSPeriod: Identifiable {
    var id: String { name + start.description }
    let name: String
    let start: Date
    let end: Date
    let isDaytime: Bool
    let shortForecast: String
    let detailedForecast: String
}

struct NWSAlert: Identifiable {
    let id: String
    let event: String
    let severity: String
    let headline: String
    let description: String
    let ends: Date?
}

struct TideData {
    let stationName: String
    let events: [TideEvent]      // yesterday through the day after tomorrow
}

struct CurrentConditions {
    let temp: Double
    let feelsLike: Double
    let humidity: Double?
    let isDay: Bool
    let code: Int
    let wind: Double
    let windDir: Double
    let gust: Double
    let precipToday: Double
    let visibilityMiles: Double?
}

struct AppWeather {
    let place: Place
    let tz: TimeZone
    let fetched: Date
    let current: CurrentConditions
    let hours: [HourChip]
    let days: [DayRow]
    let alerts: [NWSAlert]
    let periods: [NWSPeriod]
    let tides: TideData?
    let sunset: SunsetQuality?
    let beach: BeachAdvice?

    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        return c
    }
}

// MARK: - Saved locations

struct SavedLocation: Codable, Identifiable, Equatable {
    var id: String { "\(lat)_\(lon)" }
    var name: String
    var region: String
    var lat: Double
    var lon: Double
    // Last-seen conditions, so the list can show a temperature before reloading.
    var temp: Int?
    var condition: String?
    var hi: Int?
    var lo: Int?

    var place: Place { Place(name: name, lat: lat, lon: lon) }
}

struct SearchResult: Identifiable {
    var id: String { "\(latitude)_\(longitude)" }
    let name: String
    let admin1: String?
    let country: String?
    let countryCode: String?
    let latitude: Double
    let longitude: Double

    var subtitle: String { [admin1, countryCode].compactMap { $0 }.joined(separator: ", ") }
}
