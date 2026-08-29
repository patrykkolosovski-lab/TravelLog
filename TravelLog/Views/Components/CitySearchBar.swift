import SwiftUI

struct CitySearchBar: View {
    let selectResult: (CitySearchResult) -> Void

    @StateObject private var searchService = CitySearchService()
    @State private var query = ""
    @State private var isPresentingResults = false
    @State private var resolvingSuggestionID: String?
    @State private var resolutionError: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search for a city", text: $query)
                .textFieldStyle(.plain)
                .onSubmit {
                    isPresentingResults = !query.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    isPresentingResults = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear city search")
                .accessibilityLabel("Clear city search")
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: 460, minHeight: 30)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.separator.opacity(0.55), lineWidth: 0.5)
        }
        .onChange(of: query) { _, newValue in
            searchService.updateQuery(newValue)
            isPresentingResults = !newValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
        }
        .popover(isPresented: $isPresentingResults, arrowEdge: .bottom) {
            resultsPopover
        }
    }

    private var resultsPopover: some View {
        Group {
            if let errorMessage = resolutionError ?? searchService.errorMessage {
                ContentUnavailableView(
                    "City search unavailable",
                    systemImage: "wifi.exclamationmark",
                    description: Text(errorMessage)
                )
            } else if searchService.isLoading && searchService.suggestions.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Searching cities...")
                        .foregroundStyle(.secondary)
                }
            } else if searchService.suggestions.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(searchService.suggestions) { suggestion in
                    Button {
                        resolve(suggestion)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "building.2")
                                .foregroundStyle(.secondary)
                                .frame(width: 18)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .foregroundStyle(.primary)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if resolvingSuggestionID == suggestion.id {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(resolvingSuggestionID != nil)
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 430, height: 300)
    }

    private func resolve(_ suggestion: CitySearchSuggestion) {
        resolutionError = nil
        resolvingSuggestionID = suggestion.id

        Task {
            do {
                let result = try await searchService.resolve(suggestion)
                query = ""
                isPresentingResults = false
                resolvingSuggestionID = nil
                selectResult(result)
            } catch {
                resolvingSuggestionID = nil
                resolutionError = error.localizedDescription
            }
        }
    }
}

#Preview {
    CitySearchBar { _ in }
        .padding()
        .frame(width: 700)
}
