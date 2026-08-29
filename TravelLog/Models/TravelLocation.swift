import Foundation
import SwiftData

enum LocationKind: String, Codable, CaseIterable, Identifiable {
    case country
    case territory
    case city

    var id: String { rawValue }
}
@Model
final class TravelLocation {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRawValue: String
    var countryName: String?
    var isVisited: Bool
    var visitYear: Int?
    var rating: Int?
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date

    var kind: LocationKind {
        get { LocationKind(rawValue: kindRawValue) ?? .country }
        set { kindRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        kind: LocationKind,
        countryName: String? = nil,
        isVisited: Bool = false,
        visitYear: Int? = nil,
        rating: Int? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.kindRawValue = kind.rawValue
        self.countryName = countryName
        self.isVisited = isVisited
        self.visitYear = isVisited ? visitYear : nil
        self.rating = rating.map { min(max($0, 0), 10) }
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
    }
}
