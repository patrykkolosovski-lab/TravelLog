import Foundation

enum TravelAction: String, CaseIterable, Identifiable {
    case addCountry
    case addPhoto
    case addJournal
    case stats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addCountry: "Add Country"
        case .addPhoto: "Add Photo"
        case .addJournal: "Add Journal"
        case .stats: "Stats"
        }
    }

    var symbolName: String {
        switch self {
        case .addCountry: "map.badge.plus"
        case .addPhoto: "photo.badge.plus"
        case .addJournal: "book.pages"
        case .stats: "chart.bar.xaxis"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .addCountry: "Opens the country picker"
        case .addPhoto: "Adds photos to a saved location"
        case .addJournal: "Writes a journal entry for a saved location"
        case .stats: "Shows travel statistics"
        }
    }
}
