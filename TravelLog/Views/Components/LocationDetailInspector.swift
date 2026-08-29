import AppKit
import SwiftUI

struct LocationDetailInspector: View {
    let selection: WorldMapSelection
    let referenceLocations: [ReferenceLocation]
    let travelLocations: [TravelLocation]
    let edit: () -> Void
    let delete: (TravelLocation) -> Void
    let editJournal: (JournalEntry) -> Void
    let deleteJournal: (JournalEntry) -> Void
    let removePhoto: (TravelPhoto) -> Void
    let close: () -> Void

    @State private var isConfirmingDelete = false
    @State private var journalPendingDeletion: JournalEntry?
    @State private var previewPhoto: TravelPhoto?
    @State private var isCitiesExpanded = true
    @State private var expandedCityIdentifiers = Set<UUID>()

    private var reference: ReferenceLocation? {
        guard case let .reference(identifier) = selection else { return nil }
        return referenceLocations.first { $0.stableIdentifier == identifier }
    }

    private var location: TravelLocation? {
        switch selection {
        case let .reference(identifier):
            return travelLocations.first { $0.referenceIdentifier == identifier }
        case let .city(identifier):
            return travelLocations.first { $0.id == identifier }
        }
    }

    private var displayName: String {
        location?.name ?? reference?.displayName ?? "Location"
    }

    private var displayReference: ReferenceLocation? {
        if let reference { return reference }
        if let identifier = location?.referenceIdentifier {
            return referenceLocations.first { $0.stableIdentifier == identifier }
        }
        if let countryName = location?.countryName {
            return referenceForCountryName(countryName)
        }
        return nil
    }

