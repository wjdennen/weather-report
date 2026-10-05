import CoreLocation
import Foundation

// Network layer for the app screen. Reuses the widget's WeatherService for the tide station lookup and
// sunset proxy URL; everything else needs more fields than the widget fetches.
enum AppService {
    struct APIError: LocalizedError {
        let errorDescription: String?
    }

    // MARK: Load everything for a place

    static func load(_ place: Place) async throws -> AppWeather {
        async let forecast = fetchForecast(place)
        async let nws = fetchNWSPeriods(place)
        async let alerts = fetchAlerts(place)
        async let tides = fetchTides(place)
        let (f, tz) = try await forecast
        let sunset = await fetchSunset(place, f, tz)
        let (periods, periodsFailed) = await nws
        return build(place: place, f: f, tz: tz, periods: periods, periodsFailed: periodsFailed,
                     alerts: await alerts, tides: await tides, sunset: sunset)
    }

    static func timeParser(_ tz: TimeZone, _ format: String) -> DateFormatter {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = tz
        fmt.dateFormat = format
        return fmt
    }

    // MARK: Open-Meteo

    static func fetchForecast(_ p: Place) async throws -> (FullForecast, TimeZone) {
        #if DEBUG
        // Screenshot/test helper: SIMCTL_CHILD_FAIL_WEATHER=1 makes the weather request fail.
        if ProcessInfo.processInfo.environment["FAIL_WEATHER"] != nil { throw APIError(errorDescription: "forced failure") }
        #endif
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            ("latitude", String(format: "%.4f", p.lat)),
            ("longitude", String(format: "%.4f", p.lon)),
            ("current", "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation,visibility"),
            ("hourly", "temperature_2m,weather_code,precipitation_probability,precipitation,wind_speed_10m,wind_gusts_10m,wind_direction_10m"),
            ("daily", "weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant,uv_index_max,sunrise,sunset"),
            ("temperature_unit", "fahrenheit"),
            ("wind_speed_unit", "mph"),
            ("precipitation_unit", "inch"),
            ("timezone", "auto"),
            ("forecast_days", "8"),
        ].map { URLQueryItem(name: $0.0, value: $0.1) }
        let (data, resp) = try await URLSession.shared.data(from: c.url!)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw APIError(errorDescription: "Weather data unavailable") }
        let f = try JSONDecoder().decode(FullForecast.self, from: data)
        return (f, TimeZone(secondsFromGMT: f.utc_offset_seconds) ?? .current)
    }

    // MARK: NWS (US only; any failure just means no detail text or alerts)

    static func nwsRequest(_ url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue("(weather-report app, dennen@gmail.com)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        return req
    }

    static let isoDate: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    enum NWSFetch { case ok(Data), unavailable, failed }

    // api.weather.gov is flaky: retry transient failures (network error, 429, 5xx) a couple of times.
    // Any other status (e.g. 404 outside the US) is final and means "no data", not "failed".
    static func nwsFetch(_ url: URL) async -> NWSFetch {
        for attempt in 0..<3 {
            if attempt > 0 {
                try? await Task.sleep(for: .milliseconds(700 * attempt))
                if Task.isCancelled { return .failed }
            }
            guard let (data, resp) = try? await URLSession.shared.data(for: nwsRequest(url)),
                  let code = (resp as? HTTPURLResponse)?.statusCode else { continue }
            if code == 200 { return .ok(data) }
            if code == 429 || code >= 500 { continue }
            return .unavailable
        }
        return .failed
    }

    // `failed` is true only when NWS should have had a forecast but we couldn't get one, so the UI can offer a retry.
    static func fetchNWSPeriods(_ p: Place) async -> (periods: [NWSPeriod], failed: Bool) {
        guard let pointsURL = URL(string: String(format: "https://api.weather.gov/points/%.4f,%.4f", p.lat, p.lon)) else { return ([], false) }
        let pd: Data
        switch await nwsFetch(pointsURL) {
        case .ok(let d): pd = d
        case .unavailable: return ([], false)
        case .failed: return ([], true)
        }
        struct Points: Decodable { struct P: Decodable { let forecast: String? }; let properties: P }
        guard let urlString = (try? JSONDecoder().decode(Points.self, from: pd))?.properties.forecast,
              let url = URL(string: urlString) else { return ([], false) }
        let fd: Data
        switch await nwsFetch(url) {
        case .ok(let d): fd = d
        case .unavailable: return ([], false)
        case .failed: return ([], true)
        }
        struct FC: Decodable {
            struct P: Decodable {
                let name: String
                let startTime: String
                let endTime: String
                let isDaytime: Bool
                let shortForecast: String
                let detailedForecast: String
            }
            struct Props: Decodable { let periods: [P] }
            let properties: Props
        }
        guard let fc = try? JSONDecoder().decode(FC.self, from: fd) else { return ([], true) }
        let periods: [NWSPeriod] = fc.properties.periods.compactMap { p in
            guard let s = isoDate.date(from: p.startTime), let e = isoDate.date(from: p.endTime) else { return nil }
            return NWSPeriod(name: p.name, start: s, end: e, isDaytime: p.isDaytime,
                             shortForecast: p.shortForecast, detailedForecast: p.detailedForecast)
        }
        return (periods, false)
    }

    static func fetchAlerts(_ p: Place) async -> [NWSAlert] {
        guard let url = URL(string: String(format: "https://api.weather.gov/alerts/active?point=%.4f,%.4f", p.lat, p.lon)),
              let (data, resp) = try? await URLSession.shared.data(for: nwsRequest(url)),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        struct A: Decodable {
            struct F: Decodable {
                struct P: Decodable {
                    let id: String?
                    let event: String?
                    let severity: String?
                    let headline: String?
                    let description: String?
                    let ends: String?
                    let expires: String?
                }
                let properties: P
            }
            let features: [F]
        }
        guard let a = try? JSONDecoder().decode(A.self, from: data) else { return [] }
        return a.features.compactMap { f in
            let p = f.properties
            guard let event = p.event else { return nil }
            // NWS `ends` is when the hazard ends; `expires` is just when the message does.
            let end = (p.ends ?? p.expires).flatMap { isoDate.date(from: $0) }
            return NWSAlert(id: p.id ?? event, event: event, severity: p.severity ?? "",
                            headline: p.headline ?? "", description: p.description ?? "", ends: end)
        }
    }

    // MARK: Tides

    static func fetchTides(_ p: Place) async -> TideData? {
        guard let st = WeatherService.nearestStation(to: p) else { return nil }
        let day = timeParser(TimeZone(identifier: "GMT")!, "yyyyMMdd")
        var c = URLComponents(string: "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter")!
        c.queryItems = [
            ("begin_date", day.string(from: Date().addingTimeInterval(-86400))),
            ("end_date", day.string(from: Date().addingTimeInterval(3 * 86400))),
            ("station", st.id), ("product", "predictions"), ("datum", "MLLW"),
            ("time_zone", "gmt"), ("units", "english"), ("interval", "hilo"),
            ("application", "WeatherReport"), ("format", "json"),
        ].map { URLQueryItem(name: $0.0, value: $0.1) }
        struct R: Decodable { struct P: Decodable { let t: String; let v: String; let type: String }; let predictions: [P]? }
        guard let (data, _) = try? await URLSession.shared.data(from: c.url!),
              let preds = (try? JSONDecoder().decode(R.self, from: data))?.predictions else { return nil }
        let fmt = timeParser(TimeZone(identifier: "GMT")!, "yyyy-MM-dd HH:mm")
        let events: [TideEvent] = preds.compactMap { p in
            guard let d = fmt.date(from: p.t), let v = Double(p.v) else { return nil }
            return TideEvent(date: d, height: v, isHigh: p.type == "H")
        }.sorted { $0.date < $1.date }
        return events.count >= 2 ? TideData(stationName: st.name, events: events) : nil
    }

    // MARK: Sunset quality (via the web app's Worker proxy, which holds the API key)

    static func fetchSunset(_ p: Place, _ f: FullForecast, _ tz: TimeZone) async -> SunsetQuality? {
        let fmt = timeParser(tz, "yyyy-MM-dd'T'HH:mm")
        guard let first = f.daily.sunset.first, let sunsetToday = fmt.date(from: first) else { return nil }
        let tonight = Date() <= sunsetToday
        let idx = tonight ? 0 : 1
        guard idx < f.daily.time.count else { return nil }
        var c = URLComponents(string: WeatherService.sunsetProxy)!
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

    // MARK: Build

    static func build(place: Place, f: FullForecast, tz: TimeZone, periods: [NWSPeriod], periodsFailed: Bool,
                      alerts: [NWSAlert], tides: TideData?, sunset: SunsetQuality?) -> AppWeather {
        let minuteFmt = timeParser(tz, "yyyy-MM-dd'T'HH:mm")
        let dayFmt = timeParser(tz, "yyyy-MM-dd")
        let now = Date()
        let h = f.hourly

        // The next 24 hours, starting with the hour we're in.
        var chips: [HourChip] = []
        for i in h.time.indices {
            guard let d = minuteFmt.date(from: h.time[i]), d > now.addingTimeInterval(-3600) else { continue }
            guard let temp = h.temperature_2m[i] else { continue }
            chips.append(HourChip(id: i, date: d, temp: temp, code: h.weather_code[i] ?? 3,
                                  precipChance: h.precipitation_probability[i] ?? 0,
                                  precipAmount: h.precipitation[i] ?? 0,
                                  wind: h.wind_speed_10m[i] ?? 0, gust: h.wind_gusts_10m[i] ?? 0,
                                  dir: h.wind_direction_10m[i] ?? 0))
            if chips.count == 24 { break }
        }

        let d = f.daily
        var days: [DayRow] = []
        for i in d.time.indices {
            guard let date = dayFmt.date(from: d.time[i]),
                  let hi = d.temperature_2m_max[i], let lo = d.temperature_2m_min[i],
                  let sr = minuteFmt.date(from: d.sunrise[i]), let ss = minuteFmt.date(from: d.sunset[i]) else { continue }
            days.append(DayRow(id: d.time[i], date: date, code: d.weather_code[i] ?? 3, hi: hi, lo: lo,
                               wind: d.wind_speed_10m_max[i] ?? 0, gust: d.wind_gusts_10m_max[i] ?? 0,
                               dir: d.wind_direction_10m_dominant[i] ?? 0, uv: d.uv_index_max[i] ?? 0,
                               precipSum: d.precipitation_sum[i] ?? 0, sunrise: sr, sunset: ss))
        }

        let c = f.current
        let current = CurrentConditions(temp: c.temperature_2m, feelsLike: c.apparent_temperature,
                                        humidity: c.relative_humidity_2m, isDay: c.is_day == 1,
                                        code: c.weather_code, wind: c.wind_speed_10m, windDir: c.wind_direction_10m,
                                        gust: c.wind_gusts_10m, precipToday: c.precipitation ?? 0,
                                        visibilityMiles: c.visibility.map { $0 / 1609.34 })

        let beachHours = chips.map { HourSlice(id: $0.id, date: $0.date, temp: $0.temp, code: $0.code, precip: $0.precipChance,
                                               wind: $0.wind, gust: $0.gust, dir: $0.dir) }
        return AppWeather(place: place, tz: tz, fetched: now, current: current, hours: chips, days: days,
                          alerts: alerts.sorted { severityRank($0.severity) > severityRank($1.severity) },
                          periods: periods, periodsFailed: periodsFailed, tides: tides, sunset: sunset,
                          beach: BeachAdvisor.advice(place: place, hours: beachHours))
    }

    static func severityRank(_ s: String) -> Int {
        ["Extreme": 4, "Severe": 3, "Moderate": 2, "Minor": 1][s] ?? 0
    }

    // MARK: Search & reverse geocoding

    static func search(_ raw: String) async -> [SearchResult] {
        let q = raw.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }

        if q.count == 5, q.allSatisfy(\.isNumber),
           let (data, resp) = try? await URLSession.shared.data(from: URL(string: "https://api.zippopotam.us/us/\(q)")!),
           (resp as? HTTPURLResponse)?.statusCode == 200 {
            struct Zip: Decodable {
                struct P: Decodable {
                    let name: String, state: String, latitude: String, longitude: String
                    enum CodingKeys: String, CodingKey {
                        case name = "place name", state, latitude, longitude
                    }
                }
                let places: [P]
            }
            if let p = (try? JSONDecoder().decode(Zip.self, from: data))?.places.first,
               let lat = Double(p.latitude), let lon = Double(p.longitude) {
                return [SearchResult(name: p.name, admin1: p.state, country: "United States", countryCode: "US", latitude: lat, longitude: lon)]
            }
        }

        // Open-Meteo doesn't handle "City, State": search on the part before the comma.
        let name = q.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? q
        var c = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        c.queryItems = [.init(name: "name", value: name), .init(name: "count", value: "8"),
                        .init(name: "language", value: "en"), .init(name: "format", value: "json")]
        guard let (data, _) = try? await URLSession.shared.data(from: c.url!) else { return [] }
        struct Geo: Decodable {
            struct R: Decodable {
                let name: String
                let latitude: Double
                let longitude: Double
                let admin1: String?
                let country: String?
                let country_code: String?
            }
            let results: [R]?
        }
        return ((try? JSONDecoder().decode(Geo.self, from: data))?.results ?? []).map {
            SearchResult(name: $0.name, admin1: $0.admin1, country: $0.country, countryCode: $0.country_code,
                         latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    // Apple's geocoder; no third-party service involved. "City, ST" in the US, otherwise just the city.
    static func reverseGeocode(_ loc: CLLocation) async -> (name: String, region: String)? {
        guard let mark = try? await CLGeocoder().reverseGeocodeLocation(loc).first else { return nil }
        guard let city = mark.locality ?? mark.subAdministrativeArea ?? mark.administrativeArea else { return nil }
        let region = mark.isoCountryCode == "US" ? (mark.administrativeArea ?? "") : (mark.country ?? "")
        return (mark.isoCountryCode == "US" && !region.isEmpty ? "\(city), \(region)" : city, region)
    }
}
