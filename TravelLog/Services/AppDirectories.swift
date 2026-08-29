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

    static var photos: URL {
        get throws {
            let fileManager = FileManager.default
            let photosURL = try applicationSupport.appending(
                path: "Photos",
                directoryHint: .isDirectory
            )
            try fileManager.createDirectory(
                at: photosURL,
                withIntermediateDirectories: true
            )
            return photosURL
        }
    }

    static var backups: URL {
        get throws {
            let fileManager = FileManager.default
            let backupsURL = try applicationSupport.appending(
                path: "Backups",
                directoryHint: .isDirectory
            )
            try fileManager.createDirectory(
                at: backupsURL,
                withIntermediateDirectories: true
            )
            return backupsURL
        }
    }
}
