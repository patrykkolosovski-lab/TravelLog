import Foundation

enum TravelContinent: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case africa = "Africa"
    case asia = "Asia"
    case europe = "Europe"
    case northAmerica = "North America"
    case southAmerica = "South America"
    case oceania = "Oceania"

    var id: String { rawValue }
}

enum FlagSymbol {
    static func make(from code: String?) -> String {
        guard let code, code.count == 2 else { return "" }
        return code.uppercased().unicodeScalars.compactMap { scalar in
            UnicodeScalar(127_397 + scalar.value).map(String.init)
        }.joined()
    }
}

struct StatisticsLocationSummary: Identifiable, Equatable {
    let id: UUID
    let name: String
    let kind: LocationKind
    let countryName: String?
    let isVisited: Bool
    let visitYear: Int?
    let rating: Int?
    let continent: TravelContinent?
    let flagCode: String?

    var flag: String {
        FlagSymbol.make(from: flagCode)
    }
}

struct VisitYearGroup: Identifiable, Equatable {
    let year: Int
    let locations: [StatisticsLocationSummary]
    var id: Int { year }
    var count: Int { locations.count }
}

struct ContinentCoverage: Identifiable, Equatable {
    let continent: TravelContinent
    let visited: Int
    let total: Int
    var id: TravelContinent { continent }
    var percentage: Double { total == 0 ? 0 : Double(visited) / Double(total) }
}

struct TravelStatistics: Equatable {
    let visitedCountries: [StatisticsLocationSummary]
    let visitedTerritories: [StatisticsLocationSummary]
    let loggedCities: [StatisticsLocationSummary]
    let visitedContinents: [TravelContinent]
    let locationsByYear: [VisitYearGroup]
    let continentCoverage: [ContinentCoverage]
    let ratedLocations: [StatisticsLocationSummary]

    var visitedCountryCount: Int { visitedCountries.count }
    var visitedTerritoryCount: Int { visitedTerritories.count }
    var cityCount: Int { loggedCities.count }
    var continentCount: Int { visitedContinents.count }

    var combinedCoverage: Double {
        Double(visitedCountryCount + visitedTerritoryCount) / 210.0
    }

    var isEmpty: Bool {
        visitedCountries.isEmpty
            && visitedTerritories.isEmpty
            && loggedCities.isEmpty
            && ratedLocations.isEmpty
    }

    func filteredRatings(
        continent: TravelContinent?,
        includedKinds: Set<LocationKind>
    ) -> [StatisticsLocationSummary] {
        ratedLocations.filter { location in
            includedKinds.contains(location.kind)
                && (continent == nil || location.continent == continent)
        }
    }

    func averageRating(
        continent: TravelContinent?,
        includedKinds: Set<LocationKind>
    ) -> Double? {
        let ratings = filteredRatings(
            continent: continent,
            includedKinds: includedKinds
        ).compactMap(\.rating)
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }
}

enum TravelStatisticsService {
    static func calculate(
        from locations: [TravelLocation],
        references: [ReferenceLocation]
    ) -> TravelStatistics {
        let referencesByIdentifier = Dictionary(
            uniqueKeysWithValues: references.map { ($0.stableIdentifier, $0) }
        )
        var referencesByName: [String: ReferenceLocation] = [:]
        for reference in references {
            referencesByName[normalized(reference.displayName)] = reference
            guard let flagCode = reference.flagCode else { continue }
            for locale in [Locale(identifier: "en_US"), Locale.current] {
                if let localizedName = locale.localizedString(forRegionCode: flagCode) {
                    referencesByName[normalized(localizedName)] = reference
                }
            }
        }

        let summaries = locations.map { location in
            let reference = location.referenceIdentifier.flatMap { referencesByIdentifier[$0] }
            let cityCountry = location.countryName.flatMap { referencesByName[normalized($0)] }
            let metadataReference = reference ?? cityCountry
            return StatisticsLocationSummary(
                id: location.id,
                name: location.name,
                kind: location.kind,
                countryName: location.countryName,
                isVisited: location.isVisited,
                visitYear: location.visitYear,
                rating: location.rating,
                continent: metadataReference?.continent,
                flagCode: metadataReference?.flagCode
            )
        }

        let visitedCountries = sorted(summaries.filter {
            $0.kind == .country && $0.isVisited
        })
        let visitedTerritories = sorted(summaries.filter {
            $0.kind == .territory && $0.isVisited
        })
        let loggedCities = sorted(summaries.filter { $0.kind == .city })
        let visitedContinents = Set(
            summaries.filter(\.isVisited).compactMap(\.continent)
        ).sorted { continentOrder($0) < continentOrder($1) }

        let locationsByYear = Dictionary(
            grouping: summaries.filter { $0.isVisited && $0.visitYear != nil },
            by: { $0.visitYear! }
        ).map { year, yearLocations in
            VisitYearGroup(year: year, locations: sorted(yearLocations))
        }.sorted { $0.year > $1.year }

        let visitedReferenceIdentifiers = Set(
            locations.filter(\.isVisited).compactMap(\.referenceIdentifier)
        )
        let continentCoverage = TravelContinent.allCases.map { continent in
            let continentReferences = references.filter { $0.continent == continent }
            return ContinentCoverage(
                continent: continent,
                visited: continentReferences.filter {
                    visitedReferenceIdentifiers.contains($0.stableIdentifier)
                }.count,
                total: continentReferences.count
            )
        }

        let ratedLocations = summaries.filter { $0.rating != nil }.sorted {
            if $0.rating == $1.rating {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return ($0.rating ?? 0) > ($1.rating ?? 0)
        }

        return TravelStatistics(
            visitedCountries: visitedCountries,
            visitedTerritories: visitedTerritories,
            loggedCities: loggedCities,
            visitedContinents: visitedContinents,
            locationsByYear: locationsByYear,
            continentCoverage: continentCoverage,
            ratedLocations: ratedLocations
        )
    }

    private static func sorted(
        _ locations: [StatisticsLocationSummary]
    ) -> [StatisticsLocationSummary] {
        locations.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func continentOrder(_ continent: TravelContinent) -> Int {
        TravelContinent.allCases.firstIndex(of: continent) ?? .max
    }
}
