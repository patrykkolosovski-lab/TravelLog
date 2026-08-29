import SwiftUI

struct WorldMapView: View {
    let referenceLocations: [ReferenceLocation]
    let travelLocations: [TravelLocation]
    @Binding var selection: WorldMapSelection?

    @State private var mapData: WorldMapData?
    @State private var mapError: String?
    @State private var mapScale: CGFloat = 1
    @State private var settledScale: CGFloat = 1
    @State private var mapOffset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero

    private var referenceByGeometryIdentifier: [String: ReferenceLocation] {
        var result: [String: ReferenceLocation] = [:]
        for location in referenceLocations {
            result[location.geometryIdentifier] = location
        }
        return result
    }

    private var travelByReferenceIdentifier: [String: TravelLocation] {
        var result: [String: TravelLocation] = [:]
        for location in travelLocations {
            if let identifier = location.referenceIdentifier {
                result[identifier] = location
            }
        }
        return result
    }

    private var cities: [TravelLocation] {
        travelLocations.filter {
            $0.kind == .city && $0.latitude != nil && $0.longitude != nil
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppPalette.mapBackground

                if let mapData {
                    Canvas(opaque: true, rendersAsynchronously: true) { context, size in
                        drawMap(context: &context, size: size, data: mapData)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                selectMapItem(
                                    at: value.location,
                                    size: geometry.size,
                                    data: mapData
                                )
                            }
                    )
                    .simultaneousGesture(panGesture(size: geometry.size))
                    .simultaneousGesture(zoomGesture(size: geometry.size))
                } else if let mapError {
                    ContentUnavailableView(
                        "Map unavailable",
                        systemImage: "map",
                        description: Text(mapError)
                    )
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                mapControls
                    .padding(14)
            }
        }
        .task {
            guard mapData == nil else { return }
            do {
                mapData = try await GeoJSONMapService.load()
            } catch {
                mapError = error.localizedDescription
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("World travel map")
    }

    private var mapControls: some View {
        HStack(spacing: 0) {
            mapControl("minus", help: "Zoom out") {
                setScale(mapScale / 1.35)
            }
            Divider().frame(height: 18)
            mapControl("plus", help: "Zoom in") {
                setScale(mapScale * 1.35)
            }
            Divider().frame(height: 18)
            mapControl("arrow.counterclockwise", help: "Reset map") {
                withAnimation(.easeOut(duration: 0.18)) {
                    mapScale = 1
                    settledScale = 1
                    mapOffset = .zero
                    settledOffset = .zero
                }
            }
        }
        .padding(.horizontal, 3)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.separator.opacity(0.6), lineWidth: 0.5)
        }
    }

    private func mapControl(
        _ symbol: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func drawMap(
        context: inout GraphicsContext,
        size: CGSize,
        data: WorldMapData
    ) {
        let projection = WorldMapProjection(size: size, scale: mapScale, offset: mapOffset)
        let references = referenceByGeometryIdentifier
        let travelLocations = travelByReferenceIdentifier

        context.fill(
            Path(projection.mapRect),
            with: .color(AppPalette.mapBackground)
        )

        for shape in data.shapes {
            let path = projectedPath(for: shape, projection: projection)
            let reference = references[shape.geometryIdentifier]
            let isVisited = reference.flatMap {
                travelLocations[$0.stableIdentifier]?.isVisited
            } ?? false

            context.fill(
                path,
                with: .color(isVisited ? AppPalette.lime : AppPalette.unvisited),
                style: FillStyle(eoFill: true)
            )
            context.stroke(
                path,
                with: .color(AppPalette.mapBoundary),
                lineWidth: 0.55
            )
        }

        for marker in data.markers {
            guard let reference = references[marker.geometryIdentifier] else { continue }
            let center = projection.point(for: marker.coordinate)
            let isVisited = travelLocations[reference.stableIdentifier]?.isVisited ?? false
            let radius = 3.2
            let markerRect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            let markerPath = Path(ellipseIn: markerRect)
            context.fill(
                markerPath,
                with: .color(isVisited ? AppPalette.lime : AppPalette.unvisited)
            )
            context.stroke(
                markerPath,
                with: .color(AppPalette.mapBoundary),
                lineWidth: 0.75
            )
        }

        for city in cities {
            guard let latitude = city.latitude, let longitude = city.longitude else { continue }
            let center = projection.point(
                for: WorldMapCoordinate(longitude: longitude, latitude: latitude)
            )
            let radius = 4.2
            let cityRect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            let cityPath = Path(ellipseIn: cityRect)
            context.fill(cityPath, with: .color(AppPalette.cityRed))
            context.stroke(cityPath, with: .color(.white.opacity(0.9)), lineWidth: 1.2)
        }
    }

    private func selectMapItem(at point: CGPoint, size: CGSize, data: WorldMapData) {
        let projection = WorldMapProjection(size: size, scale: mapScale, offset: mapOffset)

        for city in cities.reversed() {
            guard let latitude = city.latitude, let longitude = city.longitude else { continue }
            let cityPoint = projection.point(
                for: WorldMapCoordinate(longitude: longitude, latitude: latitude)
            )
            if hypot(cityPoint.x - point.x, cityPoint.y - point.y) <= 9 {
                selection = .city(city.id)
                return
            }
        }

        let references = referenceByGeometryIdentifier
        for marker in data.markers.reversed() {
            guard let reference = references[marker.geometryIdentifier] else { continue }
            let markerPoint = projection.point(for: marker.coordinate)
            if hypot(markerPoint.x - point.x, markerPoint.y - point.y) <= 8 {
                selection = makeSelection(for: reference)
                return
            }
        }

        for shape in data.shapes.reversed() {
            guard let reference = references[shape.geometryIdentifier] else { continue }
            let path = projectedPath(for: shape, projection: projection)
            if path.contains(point, eoFill: true) {
                selection = makeSelection(for: reference)
                return
            }
        }

        selection = nil
    }

    private func makeSelection(for reference: ReferenceLocation) -> WorldMapSelection {
        .reference(reference.stableIdentifier)
    }

    private func panGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                mapOffset = clampedOffset(
                    CGSize(
                        width: settledOffset.width + value.translation.width,
                        height: settledOffset.height + value.translation.height
                    ),
                    size: size,
                    scale: mapScale
                )
            }
            .onEnded { _ in
                settledOffset = mapOffset
            }
    }

    private func zoomGesture(size: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                mapScale = min(8, max(1, settledScale * value))
                mapOffset = clampedOffset(mapOffset, size: size, scale: mapScale)
            }
            .onEnded { _ in
                settledScale = mapScale
                settledOffset = mapOffset
            }
    }

    private func setScale(_ proposedScale: CGFloat) {
        withAnimation(.easeOut(duration: 0.16)) {
            let previousScale = mapScale
            let nextScale = min(8, max(1, proposedScale))
            let offsetRatio = previousScale > 1
                ? (nextScale - 1) / (previousScale - 1)
                : 0
            mapScale = nextScale
            settledScale = mapScale
            mapOffset = nextScale == 1 ? .zero : CGSize(
                width: mapOffset.width * offsetRatio,
                height: mapOffset.height * offsetRatio
            )
            settledOffset = mapOffset
        }
    }

    private func clampedOffset(
        _ proposedOffset: CGSize,
        size: CGSize,
        scale: CGFloat
    ) -> CGSize {
        guard scale > 1 else { return .zero }
        let maxX = size.width * (scale - 1) / 2
        let maxY = size.height * (scale - 1) / 2
        return CGSize(
            width: min(maxX, max(-maxX, proposedOffset.width)),
            height: min(maxY, max(-maxY, proposedOffset.height))
        )
    }

    private func projectedPath(
        for shape: WorldMapShape,
        projection: WorldMapProjection
    ) -> Path {
        var path = Path()
        for polygon in shape.polygons {
            for ring in polygon.rings {
                guard let firstCoordinate = ring.first else { continue }
                path.move(to: projection.point(for: firstCoordinate))
                for coordinate in ring.dropFirst() {
                    path.addLine(to: projection.point(for: coordinate))
                }
                path.closeSubpath()
            }
        }
        return path
    }
}

private struct WorldMapProjection {
    let mapRect: CGRect

    init(size: CGSize, scale: CGFloat = 1, offset: CGSize = .zero) {
        let horizontalPadding = 18.0
        let verticalPadding = 16.0
        let availableWidth = max(1, size.width - horizontalPadding * 2)
        let availableHeight = max(1, size.height - verticalPadding * 2)
        let width = min(availableWidth, availableHeight * 2) * scale
        let height = width / 2
        mapRect = CGRect(
            x: (size.width - width) / 2 + offset.width,
            y: (size.height - height) / 2 + offset.height,
            width: width,
            height: height
        )
    }

    func point(for coordinate: WorldMapCoordinate) -> CGPoint {
        CGPoint(
            x: mapRect.minX + ((coordinate.longitude + 180) / 360) * mapRect.width,
            y: mapRect.minY + ((90 - coordinate.latitude) / 180) * mapRect.height
        )
    }
}

#Preview {
    WorldMapView(
        referenceLocations: [],
        travelLocations: [],
        selection: .constant(nil)
    )
    .frame(width: 1000, height: 620)
}
