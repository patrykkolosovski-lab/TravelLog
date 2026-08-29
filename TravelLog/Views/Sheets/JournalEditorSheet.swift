import SwiftData
import SwiftUI

struct JournalEditorRequest: Identifiable {
    let id = UUID()
    let initialLocationID: UUID?
    let entry: JournalEntry?

    init(initialLocationID: UUID? = nil, entry: JournalEntry? = nil) {
        self.initialLocationID = initialLocationID ?? entry?.location?.id
        self.entry = entry
    }
}

struct JournalEditorSheet: View {
    let locations: [TravelLocation]
    let request: JournalEditorRequest
    let didSave: (WorldMapSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedLocationID: UUID?
    @State private var bodyText: String
    @State private var errorMessage: String?

    init(
        locations: [TravelLocation],
        request: JournalEditorRequest,
        didSave: @escaping (WorldMapSelection) -> Void
    ) {
        self.locations = locations
        self.request = request
        self.didSave = didSave
        _selectedLocationID = State(initialValue: request.initialLocationID)
        _bodyText = State(initialValue: request.entry?.body ?? "")
    }

    private var selectedLocation: TravelLocation? {
        locations.first { $0.id == selectedLocationID }
    }

    private var isBodyEmpty: Bool {
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HSplitView {
                SavedLocationPicker(locations: locations, selection: $selectedLocationID)
                    .padding(16)
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 370)
                    .disabled(request.entry != nil)

                editor
                    .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 820, height: 540)
    }

    private var header: some View {
        HStack {
            Label(request.entry == nil ? "Add Journal" : "Edit Journal", systemImage: "book.pages")
                .font(.headline)
            Spacer()
            Button("Cancel") { dismiss() }
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
            .disabled(selectedLocation == nil || isBodyEmpty)
        }
        .padding(16)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedLocation {
                Text(selectedLocation.name)
                    .font(.headline)

                TextEditor(text: $bodyText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator, lineWidth: 0.5)
                    }
                    .frame(minHeight: 300)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            } else {
                ContentUnavailableView(
                    "Select a location",
                    systemImage: "book.pages",
                    description: Text("Choose where this journal entry belongs.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
    }

    private func save() {
        guard let selectedLocation else { return }
        do {
            _ = try JournalStore.save(
                body: bodyText,
                for: selectedLocation,
                existing: request.entry,
                in: modelContext
            )
            if let selection = WorldMapSelection(location: selectedLocation) {
                didSave(selection)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
