import SwiftUI
import SwiftData

// Progress tab (design 2e).
struct ProgressDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startDate) private var workouts: [Workout]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @Query private var records: [PersonalRecord]
    @Query private var splits: [Split]

    @AppStorage("unitMetricWeight") private var metricWeight = false
    @AppStorage("progressChartExercise") private var chartExerciseID = ""
    @AppStorage("progressRange") private var range = "6M"

    private static let ranges = ["3M", "6M", "1Y", "All"]

    private var cutoff: Date {
        let cal = Calendar.current
        switch range {
        case "3M": return cal.date(byAdding: .month, value: -3, to: .now)!
        case "6M": return cal.date(byAdding: .month, value: -6, to: .now)!
        case "1Y": return cal.date(byAdding: .year, value: -1, to: .now)!
        default: return .distantPast
        }
    }

    private var finished: [Workout] {
        workouts.filter { $0.endDate != nil }
    }
    private var inRange: [Workout] {
        finished.filter { $0.startDate >= cutoff }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    rangeChips
                    statTiles
                    volumeChart
                    exerciseChart
                    totalsCard
                    linkRow(title: "Body weight", value: bodyWeightLabel) {
                        BodyWeightView()
                    }
                    linkRow(title: "Personal records", value: "\(records.count)") {
                        RecordsListView()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Progress")
        }
    }

    // MARK: - Range chips

    private var rangeChips: some View {
        HStack(spacing: 8) {
            ForEach(Self.ranges, id: \.self) { option in
                Button {
                    range = option
                } label: {
                    Text(option)
                        .font(.mono(13, .semibold))
                        .foregroundStyle(range == option ? .black : Theme.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(range == option ? .white : Theme.insetControl)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Stat tiles

    private var statTiles: some View {
        HStack(spacing: 10) {
            let weeks = max(1.0, Date.now.timeIntervalSince(
                inRange.first?.startDate ?? .now) / (7 * 86400))
            statTile("WORKOUTS", "\(inRange.count)",
                     caption: String(format: "%.1f/wk avg", Double(inRange.count) / weeks))
            statTile("STREAK", streakValue, caption: "longest \(longestStreak)")
            statTile("AVG TIME", avgTime, caption: "per workout")
        }
    }

    private var streakValue: String {
        let streak = SplitService.displayStreak(context: context)
        let splitDriven = splits.first(where: \.isActive)?.streakFollowsSplit == true
        return splitDriven ? "\(streak)d" : "\(streak)wk"
    }

    private var longestStreak: Int {
        UserDefaults.standard.integer(forKey: SplitService.longestStreakKey)
    }

    private var avgTime: String {
        guard !inRange.isEmpty else { return "—" }
        let avg = inRange.reduce(0.0) { $0 + $1.duration } / Double(inRange.count)
        return "\(Int(avg / 60))min"
    }

    private func statTile(_ label: String, _ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            EyebrowText(text: label)
            Text(value)
                .font(.mono(20, .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.system(size: 10))
                .foregroundStyle(Theme.tertiaryText)
        }
        .card(padding: 13)
    }

    // MARK: - Charts

    private var weeklyVolume: [ChartPoint] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: inRange) {
            cal.dateInterval(of: .weekOfYear, for: $0.startDate)?.start
                ?? cal.startOfDay(for: $0.startDate)
        }
        return groups
            .map { ChartPoint(date: $0.key,
                              value: Units.displayWeight(
                                  $0.value.reduce(0) { $0 + $1.totalVolume },
                                  metric: metricWeight)) }
            .sorted { $0.date < $1.date }
    }

    private var volumeChart: some View {
        let points = weeklyVolume
        var delta: String?
        var deltaColor = Theme.success
        if points.count >= 3 {
            // Last full week vs the one before (current partial week excluded).
            let previous = points[points.count - 3].value
            let lastFull = points[points.count - 2].value
            if previous > 0 {
                let percent = (lastFull - previous) / previous * 100
                delta = String(format: "%+.1f%%", percent)
                deltaColor = percent >= 0 ? Theme.success : Theme.destructive
            }
        }
        return ChartCardView(title: "Total volume · weekly", points: points,
                             color: Theme.accent, deltaText: delta, deltaColor: deltaColor)
    }

    /// Exercises that appear in finished workouts, for the swappable chart.
    private var chartableExercises: [Exercise] {
        var seen: [String: Exercise] = [:]
        for workout in finished {
            for we in workout.exercises {
                if let exercise = we.exercise { seen[exercise.seedID] = exercise }
            }
        }
        return seen.values.sorted { $0.name < $1.name }
    }

    @ViewBuilder
    private var exerciseChart: some View {
        let options = chartableExercises
        if let chosen = options.first(where: { $0.seedID == chartExerciseID }) ?? options.first {
            VStack(alignment: .trailing, spacing: 6) {
                ChartCardView(
                    title: "\(chosen.name) · est. 1RM",
                    points: oneRMPoints(chosen),
                    color: Theme.gold)
                Menu {
                    ForEach(options, id: \.seedID) { option in
                        Button(option.name) { chartExerciseID = option.seedID }
                    }
                } label: {
                    Label("Change exercise", systemImage: "arrow.left.arrow.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private func oneRMPoints(_ exercise: Exercise) -> [ChartPoint] {
        inRange.compactMap { workout in
            let best = workout.exercises
                .filter { $0.exercise?.seedID == exercise.seedID }
                .flatMap(\.sets)
                .filter { $0.completed && $0.setType != .warmup }
                .map { WorkoutStats.estimated1RM(weight: $0.weight ?? 0, reps: $0.reps ?? 0) }
                .max()
            guard let best, best > 0 else { return nil }
            return ChartPoint(date: workout.startDate,
                              value: Units.displayWeight(best, metric: metricWeight))
        }
    }

    // MARK: - Totals

    private var totalsCard: some View {
        let cal = Calendar.current
        let thisMonth = finished.count {
            cal.isDate($0.startDate, equalTo: .now, toGranularity: .month)
        }
        let totalVolume = finished.reduce(0.0) { $0 + $1.totalVolume }
        let weeks = max(1.0, Date.now.timeIntervalSince(
            inRange.first?.startDate ?? .now) / (7 * 86400))
        let weeklyVol = inRange.reduce(0.0) { $0 + $1.totalVolume } / weeks

        return VStack(spacing: 0) {
            totalRow("Total workouts", "\(finished.count)")
            Divider().overlay(Theme.separator)
            totalRow("Total volume", volumeLabel(totalVolume))
            Divider().overlay(Theme.separator)
            totalRow("Avg weekly volume", volumeLabel(weeklyVol))
            Divider().overlay(Theme.separator)
            totalRow("Workouts this month", "\(thisMonth)")
        }
        .card(padding: 14)
    }

    private func totalRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .font(.mono(14, .semibold))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.vertical, 9)
    }

    private func volumeLabel(_ lbs: Double) -> String {
        "\(WorkoutStats.grouped(Units.displayWeight(lbs, metric: metricWeight))) \(Units.weightUnit(metric: metricWeight))"
    }

    private var bodyWeightLabel: String {
        guard let latest = measurements.first else { return "—" }
        return "\(String(format: "%.1f", Units.displayWeight(latest.value, metric: metricWeight))) \(Units.weightUnit(metric: metricWeight))"
    }

    private func linkRow<D: View>(title: String, value: String,
                                  @ViewBuilder destination: () -> D) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Text(value)
                    .font(.mono(14))
                    .foregroundStyle(Theme.secondaryText)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .card(padding: 15)
        }
        .buttonStyle(.plain)
    }
}

// Body weight log + chart.
struct BodyWeightView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @AppStorage("unitMetricWeight") private var metricWeight = false

    @State private var showAdd = false
    @State private var entry = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ChartCardView(
                    title: "Body weight",
                    points: measurements.reversed().map {
                        ChartPoint(date: $0.date,
                                   value: Units.displayWeight($0.value, metric: metricWeight))
                    },
                    color: Theme.success,
                    valueLabel: { String(format: "%.1f", $0) })
                VStack(spacing: 0) {
                    ForEach(measurements) { measurement in
                        HStack {
                            Text(measurement.date
                                .formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                                .uppercased())
                                .font(.mono(12))
                                .foregroundStyle(Theme.tertiaryText)
                            Spacer()
                            Text(String(format: "%.1f %@",
                                        Units.displayWeight(measurement.value, metric: metricWeight),
                                        Units.weightUnit(metric: metricWeight)))
                                .font(.mono(14, .semibold))
                                .foregroundStyle(.white)
                            Button {
                                context.delete(measurement)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                        }
                        .padding(.vertical, 9)
                        if measurement.persistentModelID != measurements.last?.persistentModelID {
                            Divider().overlay(Theme.separator)
                        }
                    }
                }
                .card(padding: 14)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle("Body weight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .alert("Log body weight", isPresented: $showAdd) {
            TextField(Units.weightUnit(metric: metricWeight), text: $entry)
                .keyboardType(.decimalPad)
            Button("Save") {
                if let value = Double(entry), value > 0 {
                    context.insert(BodyMeasurement(
                        value: Units.storeWeight(value, metric: metricWeight)))
                    try? context.save()
                }
                entry = ""
            }
            Button("Cancel", role: .cancel) { entry = "" }
        }
    }
}
