import SwiftUI

private struct StatsListGroup: Identifiable {
    let id = UUID()
    let title: String?
    let locations: [StatisticsLocationSummary]
}

private struct StatsDrilldown: Identifiable {
    let id = UUID()
    let title: String
    let groups: [StatsListGroup]
}

struct StatsSheet: View {
    let locations: [TravelLocation]
    let referenceLocations: [ReferenceLocation]

    @Environment(\.dismiss) private var dismiss
    @State private var drilldown: StatsDrilldown?
    @State private var isPresentingContinents = false
    @State private var ratingContinent: TravelContinent?
    @State private var includedRatingKinds = Set(LocationKind.allCases)

    private var statistics: TravelStatistics {
        TravelStatisticsService.calculate(
            from: locations,
            references: referenceLocations
        )
    }

    private var filteredRatings: [StatisticsLocationSummary] {
        statistics.filteredRatings(
            continent: ratingContinent,
            includedKinds: includedRatingKinds
        )
    }

    private var filteredAverage: Double? {
        statistics.averageRating(
            continent: ratingContinent,
            includedKinds: includedRatingKinds
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Travel Stats", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            if statistics.isEmpty {
                ContentUnavailableView(
                    "No travel statistics",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Visited locations and ratings will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        overview
                        coverageSection
                        yearSection
                        highestRatedSection
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 720, height: 720)
        .sheet(item: $drilldown) { selection in
            StatsDrilldownSheet(selection: selection)
        }
        .sheet(isPresented: $isPresentingContinents) {
            VisitedContinentsSheet(continents: statistics.visitedContinents)
        }
    }

    private var overview: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                metric(
                    "UN countries",
                    "\(statistics.visitedCountryCount) / 193",
                    "flag",
                    locations: statistics.visitedCountries
                )
                metric(
                    "UN territories",
                    "\(statistics.visitedTerritoryCount) / 17",
                    "map",
                    locations: statistics.visitedTerritories
                )
            }
            GridRow {
                metric(
                    "Cities logged",
                    "\(statistics.cityCount)",
                    "building.2",
                    locations: statistics.loggedCities
                )
                continentMetric
            }
        }
    }

    private func metric(
        _ title: String,
        _ value: String,
        _ symbol: String,
        locations: [StatisticsLocationSummary]
    ) -> some View {
        Button {
            drilldown = StatsDrilldown(
                title: title,
                groups: [StatsListGroup(title: nil, locations: locations)]
            )
        } label: {
            metricLabel(title, value, symbol)
        }
        .buttonStyle(.plain)
    }

    private var continentMetric: some View {
        Button {
            isPresentingContinents = true
        } label: {
            metricLabel(
                "Continents visited",
                "\(statistics.continentCount) / 6",
                "globe.europe.africa"
            )
        }
        .buttonStyle(.plain)
    }

    private func metricLabel(
        _ title: String,
        _ value: String,
        _ symbol: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
    }

    private var coverageSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Coverage").font(.headline)
            coverageRow(
                "Countries + territories",
                visited: statistics.visitedCountryCount + statistics.visitedTerritoryCount,
                total: 210,
                value: statistics.combinedCoverage
            )
            ForEach(statistics.continentCoverage) { coverage in
                coverageRow(
                    coverage.continent.rawValue,
                    visited: coverage.visited,
                    total: coverage.total,
                    value: coverage.percentage
                )
            }
        }
    }

    private func coverageRow(
        _ title: String,
        visited: Int,
        total: Int,
        value: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text("\(visited) / \(total)")
                    .foregroundStyle(.secondary)
                Text(value, format: .percent.precision(.fractionLength(1)))
                    .foregroundStyle(.secondary)
                    .frame(width: 58, alignment: .trailing)
            }
            ProgressView(value: value)
                .tint(AppPalette.lime)
        }
    }

    @ViewBuilder
    private var yearSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Locations by visit year").font(.headline)
            if statistics.locationsByYear.isEmpty {
                Text("No visit years recorded")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(statistics.locationsByYear) { group in
                    Button {
                        drilldown = StatsDrilldown(
                            title: "Visited in \(group.year)",
                            groups: [StatsListGroup(title: nil, locations: group.locations)]
                        )
                    } label: {
                        HStack {
                            Text(String(group.year))
                            Spacer()
                            Text("\(group.count)")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }

    private var highestRatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Highest rated").font(.headline)
                Spacer()
                Picker("Continent", selection: $ratingContinent) {
                    Text("All continents").tag(TravelContinent?.none)
                    ForEach(TravelContinent.allCases) { continent in
                        Text(continent.rawValue).tag(Optional(continent))
                    }
                }
                .labelsHidden()
                .frame(width: 170)
            }

            HStack(spacing: 16) {
                kindToggle("Countries", kind: .country)
                kindToggle("Territories", kind: .territory)
                kindToggle("Cities", kind: .city)
                Spacer()
                Text(
                    filteredAverage.map { "Average \(String(format: "%.1f", $0)) / 10" }
                        ?? "No average"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            }

            if filteredRatings.isEmpty {
                Text("No rated locations match these filters.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(filteredRatings) { location in
                    statisticsLocationRow(location, showsRating: true)
                    Divider()
                }
            }
        }
    }

    private func kindToggle(_ title: String, kind: LocationKind) -> some View {
        Toggle(title, isOn: Binding(
            get: { includedRatingKinds.contains(kind) },
            set: { isIncluded in
                if isIncluded {
                    includedRatingKinds.insert(kind)
                } else {
                    includedRatingKinds.remove(kind)
                }
            }
        ))
        .toggleStyle(.checkbox)
    }
}

