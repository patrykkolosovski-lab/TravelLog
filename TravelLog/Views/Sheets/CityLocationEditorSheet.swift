import SwiftData
import SwiftUI

struct CityEditorRequest: Identifiable {
    let id = UUID()
    let existingLocation: TravelLocation?
    let name: String
    let countryName: String
    let regionName: String?
    let latitude: Double
    let longitude: Double

    init(result: CitySearchResult) {
        existingLocation = nil
        name = result.name
        countryName = result.countryName
        regionName = result.regionName
        latitude = result.latitude
        longitude = result.longitude
    }

    init?(location: TravelLocation) {
        guard location.kind == .city,
              let countryName = location.countryName,
              let latitude = location.latitude,
              let longitude = location.longitude else {
            return nil
        }

        existingLocation = location
        name = location.name
        self.countryName = countryName
        regionName = nil
        self.latitude = latitude
        self.longitude = longitude
    }
}

struct CityLocationEditorSheet: View {
    let request: CityEditorRequest
    let didSave: (WorldMapSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isVisited: Bool
    @State private var visitYear: Int?
    @State private var rating: Int?
    @State private var errorMessage: String?

    init(
        request: CityEditorRequest,
        didSave: @escaping (WorldMapSelection) -> Void
    ) {
        self.request = request
        self.didSave = didSave
        let currentYear = Calendar.current.component(.year, from: .now)
        _isVisited = State(initialValue: request.existingLocation?.isVisited ?? true)
        _visitYear = State(initialValue: request.existingLocation?.visitYear ?? currentYear)
        _rating = State(initialValue: request.existingLocation?.rating)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(
                    request.existingLocation == nil ? "Add City" : "Edit City",
                    systemImage: "building.2"
                )
                .font(.headline)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Button {
                    save()
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 11)
                        .frame(height: 28)
                        .background(AppPalette.lime, in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(isVisited && visitYear == nil)
            }
            .padding(16)

            Divider()

            Form {
                Section("City") {
                    LabeledContent("Name", value: request.name)
                    LabeledContent("Country", value: request.countryName)
                    if let regionName = request.regionName, !regionName.isEmpty {
                        LabeledContent("Region", value: regionName)
                    }
                }

                Section("Visit") {
                    VisitDetailsEditor(
                        isVisited: $isVisited,
                        visitYear: $visitYear,
                        rating: $rating
                    )
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 430)
    }

    private func save() {
        do {
            let city = try TravelLocationStore.saveCity(
                existing: request.existingLocation,
                name: request.name,
                countryName: request.countryName,
                isVisited: isVisited,
                visitYear: isVisited ? visitYear : nil,
                rating: rating,
                latitude: request.latitude,
                longitude: request.longitude,
                in: modelContext
            )
            didSave(.city(city.id))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
