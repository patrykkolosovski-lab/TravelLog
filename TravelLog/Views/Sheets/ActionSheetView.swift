import SwiftUI

struct ActionSheetView: View {
    let action: TravelAction

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(action.title, systemImage: action.symbolName)
                    .font(.headline)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            Divider()

            ContentUnavailableView(
                emptyStateTitle,
                systemImage: action.symbolName
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 520, height: 360)
    }

    private var emptyStateTitle: String {
        switch action {
        case .addCountry:
            "No countries added"
        case .addPhoto:
            "No location selected"
        case .addJournal:
            "No location selected"
        case .stats:
            "No travel statistics"
        }
    }
}
