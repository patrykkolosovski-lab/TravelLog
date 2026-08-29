import AppKit
import Foundation
import ImageIO
import SwiftData
import UniformTypeIdentifiers

struct PhotoImportPayload {
    let originalFilename: String
    let data: Data
}

enum ManagedPhotoError: LocalizedError {
    case invalidImage(String)
    case unreadableFile(String)

    var errorDescription: String? {
        switch self {
        case let .invalidImage(filename):
            "\(filename) is not a readable image."
        case let .unreadableFile(filename):
            "TravelLog could not read \(filename)."
        }
    }
}

@MainActor
enum ManagedPhotoStore {
    static func importPhotos(
        _ payloads: [PhotoImportPayload],
        for location: TravelLocation,
        in context: ModelContext,
        photoDirectory customPhotoDirectory: URL? = nil
    ) throws -> [TravelPhoto] {
        guard !payloads.isEmpty else { return [] }

        let photoDirectory = try customPhotoDirectory ?? AppDirectories.photos
        try FileManager.default.createDirectory(
            at: photoDirectory,
            withIntermediateDirectories: true
        )
        var writtenURLs: [URL] = []
        var photos: [TravelPhoto] = []

        do {
            for payload in payloads {
                let originalFilename = normalizedOriginalFilename(payload.originalFilename)
                guard NSImage(data: payload.data) != nil else {
                    throw ManagedPhotoError.invalidImage(originalFilename)
                }

                let managedFilename = collisionSafeFilename(
                    originalFilename: originalFilename,
                    data: payload.data,
                    in: photoDirectory
                )
                let destination = photoDirectory.appending(path: managedFilename)
                try payload.data.write(to: destination, options: [.atomic])
                writtenURLs.append(destination)

                let photo = TravelPhoto(
                    originalFilename: originalFilename,
                    managedFilename: managedFilename,
                    location: location
                )
                location.photos.append(photo)
                context.insert(photo)
                photos.append(photo)
            }

            try location.normalizeAndValidateForSave()
            try context.save()
            return photos
        } catch {
            context.rollback()
            for url in writtenURLs {
                try? FileManager.default.removeItem(at: url)
            }
            throw error
        }
    }

    static func payload(from url: URL) throws -> PhotoImportPayload {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            return PhotoImportPayload(
                originalFilename: url.lastPathComponent,
                data: try Data(contentsOf: url, options: [.mappedIfSafe])
            )
        } catch {
            throw ManagedPhotoError.unreadableFile(url.lastPathComponent)
        }
    }

    static func remove(
        _ photo: TravelPhoto,
        from context: ModelContext,
        photoDirectory customPhotoDirectory: URL? = nil
    ) throws {
        let photoDirectory = try customPhotoDirectory ?? AppDirectories.photos
        let originalURL = photoDirectory.appending(path: photo.managedFilename)
        let stagedURL = FileManager.default.temporaryDirectory
            .appending(path: "TravelLog-Removed-\(UUID().uuidString)")
        let fileExists = FileManager.default.fileExists(atPath: originalURL.path)

        if fileExists {
            try FileManager.default.moveItem(at: originalURL, to: stagedURL)
        }

        do {
            context.delete(photo)
            try context.save()
            if fileExists {
                try FileManager.default.removeItem(at: stagedURL)
            }
        } catch {
            context.rollback()
            if fileExists, FileManager.default.fileExists(atPath: stagedURL.path) {
                try? FileManager.default.moveItem(at: stagedURL, to: originalURL)
            }
            throw error
        }
    }

    static func fileURL(for photo: TravelPhoto) -> URL? {
        guard let directory = try? AppDirectories.photos else { return nil }
        return directory.appending(path: photo.managedFilename)
    }

    private static func collisionSafeFilename(
        originalFilename: String,
        data: Data,
        in directory: URL
    ) -> String {
        let fileExtension = preferredExtension(for: data)
            ?? URL(fileURLWithPath: originalFilename).pathExtension.lowercased()
        let suffix = fileExtension.isEmpty ? "" : ".\(fileExtension)"

        while true {
            let candidate = "\(UUID().uuidString.lowercased())\(suffix)"
            if !FileManager.default.fileExists(
                atPath: directory.appending(path: candidate).path
            ) {
                return candidate
            }
        }
    }

    private static func preferredExtension(for data: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let typeIdentifier = CGImageSourceGetType(source) else {
            return nil
        }
        return UTType(typeIdentifier as String)?.preferredFilenameExtension
    }

    private static func normalizedOriginalFilename(_ filename: String) -> String {
        let value = URL(fileURLWithPath: filename).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Imported Photo" : value
    }
}
