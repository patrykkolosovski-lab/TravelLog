import SwiftData
import SwiftUI

private enum LocationEditorCategory: String, CaseIterable, Identifiable {
    case country
    case territory
    case city

    var id: String { rawValue }
}

struct ReferenceLocationEditorSheet: View {
    let referenceLocations: [ReferenceLocation]
    let travelLocations: [TravelLocation]
    let initialReferenceIdentifier: String?
    let didSave: (WorldMapSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var category: LocationEditorCategory = .country
    @State private var searchText = ""
    @State private var selectedReferenceIdentifier: String?
    @State private var isVisited = true
    @State private var visitYear: Int? = Calendar.current.component(.year, from: .now)
    @State private var rating: Int?
    @State private var errorMessage: String?
    @State private var cityEditorRequest: CityEditorRequest?

    private var filteredReferences: [ReferenceLocation] {
        referenceLocations.filter { reference in
            reference.category == referenceCategory
                && (searchText.isEmpty || reference.displayName.localizedCaseInsensitiveContains(searchText))
        }
    }

    private var referenceCategory: ReferenceLocationCategory? {
        switch category {
        case .country: .country
        case .territory: .territory
        case .city: nil
        }
    }

    private var selectedReference: ReferenceLocation? {
        referenceLocations.first { $0.stableIdentifier == selectedReferenceIdentifier }
    }

    private var savedByReferenceIdentifier: [String: TravelLocation] {
        Dictionary(
            travelLocations.compactMap { location in
                location.referenceIdentifier.map { ($0, location) }
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HSplitView {
                referencePicker
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 370)

                editor
                    .frame(minWidth: 330, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 760, height: 540)
        .onAppear(perform: prepareInitialSelection)
        .onChange(of: selectedReferenceIdentifier) { _, _ in
            loadSavedValues()
        }
        .onChange(of: category) { _, newCategory in
            guard selectedReference?.category != referenceCategory else { return }
            selectedReferenceIdentifier = nil
            errorMessage = nil
        }
        .sheet(item: $cityEditorRequest) { request in
            CityLocationEditorSheet(request: request) { selection in
                didSave(selection)
                dismiss()
            }
        }
    }

    private var header: some View {
        HStack {
            Label(
                initialReferenceIdentifier == nil ? "Add Location" : "Edit Location",
                systemImage: "map.badge.plus"
            )
                .font(.headline)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)

            if category != .city {
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
                .disabled(selectedReference == nil || (isVisited && visitYear == nil))
            }
        }
        .padding(16)
    }

    private var referencePicker: some View {
        VStack(spacing: 12) {
            Picker("Category", selection: $category) {
                Text("Countries").tag(LocationEditorCategory.country)
                Text("UN Territories").tag(LocationEditorCategory.territory)
                Text("Cities").tag(LocationEditorCategory.city)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if category != .city {
                TextField("Search locations", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }

            if category == .city {
                cityPicker
            } else if filteredReferences.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(filteredReferences, selection: $selectedReferenceIdentifier) { reference in
                        HStack(spacing: 8) {
                            Text(FlagSymbol.make(from: reference.flagCode))
                                .accessibilityHidden(true)
                            Text(reference.displayName)
                                .lineLimit(1)

                            Spacer()

                            if let saved = savedByReferenceIdentifier[reference.stableIdentifier] {
                                Image(systemName: saved.isVisited ? "checkmark.circle.fill" : "checkmark.circle")
                                    .foregroundStyle(saved.isVisited ? AppPalette.lime : .secondary)
                                    .help("Saved")
                            }
                        }
                        .tag(reference.stableIdentifier)
                        .id(reference.stableIdentifier)
                    }
                    .listStyle(.inset)
                    .onChange(of: selectedReferenceIdentifier) { _, identifier in
                        guard let identifier else { return }
                        proxy.scrollTo(identifier, anchor: .center)
                    }
                }
            }
        }
        .padding(16)
    }

    private var cityPicker: some View {
        VStack(spacing: 12) {
            CitySearchBar { result in
                cityEditorRequest = CityEditorRequest(result: result)
            }

            let savedCities = travelLocations.filter { $0.kind == .city }.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            if savedCities.isEmpty {
                ContentUnavailableView(
                    "No saved cities",
                    systemImage: "building.2"
                )
            } else {
                List(savedCities) { city in
                    Button {
                        cityEditorRequest = CityEditorRequest(location: city)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(city.name)
                            if let countryName = city.countryName {
                                Text(countryName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
    }

    @ViewBuilder
    private var editor: some View {
        if let selectedReference {
            Form {
                Section("Location") {
                    LabeledContent("Name", value: selectedReference.displayName)
                    LabeledContent(
                        "Category",
                        value: selectedReference.category == .country ? "UN country" : "UN territory"
                    )
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
        } else {
            if category == .city {
                ContentUnavailableView(
                    "No city selected",
                    systemImage: "building.2"
                )
            } else {
                ContentUnavailableView(
                    "Select a location",
                    systemImage: "map",
                    description: Text("Choose a country or UN territory from the list.")
                )
            }
        }
    }

    private func prepareInitialSelection() {
        guard let initialReferenceIdentifier,
              let reference = referenceLocations.first(where: {
                  $0.stableIdentifier == initialReferenceIdentifier
              }) else {
            return
        }

        category = reference.category == .country ? .country : .territory
        selectedReferenceIdentifier = initialReferenceIdentifier
        loadSavedValues()
    }

    private func loadSavedValues() {
        errorMessage = nil
        guard let selectedReferenceIdentifier,
              let existing = savedByReferenceIdentifier[selectedReferenceIdentifier] else {
            isVisited = true
            visitYear = Calendar.current.component(.year, from: .now)
            rating = nil
            return
        }

        isVisited = existing.isVisited
        visitYear = existing.visitYear ?? Calendar.current.component(.year, from: .now)
        rating = existing.rating
    }

    private func save() {
        guard let selectedReference else { return }

        do {
            _ = try TravelLocationStore.saveReferenceLocation(
                selectedReference,
                isVisited: isVisited,
                visitYear: isVisited ? visitYear : nil,
                rating: rating,
                in: modelContext
            )
            didSave(.reference(selectedReference.stableIdentifier))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
