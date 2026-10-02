import Foundation

struct Place {
    let name: String
    let lat: Double
    let lon: Double
}

struct Forecast: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let apparent_temperature: Double
        let is_day: Int
        let weather_code: Int
        let wind_speed_10m: Double
        let wind_direction_10m: Double
        let wind_gusts_10m: Double
    }
    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double]
        let weather_code: [Int]
        let precipitation_probability: [Int?]
        let wind_speed_10m: [Double]
        let wind_gusts_10m: [Double]
        let wind_direction_10m: [Double]
    }
    struct Daily: Decodable {
        let time: [String]
        let weather_code: [Int]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let wind_gusts_10m_max: [Double]
        let sunset: [String]
    }
    let utc_offset_seconds: Int
    let current: Current
    let hourly: Hourly
    let daily: Daily
}

struct HourSlice: Identifiable {
    let id: Int
    let date: Date
    let temp: Double
    let code: Int
    let precip: Int
    let wind: Double
    let gust: Double
    let dir: Double
}

struct DaySlice: Identifiable {
    let id: Int
    let date: Date
    let code: Int
    let hi: Double
    let lo: Double
    let gust: Double
}

struct WeatherAlert {
    let event: String
    let severity: String
}

struct TideEvent {
    let date: Date
    let height: Double
}

struct TideInfo {
    let station: String
    let nextHigh: TideEvent?
    let nextLow: TideEvent?
}

struct SunsetQuality: Decodable {
    let quality: Double          // 0...1
    let quality_text: String?
    let cloud_cover: Double?
    let direction: Double?
    var tonight = true           // false once today's sunset has passed (tomorrow's is shown)
    enum CodingKeys: String, CodingKey { case quality, quality_text, cloud_cover, direction }
}

struct WeatherData {
    let place: Place
    let timeZone: TimeZone
    let current: Forecast.Current
    let hours: [HourSlice]
    let days: [DaySlice]
    let alert: WeatherAlert?
    let tides: TideInfo?
    let beach: BeachAdvice?
    let sunset: SunsetQuality?
}

enum WeatherService {
    static let nwsHeaders = ["User-Agent": "(weather-report widget, dennen@gmail.com)", "Accept": "application/geo+json"]

    static func load(query: String) async throws -> WeatherData {
        let place = try await geocode(query)
        async let forecast = fetchForecast(place)
        async let alert = fetchAlert(place)
        async let tides = fetchTides(place)
        let (f, tz) = try await forecast
        let sunset = await fetchSunset(place, f, tz)
        return build(place: place, f: f, tz: tz, alert: await alert, tides: await tides, sunset: sunset)
    }

    // City name via Open-Meteo, or a 5-digit US zip via Zippopotam (same sources as the web app).
    static func geocode(_ raw: String) async throws -> Place {
        let q = raw.trimmingCharacters(in: .whitespaces)
        if q.count == 5, q.allSatisfy(\.isNumber) {
            struct Zip: Decodable {
                struct P: Decodable {
                    let latitude: String
                    let longitude: String
                    let state: String
                    enum CodingKeys: String, CodingKey {
                        case latitude, longitude, state = "state abbreviation"
                        case name = "place name"
                    }
                    let name: String
                    init(from d: Decoder) throws {
                        let c = try d.container(keyedBy: CodingKeys.self)
                        latitude = try c.decode(String.self, forKey: .latitude)
                        longitude = try c.decode(String.self, forKey: .longitude)
                        state = try c.decode(String.self, forKey: .state)
                        name = try c.decode(String.self, forKey: .name)
                    }
                }
                let places: [P]
            }
            let (data, _) = try await URLSession.shared.data(from: URL(string: "https://api.zippopotam.us/us/\(q)")!)
            if let p = try JSONDecoder().decode(Zip.self, from: data).places.first,
               let lat = Double(p.latitude), let lon = Double(p.longitude) {
                return Place(name: "\(p.name), \(p.state)", lat: lat, lon: lon)
            }
        }
        struct Geo: Decodable {
            struct R: Decodable { let name: String; let latitude: Double; let longitude: Double; let admin1: String? }
            let results: [R]?
        }
        var c = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        c.queryItems = [.init(name: "name", value: q), .init(name: "count", value: "1")]
        let (data, _) = try await URLSession.shared.data(from: c.url!)
        guard let r = try JSONDecoder().decode(Geo.self, from: data).results?.first else {
            throw URLError(.cannotFindHost)
        }
        return Place(name: [r.name, r.admin1].compactMap { $0 }.joined(separator: ", "), lat: r.latitude, lon: r.longitude)
    }

