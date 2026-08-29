import Combine
import MapKit

struct CitySearchSuggestion: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    fileprivate let completion: MKLocalSearchCompletion
}

struct CitySearchResult: Identifiable, Equatable {
    let id: UUID
    let name: String
    let countryName: String
    let regionName: String?
    let latitude: Double
    let longitude: Double

    init(
        id: UUID = UUID(),
        name: String,
        countryName: String,
        regionName: String?,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.name = name
        self.countryName = countryName
        self.regionName = regionName
        self.latitude = latitude
        self.longitude = longitude
    }
}

enum CitySearchError: LocalizedError {
    case noCityResult

    var errorDescription: String? {
        "MapKit could not identify a city for this result. Try a more specific search."
    }
}

@MainActor
final class CitySearchService: NSObject, ObservableObject, @preconcurrency MKLocalSearchCompleterDelegate {
    @Published private(set) var suggestions: [CitySearchSuggestion] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address]
    }

    func updateQuery(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil

        guard !trimmedQuery.isEmpty else {
            completer.cancel()
            suggestions = []
            isLoading = false
            return
        }

        isLoading = true
        completer.queryFragment = trimmedQuery
    }

    func resolve(_ suggestion: CitySearchSuggestion) async throws -> CitySearchResult {
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        request.resultTypes = [.address]
        let response = try await MKLocalSearch(request: request).start()

        guard let mapItem = response.mapItems.first(where: {
            $0.placemark.locality != nil && $0.placemark.country != nil
        }),
        let cityName = mapItem.placemark.locality,
        let countryName = mapItem.placemark.country else {
            throw CitySearchError.noCityResult
        }

        return CitySearchResult(
            name: cityName,
            countryName: countryName,
            regionName: mapItem.placemark.administrativeArea,
            latitude: mapItem.placemark.coordinate.latitude,
            longitude: mapItem.placemark.coordinate.longitude
        )
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results.enumerated().map { index, completion in
            CitySearchSuggestion(
                id: "\(index):\(completion.title):\(completion.subtitle)",
                title: completion.title,
                subtitle: completion.subtitle,
                completion: completion
            )
        }
        isLoading = false
        errorMessage = nil
    }

    func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: Error
    ) {
        suggestions = []
        isLoading = false
        errorMessage = "City search is unavailable. Check your connection and try again."
    }
}
