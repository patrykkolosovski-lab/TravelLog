import Foundation
import SwiftData

enum LocationKind: String, Codable, CaseIterable, Hashable, Identifiable {
    case country
    case territory
    case city

    var id: String { rawValue }
}

@Model
final class TravelLocation {
    @Attribute(.unique) var id: UUID
    var referenceIdentifier: String?
    var name: String
    var kindRawValue: String
    var countryName: String?
    var isVisited: Bool
    var visitYear: Int?
    var rating: Int?
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.location)
    var journalEntries: [JournalEntry]

    @Relationship(deleteRule: .cascade, inverse: \TravelPhoto.location)
    var photos: [TravelPhoto]

    var kind: LocationKind {
        get { LocationKind(rawValue: kindRawValue) ?? .country }
        set { kindRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        referenceIdentifier: String? = nil,
        name: String,
        kind: LocationKind,
        createdAt: Date = .now
    ) {
        self.id = id
        self.referenceIdentifier = referenceIdentifier
        self.name = name
        self.kindRawValue = kind.rawValue
        self.countryName = nil
        self.isVisited = false
        self.visitYear = nil
        self.rating = nil
        self.latitude = nil
        self.longitude = nil
        self.createdAt = createdAt
        self.journalEntries = []
        self.photos = []
    }

    static func validated(
        id: UUID = UUID(),
        referenceIdentifier: String? = nil,
        name: String,
        kind: LocationKind,
        countryName: String? = nil,
        isVisited: Bool = false,
        visitYear: Int? = nil,
        rating: Int? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        createdAt: Date = .now,
        currentYear: Int = Calendar.current.component(.year, from: .now)
    ) throws -> TravelLocation {
        let location = TravelLocation(
            id: id,
            referenceIdentifier: referenceIdentifier,
            name: name,
            kind: kind,
            createdAt: createdAt
        )
        try location.update(
            referenceIdentifier: referenceIdentifier,
            name: name,
            kind: kind,
            countryName: countryName,
            isVisited: isVisited,
            visitYear: visitYear,
            rating: rating,
            latitude: latitude,
            longitude: longitude,
            currentYear: currentYear
        )
        return location
    }

    func update(
        referenceIdentifier: String?,
        name: String,
        kind: LocationKind,
        countryName: String?,
        isVisited: Bool,
        visitYear: Int?,
        rating: Int?,
        latitude: Double?,
        longitude: Double?,
        currentYear: Int = Calendar.current.component(.year, from: .now)
    ) throws {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCountry = countryName?.trimmingCharacters(in: .whitespacesAndNewlines)

        try Self.validate(
            name: normalizedName,
            kind: kind,
            countryName: normalizedCountry,
            isVisited: isVisited,
            visitYear: visitYear,
            rating: rating,
            latitude: latitude,
            longitude: longitude,
            currentYear: currentYear
        )

        self.referenceIdentifier = referenceIdentifier
        self.name = normalizedName
        self.kind = kind
        self.countryName = kind == .city ? normalizedCountry : nil
        self.isVisited = isVisited
        self.visitYear = isVisited ? visitYear : nil
        self.rating = rating
        self.latitude = kind == .city ? latitude : nil
        self.longitude = kind == .city ? longitude : nil
    }

    func normalizeAndValidateForSave(
        currentYear: Int = Calendar.current.component(.year, from: .now)
    ) throws {
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        countryName = countryName?.trimmingCharacters(in: .whitespacesAndNewlines)

        if !isVisited {
            visitYear = nil
        }

        try Self.validate(
            name: name,
            kind: kind,
            countryName: countryName,
            isVisited: isVisited,
            visitYear: visitYear,
            rating: rating,
            latitude: latitude,
            longitude: longitude,
            currentYear: currentYear
        )

        for entry in journalEntries {
            try entry.normalizeAndValidateForSave()
        }
        for photo in photos {
            try photo.normalizeAndValidateForSave()
        }
    }

    private static func validate(
        name: String,
        kind: LocationKind,
        countryName: String?,
        isVisited: Bool,
        visitYear: Int?,
        rating: Int?,
        latitude: Double?,
        longitude: Double?,
        currentYear: Int
    ) throws {
        guard !name.isEmpty else {
            throw TravelDataValidationError.emptyLocationName
        }

        if kind == .city {
            guard let countryName, !countryName.isEmpty else {
                throw TravelDataValidationError.cityRequiresCountry
            }
            if (latitude == nil) != (longitude == nil) {
                throw TravelDataValidationError.incompleteCoordinates
            }
            if let latitude, !(-90...90).contains(latitude) {
                throw TravelDataValidationError.invalidLatitude(latitude)
            }
            if let longitude, !(-180...180).contains(longitude) {
                throw TravelDataValidationError.invalidLongitude(longitude)
            }
        } else if countryName != nil || latitude != nil || longitude != nil {
            throw TravelDataValidationError.cityFieldsOnNonCity
        }

        if isVisited {
            guard let visitYear else {
                throw TravelDataValidationError.missingVisitYear
            }
            guard (1900...currentYear).contains(visitYear) else {
                throw TravelDataValidationError.invalidVisitYear(visitYear)
            }
        }

        if let rating, !(0...10).contains(rating) {
            throw TravelDataValidationError.invalidRating(rating)
        }
    }
}
