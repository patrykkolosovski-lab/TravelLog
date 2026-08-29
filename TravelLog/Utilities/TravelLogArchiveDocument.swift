import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let travelLogArchive = UTType(
        exportedAs: "com.patrykkolosovski.travellog.archive",
        conformingTo: .json
    )
}

struct TravelLogArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.travelLogArchive] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
