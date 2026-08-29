import Foundation

enum TravelDataValidationError: Error, Equatable, LocalizedError {
    case emptyLocationName
    case cityRequiresCountry
    case cityFieldsOnNonCity
    case incompleteCoordinates
    case missingVisitYear
    case invalidLatitude(Double)
    case invalidLongitude(Double)
    case invalidVisitYear(Int)
    case invalidRating(Int)
    case emptyJournalBody
    case emptyOriginalFilename
    case emptyManagedFilename
    case missingParentLocation

    var errorDescription: String? {
        switch self {
        case .emptyLocationName:
            "Location name cannot be empty."
        case .cityRequiresCountry:
            "A city must have a country."
        case .cityFieldsOnNonCity:
            "Country and coordinates are only valid for cities."
        case .incompleteCoordinates:
            "Latitude and longitude must be provided together."
        case .missingVisitYear:
            "Choose a visit year when a location is marked as visited."
        case .invalidLatitude:
            "Latitude must be between -90 and 90."
        case .invalidLongitude:
            "Longitude must be between -180 and 180."
        case let .invalidVisitYear(year):
            "\(year) is not a valid visit year."
        case let .invalidRating(rating):
            "\(rating) is not a valid rating. Use a value from 0 to 10."
        case .emptyJournalBody:
            "Journal body cannot be empty."
        case .emptyOriginalFilename:
            "Original photo filename cannot be empty."
        case .emptyManagedFilename:
            "Managed photo filename cannot be empty."
        case .missingParentLocation:
            "Journal entries and photos must belong to a location."
        }
    }
}
