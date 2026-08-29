import Foundation

enum WorldMapSelection: Identifiable, Equatable {
    case reference(String)
    case city(UUID)

    var id: String {
        switch self {
        case let .reference(identifier):
            "reference:\(identifier)"
        case let .city(identifier):
            "city:\(identifier.uuidString)"
        }
    }

    init?(location: TravelLocation) {
        if location.kind == .city {
            self = .city(location.id)
        } else if let referenceIdentifier = location.referenceIdentifier {
            self = .reference(referenceIdentifier)
        } else {
            return nil
        }
    }
}
