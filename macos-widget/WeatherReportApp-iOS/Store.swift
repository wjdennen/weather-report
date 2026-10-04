import CoreLocation
import Foundation
import Observation

// One-shot "where am I" request wrapped in async/await.
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    enum Failure: LocalizedError {
        case denied, unavailable
        var errorDescription: String? {
            switch self {
            case .denied: "Location access is off. Turn it on in Settings, or search for a place."
            case .unavailable: "Couldn't find your location. Try again, or search for a place."
            }
        }
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func current() async throws -> CLLocation {
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted { throw Failure.denied }
        continuation?.resume(throwing: Failure.unavailable) // a newer request supersedes an unfinished one
        continuation = nil
        return try await withCheckedThrowingContinuation { c in
            continuation = c
            if manager.authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        guard let c = continuation else { return }
        continuation = nil
        c.resume(with: result)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        case .denied, .restricted: finish(.failure(Failure.denied))
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let l = locations.last { finish(.success(l)) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(.failure((error as? CLError)?.code == .denied ? Failure.denied : Failure.unavailable))
    }
}

@Observable @MainActor
final class Store {
    enum Phase {
        case idle, loading
        case failed(String)
        case loaded
    }

    enum Selection: Equatable {
        case gps
        case saved(String)   // SavedLocation.id
    }

    private(set) var saved: [SavedLocation] = [] {
        didSet { persistSaved() }
    }
    private(set) var selection: Selection = .gps
    private(set) var phase: Phase = .idle
    private(set) var weather: AppWeather?
    private(set) var gpsPlace: Place?            // last resolved GPS location, shown in the list
    private(set) var title = "Weather Report"

    private let locator = LocationProvider()
    private var generation = 0                   // stale responses from a previous selection are dropped
    private let defaults = UserDefaults.standard

    init() {
        if let data = defaults.data(forKey: "saved_locations_v1"),
           let list = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            saved = list
        }
    }

    // MARK: Launch / refresh

    // Like the web app: with a saved location, open it straight away; otherwise ask for GPS.
    func start() async {
        if let lastID = defaults.string(forKey: "last_selection"), lastID != "gps",
           let loc = saved.first(where: { $0.id == lastID }) ?? saved.first {
            await select(loc)
        } else if let first = saved.first, defaults.string(forKey: "last_selection") == nil {
            await select(first)
        } else {
            await useGPS()
        }
    }

    func refresh() async {
        switch selection {
        case .gps: await useGPS(keepContent: true)
        case .saved(let id):
            if let loc = saved.first(where: { $0.id == id }) { await select(loc, keepContent: true) }
        }
    }

    // MARK: Selection

    func useGPS(keepContent: Bool = false) async {
        generation += 1
        let gen = generation
        selection = .gps
        defaults.set("gps", forKey: "last_selection")
        if !keepContent { weather = nil; title = "Locating…" }
        phase = .loading
        do {
            let loc = try await locator.current()
            let named = await AppService.reverseGeocode(loc)
            guard gen == generation else { return }
            let place = Place(name: named?.name ?? "Current Location", lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
            gpsPlace = place
            title = place.name
            await fetch(place, gen: gen)
        } catch {
            guard gen == generation else { return }
            weather = keepContent ? weather : nil
            title = "Weather Report"
            phase = .failed(error.localizedDescription)
        }
    }

    func select(_ loc: SavedLocation, keepContent: Bool = false) async {
        generation += 1
        let gen = generation
        selection = .saved(loc.id)
        defaults.set(loc.id, forKey: "last_selection")
        if !keepContent { weather = nil }
        title = loc.displayName
        phase = .loading
        await fetch(loc.place, gen: gen)
    }

    // Add (or reuse) a saved location from a search result and open it.
    func add(_ r: SearchResult) async {
        let region = r.admin1 ?? r.countryCode ?? ""
        let loc = SavedLocation(name: r.name, region: region, lat: r.latitude, lon: r.longitude)
        if !saved.contains(where: { $0.id == loc.id }) { saved.append(loc) }
        await select(saved.first { $0.id == loc.id } ?? loc)
    }

    func remove(at offsets: IndexSet) {
        let removing = offsets.map { saved[$0].id }
        saved.remove(atOffsets: offsets)
        if case .saved(let id) = selection, removing.contains(id) {
            defaults.removeObject(forKey: "last_selection")
            Task { await start() }
        }
    }

    func move(from: IndexSet, to: Int) { saved.move(fromOffsets: from, toOffset: to) }

    // MARK: Fetch

    private func fetch(_ place: Place, gen: Int) async {
        do {
            let w = try await AppService.load(place)
            guard gen == generation else { return }
            weather = w
            phase = .loaded
            remember(w)
        } catch {
            guard gen == generation else { return }
            phase = .failed(weather == nil ? "Could not load weather. Check your connection."
                                           : "Couldn't refresh. Showing the last data.")
        }
    }

    // Keep the saved-location list's temperatures current for whichever location just loaded.
    private func remember(_ w: AppWeather) {
        guard let i = saved.firstIndex(where: { $0.id == "\(w.place.lat)_\(w.place.lon)" }) else { return }
        var loc = saved[i]
        loc.temp = Int(w.current.temp.rounded())
        loc.condition = WMO.text(w.current.code)
        loc.hi = w.days.first.map { Int($0.hi.rounded()) }
        loc.lo = w.days.first.map { Int($0.lo.rounded()) }
        if loc != saved[i] { saved[i] = loc }
    }

    private func persistSaved() {
        if let data = try? JSONEncoder().encode(saved) { defaults.set(data, forKey: "saved_locations_v1") }
    }
}
