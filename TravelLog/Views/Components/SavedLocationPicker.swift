import SwiftUI

struct SavedLocationPicker: View {
    let locations: [TravelLocation]
    @Binding var selection: UUID?

    @State private var searchText = ""

    private var filteredLocations: [TravelLocation] {
        locations
            .filter {
                searchText.isEmpty
                    || $0.name.localizedCaseInsensitiveContains(searchText)
                    || ($0.countryName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 10) {
            TextField("Search saved locations", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if locations.isEmpty {
                ContentUnavailableView(
                    "No saved locations",
                    systemImage: "map",
                    description: Text("Save a country, territory, or city first.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredLocations.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredLocations, selection: $selection) { location in
                    HStack(spacing: 9) {
                        Image(systemName: symbol(for: location.kind))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.name)
                            if let countryName = location.countryName {
                                Text(countryName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tag(location.id)
                }
                .listStyle(.inset)
            }
        }
    }

    private func symbol(for kind: LocationKind) -> String {
        switch kind {
        case .country: "globe.europe.africa"
        case .territory: "map"
        case .city: "building.2"
        }
    }
}
