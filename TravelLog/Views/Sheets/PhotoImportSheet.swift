import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PhotoImportSheet: View {
    let locations: [TravelLocation]
    let didSave: (WorldMapSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedLocationID: UUID?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isPresentingFileImporter = false
    @State private var isImporting = false
    @State private var errorMessage: String?

    private var selectedLocation: TravelLocation? {
        locations.first { $0.id == selectedLocationID }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HSplitView {
                SavedLocationPicker(
                    locations: locations,
                    selection: $selectedLocationID
                )
                .padding(16)
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 370)

                importPanel
                    .frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 760, height: 500)
        .fileImporter(
            isPresented: $isPresentingFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPhotoPickerItems(items) }
        }
    }

    private var header: some View {
        HStack {
            Label("Add Photo", systemImage: "photo.badge.plus")
                .font(.headline)
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    private var importPanel: some View {
        VStack(spacing: 18) {
            if let selectedLocation {
                VStack(spacing: 5) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 38))
                        .foregroundStyle(AppPalette.lime)
                    Text("Add photos to \(selectedLocation.name)")
                        .font(.headline)
                    Text("Images are copied into TravelLog and remain available if the originals move.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }

                HStack(spacing: 12) {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 0,
                        matching: .images
                    ) {
                        Label("Photos Library", systemImage: "photo.stack")
                    }
                    .disabled(isImporting)

                    Button {
                        isPresentingFileImporter = true
                    } label: {
                        Label("Choose Files", systemImage: "folder")
                    }
                    .disabled(isImporting)
                }

                if isImporting {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Importing photos...")
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
            } else {
                ContentUnavailableView(
                    "Select a location",
                    systemImage: "photo.badge.plus",
                    description: Text("Choose where these photos belong.")
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func importPhotoPickerItems(_ items: [PhotosPickerItem]) async {
        guard let selectedLocation else { return }
        isImporting = true
        errorMessage = nil

        do {
            var payloads: [PhotoImportPayload] = []
            for (index, item) in items.enumerated() {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw ManagedPhotoError.unreadableFile("Photos Library image \(index + 1)")
                }
                payloads.append(
                    PhotoImportPayload(
                        originalFilename: "Photos Library Image \(index + 1)",
                        data: data
                    )
                )
            }
            try finishImport(payloads, for: selectedLocation)
        } catch {
            isImporting = false
            pickerItems = []
            errorMessage = error.localizedDescription
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard let selectedLocation else { return }
        isImporting = true
        errorMessage = nil

        do {
            let urls = try result.get()
            let payloads = try urls.map(ManagedPhotoStore.payload)
            try finishImport(payloads, for: selectedLocation)
        } catch {
            isImporting = false
            errorMessage = error.localizedDescription
        }
    }

    private func finishImport(
        _ payloads: [PhotoImportPayload],
        for location: TravelLocation
    ) throws {
        _ = try ManagedPhotoStore.importPhotos(payloads, for: location, in: modelContext)
        isImporting = false
        pickerItems = []
        if let selection = WorldMapSelection(location: location) {
            didSave(selection)
        }
        dismiss()
    }
}