private struct VisitedContinentsSheet: View {
    let continents: [TravelContinent]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Continents visited")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            Divider()

            if continents.isEmpty {
                ContentUnavailableView(
                    "No continents visited",
                    systemImage: "globe",
                    description: Text("Visited continents will appear here.")
                )
            } else {
                List(continents) { continent in
                    Label(continent.rawValue, systemImage: "globe.europe.africa")
                        .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 420, height: 360)
    }
}

private struct StatsDrilldownSheet: View {
    let selection: StatsDrilldown
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(selection.title)
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            Divider()

            if selection.groups.allSatisfy({ $0.locations.isEmpty }) {
                ContentUnavailableView(
                    "No locations",
                    systemImage: "mappin.slash",
                    description: Text("There are no matching saved locations.")
                )
            } else {
                List {
                    ForEach(selection.groups) { group in
                        Section(group.title ?? "") {
                            ForEach(group.locations) { location in
                                statisticsLocationRow(location, showsRating: false)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 420)
    }
}

@ViewBuilder
private func statisticsLocationRow(
    _ location: StatisticsLocationSummary,
    showsRating: Bool
) -> some View {
    HStack(spacing: 9) {
        if location.kind != .city, !location.flag.isEmpty {
            Text(location.flag)
                .accessibilityLabel(location.name)
        }
        VStack(alignment: .leading, spacing: 2) {
            Text(location.name)
            HStack(spacing: 5) {
                Text(location.kind.rawValue.capitalized)
                if location.kind == .city, let countryName = location.countryName {
                    Text("in")
                    if !location.flag.isEmpty {
                        Text(location.flag)
                            .accessibilityLabel(countryName)
                    }
                    Text(countryName)
                }
                if let visitYear = location.visitYear {
                    Text("Year \(visitYear)")
                } else if !location.isVisited {
                    Text("Not visited")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if showsRating, let rating = location.rating {
            Label("\(rating) / 10", systemImage: "star.fill")
                .foregroundStyle(.secondary)
        } else if let rating = location.rating {
            Text("\(rating) / 10")
                .foregroundStyle(.secondary)
        }
    }
    .padding(.vertical, 3)
}
