import Foundation

enum AppDirectories {
    static var applicationSupport: URL {
        get throws {
            let fileManager = FileManager.default
            let baseURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let appURL = baseURL.appending(path: "TravelLog", directoryHint: .isDirectory)
            try fileManager.createDirectory(
                at: appURL,
                withIntermediateDirectories: true
            )
            return appURL
        }
    }
}
