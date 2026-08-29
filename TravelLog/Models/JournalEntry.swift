import Foundation
import SwiftData

@Model
final class JournalEntry {
    @Attribute(.unique) var id: UUID
    var body: String
    var createdAt: Date
    var location: TravelLocation?

    init(
        id: UUID = UUID(),
        body: String,
        createdAt: Date = .now,
        location: TravelLocation? = nil
    ) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
        self.location = location
    }

    func normalizeAndValidateForSave() throws {
        body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            throw TravelDataValidationError.emptyJournalBody
        }
        guard location != nil else {
            throw TravelDataValidationError.missingParentLocation
        }
    }
}
