import SwiftUI

struct VisitDetailsEditor: View {
    @Binding var isVisited: Bool
    @Binding var visitYear: Int?
    @Binding var rating: Int?

    private let currentYear = Calendar.current.component(.year, from: .now)

    var body: some View {
        Toggle("Visited", isOn: $isVisited)
            .onChange(of: isVisited) { _, isVisited in
                visitYear = isVisited ? (visitYear ?? currentYear) : nil
            }

        if isVisited {
            Picker("Visit year", selection: requiredYear) {
                ForEach(Array((1900...currentYear).reversed()), id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
        }

        Picker("Rating", selection: $rating) {
            Text("Not rated").tag(nil as Int?)
            ForEach(0...10, id: \.self) { value in
                Text("\(value) / 10").tag(value as Int?)
            }
        }
    }

    private var requiredYear: Binding<Int> {
        Binding(
            get: { visitYear ?? currentYear },
            set: { visitYear = $0 }
        )
    }
}
