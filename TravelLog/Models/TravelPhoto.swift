import Foundation
import SwiftData

@Model
final class TravelPhoto {
    @Attribute(.unique) var id: UUID
    var originalFilename: String
    var managedFilename: String
    var createdAt: Date
    var location: TravelLocation?

    init(
        id: UUID = UUID(),
        originalFilename: String,
        managedFilename: String,
        createdAt: Date = .now,
        location: TravelLocation? = nil
    ) {
        self.id = id
        self.originalFilename = originalFilename
        self.managedFilename = managedFilename
        self.createdAt = createdAt
        self.location = location
    }

    func normalizeAndValidateForSave() throws {
        originalFilename = originalFilename.trimmingCharacters(in: .whitespacesAndNewlines)
        managedFilename = managedFilename.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !originalFilename.isEmpty else {
            throw TravelDataValidationError.emptyOriginalFilename
        }
        guard !managedFilename.isEmpty else {
            throw TravelDataValidationError.emptyManagedFilename
        }
        guard location != nil else {
            throw TravelDataValidationError.missingParentLocation
        }
    }
}
