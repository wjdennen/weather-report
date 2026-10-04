import SwiftUI

// Search by city or US zip, switch between GPS and saved locations, and manage the saved list.
struct LocationsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var searching = false

    var body: some View {
        NavigationStack {
            List {
                if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchResults
                } else {
                    Section {
                        Button {
                            Task { await store.useGPS() }
                            dismiss()
                        } label: { gpsRow }
                        .listRowBackground(rowBackground(active: store.selection == .gps))
                    }
                    if !store.saved.isEmpty {
                        Section("Saved") {
                            ForEach(store.saved) { loc in
                                Button {
                                    Task { await store.select(loc) }
                                    dismiss()
                                } label: { savedRow(loc) }
                                .listRowBackground(rowBackground(active: store.selection == .saved(loc.id)))
                            }
                            .onDelete { store.remove(at: $0) }
                            .onMove { store.move(from: $0, to: $1) }
                        }
                    } else {
                        Section {
                            VStack(spacing: 6) {
                                Text("Explore the horizon").font(.headline)
                                Text("Search any city or zip code to add locations and track weather around the world.")
                                    .font(.footnote).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LinearGradient(colors: [Color(red: 0.06, green: 0.08, blue: 0.1), Color(red: 0.11, green: 0.14, blue: 0.2)],
                                       startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by city or zip code")
            .autocorrectionDisabled()
            .task(id: query) { await runSearch() }
            .navigationTitle("Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { if !store.saved.isEmpty && query.isEmpty { EditButton() } }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder var searchResults: some View {
        if results.isEmpty {
            Section {
                Text(searching ? "Searching…" : "No places found").foregroundStyle(.white.opacity(0.7))
                    .listRowBackground(Color.clear)
            }
        } else {
            Section("Results") {
                ForEach(results) { r in
                    Button {
                        Task { await store.add(r) }
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name).font(.headline)
                                Text(r.subtitle).font(.footnote).foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()
                            Image(systemName: "plus.circle").accessibilityHidden(true)
                        }
                    }
                    .accessibilityHint("Add and show this location")
                    .listRowBackground(rowBackground(active: false))
                }
            }
        }
    }

    var gpsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Current Location").font(.headline)
                Label("GPS", systemImage: "location.fill").font(.caption.weight(.bold)).foregroundStyle(Color(red: 0.56, green: 0.84, blue: 1))
            }
            Spacer()
            if let w = store.weather, store.selection == .gps {
                Text(degrees(w.current.temp)).font(.title2.weight(.light))
            }
        }
        .accessibilityElement(children: .combine)
    }

    func savedRow(_ loc: SavedLocation) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.name).font(.headline)
                if let cond = loc.condition { Text(cond).font(.footnote).foregroundStyle(.white.opacity(0.7)) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(loc.temp.map { "\($0)°" } ?? "—").font(.title2.weight(.light))
                if let hi = loc.hi, let lo = loc.lo { Text("H:\(hi)° L:\(lo)°").font(.caption).foregroundStyle(.white.opacity(0.7)) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    func rowBackground(active: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.white.opacity(active ? 0.2 : 0.1))
    }

    func runSearch() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; searching = false; return }
        searching = true
        try? await Task.sleep(for: .milliseconds(350))   // debounce; cancelled when the query changes
        if Task.isCancelled { return }
        let found = await AppService.search(q)
        if Task.isCancelled { return }
        results = found
        searching = false
    }
}
