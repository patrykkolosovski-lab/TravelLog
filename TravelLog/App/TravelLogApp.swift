import SwiftData
import SwiftUI

@main
struct TravelLogApp: App {
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            TravelLocation.self,
            JournalEntry.self,
            TravelPhoto.self,
            ReferenceLocation.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            try ReferenceDataSeeder.seedIfNeeded(in: container.mainContext)
            modelContainer = container
        } catch {
            fatalError("Unable to create the TravelLog data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 840, minHeight: 580)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)

        Settings {
            BackupSettingsView()
                .modelContainer(modelContainer)
        }
    }
}
