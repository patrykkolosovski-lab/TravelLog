import SwiftData
import SwiftUI

struct ContentView: View {
    @Query private var locations: [TravelLocation]
    @State private var selectedAction: TravelAction?

    private var visitedCount: Int {
        locations.lazy.filter(\.isVisited).count
    }

    var body: some View {
        VStack(spacing: 0) {
            WorldMapView(visitedCount: visitedCount)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomActionBar { action in
                selectedAction = action
            }
        }
        .background(AppPalette.windowBackground)
        .sheet(item: $selectedAction) { action in
            ActionSheetView(action: action)
        }
    }
}
#Preview {
    ContentView()
        .modelContainer(for: TravelLocation.self, inMemory: true)
        .frame(width: 1100, height: 720)
}