    private var childCities: [TravelLocation] {
        guard (location?.kind == .country || reference?.category == .country),
              let selectedReference = displayReference else {
            return []
        }
        return travelLocations.filter { city in
            guard city.kind == .city,
                  let countryName = city.countryName,
                  let cityReference = referenceForCountryName(countryName) else {
                return false
            }
            return cityReference.stableIdentifier == selectedReference.stableIdentifier
        }.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var categoryLabel: String {
        if let location {
            switch location.kind {
            case .country: return "UN country"
            case .territory: return "UN territory"
            case .city: return "City"
            }
        }
        return reference?.category == .territory ? "UN territory" : "UN country"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    facts
                    citiesSection
                    photosSection
                    journalsSection
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
            actions
        }
        .confirmationDialog(
            "Delete \(displayName)?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let location else { return }
                delete(location)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
        .confirmationDialog(
            "Delete journal entry?",
            isPresented: Binding(
                get: { journalPendingDeletion != nil },
                set: { if !$0 { journalPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let entry = journalPendingDeletion else { return }
                deleteJournal(entry)
                journalPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                journalPendingDeletion = nil
            }
        } message: {
            Text("This journal entry will be permanently removed.")
        }
        .sheet(item: $previewPhoto) { photo in
            PhotoPreviewSheet(photo: photo) {
                removePhoto(photo)
                previewPhoto = nil
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    let flag = FlagSymbol.make(from: displayReference?.flagCode)
                    if location?.kind != .city, !flag.isEmpty {
                        Text(flag)
                            .accessibilityHidden(true)
                    }
                    Text(displayName)
                        .font(.headline)
                        .lineLimit(2)
                }
                Text(categoryLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: close) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .help("Close inspector")
            .accessibilityLabel("Close location details")
        }
        .padding(16)
    }

    private var facts: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 9) {
            if let countryName = location?.countryName {
                GridRow {
                    Text("Country")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 5) {
                        Text(FlagSymbol.make(from: displayReference?.flagCode))
                            .accessibilityHidden(true)
                        Text(countryName)
                    }
                    .gridColumnAlignment(.trailing)
                }
            }
            factRow("Visited", (location?.isVisited ?? false) ? "Yes" : "No")
            factRow("Visit year", location?.visitYear.map(String.init) ?? "Not set")
            factRow("Rating", location?.rating.map { "\($0) / 10" } ?? "Not rated")
        }
        .font(.subheadline)
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .gridColumnAlignment(.trailing)
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Photos", systemImage: "photo.on.rectangle")

            if let photos = location?.photos, !photos.isEmpty {
                photoGrid(photos)
            } else {
                emptyRow("No photos", systemImage: "photo")
            }
        }
    }

    private var journalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Journal", systemImage: "book.pages")

            if let entries = location?.journalEntries, !entries.isEmpty {
                journalEntries(entries)
            } else {
                emptyRow("No journal entries", systemImage: "text.page")
            }
        }
    }

    @ViewBuilder
    private var citiesSection: some View {
        if !childCities.isEmpty {
            DisclosureGroup(isExpanded: $isCitiesExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(childCities) { city in
                        DisclosureGroup(isExpanded: cityExpansionBinding(for: city.id)) {
                            VStack(alignment: .leading, spacing: 10) {
                                if !city.photos.isEmpty {
                                    Label("Photos", systemImage: "photo.on.rectangle")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    photoGrid(city.photos)
                                }

                                if !city.journalEntries.isEmpty {
                                    Label("Journal", systemImage: "book.pages")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    journalEntries(city.journalEntries)
                                }

                                if city.photos.isEmpty && city.journalEntries.isEmpty {
                                    Text("No photos or journal entries")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.top, 9)
                            .padding(.leading, 8)
                        } label: {
                            HStack {
                                Text(city.name)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                if let rating = city.rating {
                                    Label("\(rating) / 10", systemImage: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if city.id != childCities.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.leading, 8)
            } label: {
                HStack {
                    sectionHeader("Cities", systemImage: "building.2")
                    Spacer()
                    Text("\(childCities.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func cityExpansionBinding(for identifier: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedCityIdentifiers.contains(identifier) },
            set: { isExpanded in
                if isExpanded {
                    expandedCityIdentifiers.insert(identifier)
                } else {
                    expandedCityIdentifiers.remove(identifier)
                }
            }
        )
    }

    private func photoGrid(_ photos: [TravelPhoto]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 76, maximum: 100), spacing: 8)],
            spacing: 8
        ) {
            ForEach(photos.sorted { $0.createdAt > $1.createdAt }) { photo in
                Button {
                    previewPhoto = photo
                } label: {
                    PhotoThumbnail(photo: photo)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func journalEntries(_ entries: [JournalEntry]) -> some View {
        let sortedEntries = entries.sorted { $0.createdAt > $1.createdAt }
        return ForEach(sortedEntries) { entry in
            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.createdAt, format: .dateTime.year().month().day())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.body)
                            .font(.subheadline)
                            .textSelection(.enabled)
                    }

                    Spacer(minLength: 4)

                    Button {
                        editJournal(entry)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)
                    .help("Edit journal entry")

                    Button(role: .destructive) {
                        journalPendingDeletion = entry
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .help("Delete journal entry")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if entry.id != sortedEntries.last?.id {
                    Divider()
                }
            }
        }
    }

    private func referenceForCountryName(_ countryName: String) -> ReferenceLocation? {
        let normalizedName = normalized(countryName)
        return referenceLocations.first { reference in
            if normalized(reference.displayName) == normalizedName {
                return true
            }
            guard let flagCode = reference.flagCode else { return false }
            return [Locale(identifier: "en_US"), Locale.current].contains { locale in
                locale.localizedString(forRegionCode: flagCode).map(normalized) == normalizedName
            }
        }
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
    }

    private func emptyRow(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
    }

    private var actions: some View {
        HStack {
            Button {
                edit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .buttonStyle(.plain)

            Spacer()

            if location != nil {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        .padding(12)
    }

    private var deleteMessage: String {
        guard let location else { return "This cannot be undone." }
        let journalCount = location.journalEntries.count
        let photoCount = location.photos.count
        guard journalCount > 0 || photoCount > 0 else {
            return "This saved location will be removed. This cannot be undone."
        }

        return "This also deletes \(journalCount) journal entries and \(photoCount) photos. This cannot be undone."
    }
}

private struct PhotoThumbnail: View {
    let photo: TravelPhoto

    private var image: NSImage? {
        guard let fileURL = ManagedPhotoStore.fileURL(for: photo) else { return nil }
        return NSImage(contentsOf: fileURL)
    }

    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(.separator.opacity(0.5), lineWidth: 0.5)
        }
        .help(photo.originalFilename)
    }
}