    static func fetchForecast(_ p: Place) async throws -> (Forecast, TimeZone) {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            ("latitude", String(format: "%.4f", p.lat)),
            ("longitude", String(format: "%.4f", p.lon)),
            ("current", "temperature_2m,apparent_temperature,is_day,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m"),
            ("hourly", "temperature_2m,weather_code,precipitation_probability,wind_speed_10m,wind_gusts_10m,wind_direction_10m"),
            ("daily", "weather_code,temperature_2m_max,temperature_2m_min,wind_gusts_10m_max,sunset"),
            ("temperature_unit", "fahrenheit"),
            ("wind_speed_unit", "mph"),
            ("timezone", "auto"),
            ("forecast_days", "7"),
        ].map { URLQueryItem(name: $0.0, value: $0.1) }
        let (data, resp) = try await URLSession.shared.data(from: c.url!)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let f = try JSONDecoder().decode(Forecast.self, from: data)
        return (f, TimeZone(secondsFromGMT: f.utc_offset_seconds) ?? .current)
    }

    // NWS alerts are US-only; any failure just means no banner.
    static func fetchAlert(_ p: Place) async -> WeatherAlert? {
        guard let url = URL(string: String(format: "https://api.weather.gov/alerts/active?point=%.4f,%.4f", p.lat, p.lon)) else { return nil }
        var req = URLRequest(url: url)
        nwsHeaders.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        struct A: Decodable {
            struct F: Decodable { struct P: Decodable { let event: String; let severity: String? }; let properties: P }
            let features: [F]
        }
        guard let a = try? JSONDecoder().decode(A.self, from: data) else { return nil }
        let rank = ["Extreme": 4, "Severe": 3, "Moderate": 2, "Minor": 1]
        let top = a.features.max { rank[$0.properties.severity ?? ""] ?? 0 < rank[$1.properties.severity ?? ""] ?? 0 }
        return top.map { WeatherAlert(event: $0.properties.event, severity: $0.properties.severity ?? "") }
    }

    // Sunset quality comes from the web app's Worker proxy (worker/index.js), which holds the Sunsethue
    // API key and caches results; the app itself carries no key. Tonight's sunset, or tomorrow's once
    // today's has passed. Any failure just means no sunset line.
    static let sunsetProxy = "https://weather.dennen.dev/api/sunset"

    static func fetchSunset(_ p: Place, _ f: Forecast, _ tz: TimeZone) async -> SunsetQuality? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = tz
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
        guard let first = f.daily.sunset.first, let sunsetToday = fmt.date(from: first) else { return nil }
        let tonight = Date() <= sunsetToday
        let idx = tonight ? 0 : 1
        guard idx < f.daily.time.count else { return nil }
        var c = URLComponents(string: sunsetProxy)!
        c.queryItems = [
            URLQueryItem(name: "lat", value: String(format: "%.2f", p.lat)),
            URLQueryItem(name: "lon", value: String(format: "%.2f", p.lon)),
            URLQueryItem(name: "date", value: f.daily.time[idx]),
        ]
        guard let (data, resp) = try? await URLSession.shared.data(from: c.url!),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              var q = try? JSONDecoder().decode(SunsetQuality.self, from: data) else { return nil }
        q.tonight = tonight
        return q
    }

    // Nearest NOAA tide station within 150 miles (list bundled from public/stations.json), as in the web app.
    static func nearestStation(to p: Place) -> (id: String, name: String)? {
        guard let url = Bundle.main.url(forResource: "stations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONSerialization.jsonObject(with: data) as? [[Any]] else { return nil }
        func miles(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
            let r = Double.pi / 180
            let a = pow(sin((lat2 - lat1) * r / 2), 2) + cos(lat1 * r) * cos(lat2 * r) * pow(sin((lon2 - lon1) * r / 2), 2)
            return 3958.8 * 2 * asin(min(1, sqrt(a)))
        }
        var best: (id: String, name: String, dist: Double)?
        for s in list {
            guard s.count >= 5, let id = s[0] as? String, let name = s[1] as? String,
                  let lat = (s[3] as? NSNumber)?.doubleValue, let lon = (s[4] as? NSNumber)?.doubleValue else { continue }
            let d = miles(p.lat, p.lon, lat, lon)
            if d < (best?.dist ?? .infinity) { best = (id, name, d) }
        }
        guard let b = best, b.dist <= 150 else { return nil }
        return (b.id, b.name)
    }

    // High/low predictions in GMT so the instants are exact regardless of station time zone.
    static func fetchTides(_ p: Place) async -> TideInfo? {
        guard let st = nearestStation(to: p) else { return nil }
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = TimeZone(identifier: "GMT")
        day.dateFormat = "yyyyMMdd"
        var c = URLComponents(string: "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter")!
        c.queryItems = [
            ("begin_date", day.string(from: Date())),
            ("end_date", day.string(from: Date().addingTimeInterval(2 * 86400))),
            ("station", st.id), ("product", "predictions"), ("datum", "MLLW"),
            ("time_zone", "gmt"), ("units", "english"), ("interval", "hilo"),
            ("application", "WeatherReportWidget"), ("format", "json"),
        ].map { URLQueryItem(name: $0.0, value: $0.1) }
        struct R: Decodable { struct P: Decodable { let t: String; let v: String; let type: String }; let predictions: [P]? }
        guard let (data, _) = try? await URLSession.shared.data(from: c.url!),
              let preds = (try? JSONDecoder().decode(R.self, from: data))?.predictions else { return nil }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "GMT")
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        let now = Date()
        let events: [(TideEvent, String)] = preds.compactMap { p in
            guard let d = fmt.date(from: p.t), d > now, let v = Double(p.v) else { return nil }
            return (TideEvent(date: d, height: v), p.type)
        }
        return TideInfo(station: st.name,
                        nextHigh: events.first { $0.1 == "H" }?.0,
                        nextLow: events.first { $0.1 == "L" }?.0)
    }

    static func build(place: Place, f: Forecast, tz: TimeZone, alert: WeatherAlert?, tides: TideInfo?, sunset: SunsetQuality?) -> WeatherData {
        let hourFmt = DateFormatter()
        hourFmt.locale = Locale(identifier: "en_US_POSIX")
        hourFmt.timeZone = tz
        hourFmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let dayFmt = DateFormatter()
        dayFmt.locale = hourFmt.locale
        dayFmt.timeZone = tz
        dayFmt.dateFormat = "yyyy-MM-dd"

        let now = Date()
        let h = f.hourly
        let hours: [HourSlice] = h.time.indices.compactMap { i in
            guard let d = hourFmt.date(from: h.time[i]), d > now.addingTimeInterval(-3600) else { return nil }
            return HourSlice(id: i, date: d, temp: h.temperature_2m[i], code: h.weather_code[i],
                             precip: h.precipitation_probability[i] ?? 0, wind: h.wind_speed_10m[i],
                             gust: h.wind_gusts_10m[i], dir: h.wind_direction_10m[i])
        }
        let dd = f.daily
        let days: [DaySlice] = dd.time.indices.compactMap { i in
            guard let d = dayFmt.date(from: dd.time[i]) else { return nil }
            return DaySlice(id: i, date: d, code: dd.weather_code[i], hi: dd.temperature_2m_max[i],
                            lo: dd.temperature_2m_min[i], gust: dd.wind_gusts_10m_max[i])
        }
        return WeatherData(place: place, timeZone: tz, current: f.current, hours: hours, days: days, alert: alert, tides: tides,
                           beach: BeachAdvisor.advice(place: place, hours: hours), sunset: sunset)
    }
}
