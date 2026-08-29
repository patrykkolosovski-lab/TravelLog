import Foundation
import SwiftData

enum ReferenceLocationCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case country
    case territory

    var id: String { rawValue }
}

@Model
final class ReferenceLocation {
    @Attribute(.unique) var stableIdentifier: String
    var displayName: String
    var categoryRawValue: String
    var geometryIdentifier: String
    var continentRawValue: String?
    var flagCode: String?

    var category: ReferenceLocationCategory {
        get { ReferenceLocationCategory(rawValue: categoryRawValue) ?? .country }
        set { categoryRawValue = newValue.rawValue }
    }

    init(
        stableIdentifier: String,
        displayName: String,
        category: ReferenceLocationCategory,
        geometryIdentifier: String,
        continent: TravelContinent? = nil,
        flagCode: String? = nil
    ) {
        self.stableIdentifier = stableIdentifier
        self.displayName = displayName
        self.categoryRawValue = category.rawValue
        self.geometryIdentifier = geometryIdentifier
        self.continentRawValue = continent?.rawValue
        self.flagCode = flagCode
    }

    var continent: TravelContinent? {
        get { continentRawValue.flatMap(TravelContinent.init(rawValue:)) }
        set { continentRawValue = newValue?.rawValue }
    }
}
