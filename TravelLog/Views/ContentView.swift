import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var locations: [TravelLocation]
    @Query(sort: \ReferenceLocation.displayName) private var referenceLocations: [ReferenceLocation]
    @Environment(\.modelContext) private var modelContext

    @State private var mapSelection: WorldMapSelection?
    @State private var isPresentingReferenceEditor = false
    @State private var initialReferenceIdentifier: String?
    @State private var cityEditorRequest: CityEditorRequest?
    @State private var journalEditorRequest: JournalEditorRequest?
    @State private var isPresentingPhotoImport = false
    @State private var isPresentingStats = false
    @State private var dataErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            WorldMapView(
                referenceLocations: referenceLocations,
                travelLocations: locations,
                selection: $mapSelection
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomActionBar { action in
                perform(action)
            }
        }
        .background(AppPalette.windowBackground)
        .inspector(isPresented: inspectorIsPresented) {
            if let mapSelection {
                LocationDetailInspector(
                    selection: mapSelection,
                    referenceLocations: referenceLocations,
                    travelLocations: locations,
                    edit: { edit(mapSelection) },
                    delete: delete,
                    editJournal: { entry in
                        journalEditorRequest = JournalEditorRequest(entry: entry)
                    },
                    deleteJournal: deleteJournal,
                    removePhoto: removePhoto,
                    close: { self.mapSelection = nil }
                )
                .inspectorColumnWidth(min: 290, ideal: 330, max: 400)
            }
        }
        .sheet(isPresented: $isPresentingReferenceEditor) {
            ReferenceLocationEditorSheet(
                referenceLocations: referenceLocations,
                travelLocations: locations,
                initialReferenceIdentifier: initialReferenceIdentifier,
                didSave: { selection in
                    mapSelection = selection
                }
            )
        }
        .sheet(item: $cityEditorRequest) { request in
            CityLocationEditorSheet(request: request) { selection in
                mapSelection = selection
            }
        }
        .sheet(isPresented: $isPresentingPhotoImport) {
            PhotoImportSheet(locations: locations) { selection in
                mapSelection = selection
            }
        }
        .sheet(item: $journalEditorRequest) { request in
            JournalEditorSheet(locations: locations, request: request) { selection in
                mapSelection = selection
            }
        }
        .sheet(isPresented: $isPresentingStats) {
            StatsSheet(
                locations: locations,
                referenceLocations: referenceLocations
            )
        }
        .alert("Unable to update location", isPresented: dataErrorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dataErrorMessage ?? "An unknown error occurred.")
        }
    }

    private var inspectorIsPresented: Binding<Bool> {
        Binding(
            get: { mapSelection != nil },
            set: { isPresented in
                if !isPresented {
                    mapSelection = nil
                }
            }
        )
    }

    private var dataErrorIsPresented: Binding<Bool> {
        Binding(
            get: { dataErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    dataErrorMessage = nil
                }
            }
        )
    }

    private func perform(_ action: TravelAction) {
        switch action {
        case .addCountry:
            initialReferenceIdentifier = nil
            isPresentingReferenceEditor = true
        case .addPhoto:
            isPresentingPhotoImport = true
        case .addJournal:
            journalEditorRequest = JournalEditorRequest()
        case .stats:
            isPresentingStats = true
        }
    }

    private func edit(_ selection: WorldMapSelection) {
        switch selection {
        case let .reference(identifier):
            initialReferenceIdentifier = identifier
            isPresentingReferenceEditor = true
        case let .city(identifier):
            guard let location = locations.first(where: { $0.id == identifier }),
                  let request = CityEditorRequest(location: location) else {
                dataErrorMessage = "The saved city could not be loaded."
                return
            }
            cityEditorRequest = request
        }
    }

    private func delete(_ location: TravelLocation) {
        do {
            try TravelLocationStore.delete(location, from: modelContext)
            mapSelection = nil
        } catch {
            dataErrorMessage = error.localizedDescription
        }
    }

    private func deleteJournal(_ entry: JournalEntry) {
        do {
            try JournalStore.delete(entry, from: modelContext)
        } catch {
            dataErrorMessage = error.localizedDescription
        }
    }

    private func removePhoto(_ photo: TravelPhoto) {
        do {
            try ManagedPhotoStore.remove(photo, from: modelContext)
        } catch {
            dataErrorMessage = error.localizedDescription
        }
    }
}
#Preview {
    ContentView()
        .modelContainer(
            for: [
                TravelLocation.self,
                JournalEntry.self,
                TravelPhoto.self,
                ReferenceLocation.self
            ],
            inMemory: true
        )
        .frame(width: 1100, height: 720)
}
