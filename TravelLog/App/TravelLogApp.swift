import SwiftData
import SwiftUI

@main
struct TravelLogApp: App {
    private let modelContainer: ModelContainer = {
        let schema = Schema([
            TravelLocation.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Unable to create the TravelLog data store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 840, minHeight: 580)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)
    }
}
