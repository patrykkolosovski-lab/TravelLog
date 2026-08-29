import MapKit
import SwiftUI

struct WorldMapView: View {
    let visitedCount: Int

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 18, longitude: 8),
            span: MKCoordinateSpan(latitudeDelta: 135, longitudeDelta: 300)
        )
    )

    var body: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom])
            .mapStyle(
                .standard(
                    elevation: .flat,
                    emphasis: .muted,
                    pointsOfInterest: .excludingAll,
                    showsTraffic: false
                )
            )
            .mapControls {
                MapCompass()
                MapZoomStepper()
            }
            .overlay(alignment: .topLeading) {
                titleBar
            }
            .accessibilityLabel("World travel map")
    }

    private var titleBar: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("TravelLog")
                .font(.system(size: 24, weight: .semibold))

            Text("\(visitedCount) visited")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .frame(height: 54)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
#Preview {
    WorldMapView(visitedCount: 0)
        .frame(width: 1000, height: 620)
}
