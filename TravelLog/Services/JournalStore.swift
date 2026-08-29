import Foundation
import SwiftData

@MainActor
enum JournalStore {
    static func save(
        body: String,
        for location: TravelLocation,
        existing entry: JournalEntry? = nil,
        in context: ModelContext
    ) throws -> JournalEntry {
        let journal = entry ?? JournalEntry(body: body, location: location)
        journal.body = body
        journal.location = location
        try journal.normalizeAndValidateForSave()

        if journal.modelContext == nil {
            location.journalEntries.append(journal)
            context.insert(journal)
        }
        try context.save()
        return journal
    }

    static func delete(_ entry: JournalEntry, from context: ModelContext) throws {
        context.delete(entry)
        try context.save()
    }
}
