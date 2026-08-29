import AppKit
import SwiftUI

struct PhotoPreviewSheet: View {
    let photo: TravelPhoto
    let remove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingRemoval = false

    private var image: NSImage? {
        guard let fileURL = ManagedPhotoStore.fileURL(for: photo) else { return nil }
        return NSImage(contentsOf: fileURL)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(photo.originalFilename)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button(role: .destructive) {
                    isConfirmingRemoval = true
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .underPageBackgroundColor))
            } else {
                ContentUnavailableView(
                    "Photo unavailable",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text("The managed image file is missing or unreadable.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .confirmationDialog(
            "Remove this photo?",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove Photo", role: .destructive) {
                remove()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The managed image file and its TravelLog record will be permanently removed.")
        }
    }
}
