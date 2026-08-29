import SwiftUI

struct BottomActionBar: View {
    let perform: (TravelAction) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TravelAction.allCases) { action in
                Button {
                    perform(action)
                } label: {
                    Label(action.title, systemImage: action.symbolName)
                        .font(.system(size: 13, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(action == .addCountry ? AppPalette.lime : .primary)
                .accessibilityHint(action.accessibilityHint)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 70)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
#Preview {
    BottomActionBar { _ in }
        .frame(width: 900)
}
