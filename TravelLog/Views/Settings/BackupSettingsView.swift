import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupSettingsView: View {
    @Query private var referenceLocations: [ReferenceLocation]
    @Environment(\.modelContext) private var modelContext

    @State private var exportDocument: TravelLogArchiveDocument?
    @State private var isPresentingExporter = false
    @State private var isPresentingImporter = false
    @State private var pendingArchive: TravelLogArchive?
    @State private var isChoosingImportMode = false
    @State private var isConfirmingReplacement = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    private var referenceIdentifiers: Set<String> {
        Set(referenceLocations.map(\.stableIdentifier))
    }

    var body: some View {
        Form {
            Section("Backup") {
                Text("Export a portable archive containing locations, journals, and managed photos.")
                    .foregroundStyle(.secondary)

                HStack {
                    Button {
                        prepareExport()
                    } label: {
                        Label("Export Archive", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        isPresentingImporter = true
                    } label: {
                        Label("Import Archive", systemImage: "square.and.arrow.down")
                    }
                }

                if let statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 280)
        .fileExporter(
            isPresented: $isPresentingExporter,
            document: exportDocument,
            contentType: .travelLogArchive,
            defaultFilename: "TravelLog-Backup"
        ) { result in
            switch result {
            case let .success(url):
                statusMessage = "Archive exported to \(url.lastPathComponent)."
            case let .failure(error):
                errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $isPresentingImporter,
            allowedContentTypes: [.travelLogArchive, .json]
        ) { result in
            handleImportSelection(result)
        }
        .confirmationDialog(
            "Import TravelLog archive",
            isPresented: $isChoosingImportMode,
            titleVisibility: .visible
        ) {
            Button("Merge with Existing Data") {
                performImport(mode: .merge)
            }
            Button("Replace Existing Data", role: .destructive) {
                isConfirmingReplacement = true
            }
            Button("Cancel", role: .cancel) {
                pendingArchive = nil
            }
        } message: {
            Text("Merge keeps existing records. Replace removes personal TravelLog content after creating a safety backup.")
        }
        .alert("Replace all TravelLog data?", isPresented: $isConfirmingReplacement) {
            Button("Replace", role: .destructive) {
                performImport(mode: .replace)
            }
            Button("Cancel", role: .cancel) {
                pendingArchive = nil
            }
        } message: {
            Text("All current locations, journals, and photo records will be replaced. An automatic safety backup will be created first.")
        }
        .alert("Backup Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    private func prepareExport() {
        do {
            exportDocument = TravelLogArchiveDocument(
                data: try BackupService.encodedArchive(in: modelContext)
            )
            statusMessage = nil
            isPresentingExporter = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImportSelection(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            pendingArchive = try BackupService.decodeAndValidate(
                data,
                referenceIdentifiers: referenceIdentifiers
            )
            statusMessage = nil
            isChoosingImportMode = true
        } catch {
            pendingArchive = nil
            errorMessage = error.localizedDescription
        }
    }

    private func performImport(mode: TravelLogImportMode) {
        guard let pendingArchive else { return }
        do {
            let result = try BackupService.importArchive(
                pendingArchive,
                mode: mode,
                referenceIdentifiers: referenceIdentifiers,
                in: modelContext
            )
            self.pendingArchive = nil
            if let safetyURL = result.safetyBackupURL {
                statusMessage = "Imported \(result.locationCount) locations. Safety backup: \(safetyURL.lastPathComponent)."
            } else {
                statusMessage = "Imported \(result.locationCount) locations, \(result.journalCount) journals, and \(result.photoCount) photos."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
