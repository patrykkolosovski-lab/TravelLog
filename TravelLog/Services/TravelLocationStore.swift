import Foundation
import SwiftData

enum TravelLocationStoreError: LocalizedError, Equatable {
    case duplicateReferenceLocation
    case duplicateCity

    var errorDescription: String? {
        switch self {
        case .duplicateReferenceLocation:
            "This country or territory is already saved."
        case .duplicateCity:
            "This city appears to be already saved."
        }
    }
}

@MainActor
enum TravelLocationStore {
    static func saveReferenceLocation(
        _ reference: ReferenceLocation,
        isVisited: Bool,
        visitYear: Int?,
        rating: Int?,
        in context: ModelContext
    ) throws -> TravelLocation {
        let identifier = reference.stableIdentifier
        let matches = try context.fetch(
            FetchDescriptor<TravelLocation>(
                predicate: #Predicate { $0.referenceIdentifier == identifier }
            )
        )
        guard matches.count < 2 else {
            throw TravelLocationStoreError.duplicateReferenceLocation
        }

        let kind: LocationKind = reference.category == .country ? .country : .territory
        let location = matches.first ?? TravelLocation(
            referenceIdentifier: identifier,
            name: reference.displayName,
            kind: kind
        )
        try location.update(
            referenceIdentifier: identifier,
            name: reference.displayName,
            kind: kind,
            countryName: nil,
            isVisited: isVisited,
            visitYear: visitYear,
            rating: rating,
            latitude: nil,
            longitude: nil
        )
        try save(location, in: context)
        return location
    }

    static func saveCity(
        existing location: TravelLocation? = nil,
        name: String,
        countryName: String,
        isVisited: Bool,
        visitYear: Int?,
        rating: Int?,
        latitude: Double,
        longitude: Double,
        in context: ModelContext
    ) throws -> TravelLocation {
        let savedCities = try context.fetch(FetchDescriptor<TravelLocation>())
            .filter { $0.kind == .city && $0.id != location?.id }

        guard !savedCities.contains(where: {
            isObviousCityDuplicate(
                $0,
                name: name,
                countryName: countryName,
                latitude: latitude,
                longitude: longitude
            )
        }) else {
            throw TravelLocationStoreError.duplicateCity
        }

        let city = location ?? TravelLocation(name: name, kind: .city)
        try city.update(
            referenceIdentifier: nil,
            name: name,
            kind: .city,
            countryName: countryName,
            isVisited: isVisited,
            visitYear: visitYear,
            rating: rating,
            latitude: latitude,
            longitude: longitude
        )
        try save(city, in: context)
        return city
    }

    static func isObviousCityDuplicate(
        _ location: TravelLocation,
        name: String,
        countryName: String,
        latitude: Double,
        longitude: Double,
        coordinateTolerance: Double = 0.02
    ) -> Bool {
        guard location.kind == .city,
              let savedCountry = location.countryName,
              let savedLatitude = location.latitude,
              let savedLongitude = location.longitude else {
            return false
        }

        return normalized(name) == normalized(location.name)
            && normalized(countryName) == normalized(savedCountry)
            && abs(latitude - savedLatitude) <= coordinateTolerance
            && abs(longitude - savedLongitude) <= coordinateTolerance
    }

    static func save(_ location: TravelLocation, in context: ModelContext) throws {
        try location.normalizeAndValidateForSave()
        if location.modelContext == nil {
            context.insert(location)
        }
        try context.save()
    }

    static func delete(_ location: TravelLocation, from context: ModelContext) throws {
        let managedFilenames = location.photos.map(\.managedFilename)
        context.delete(location)
        try context.save()

        guard let photoDirectory = try? AppDirectories.photos else { return }
        let fileManager = FileManager.default
        for filename in managedFilenames {
            let fileURL = photoDirectory.appending(path: filename)
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
