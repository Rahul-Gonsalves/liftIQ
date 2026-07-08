import SwiftUI
import SwiftData

// Per-exercise stats, charts, records, history.
struct ExerciseDetailView: View {
    @Bindable var exercise: Exercise

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workout.startDate) private var workouts: [Workout]
    @Query private var records: [PersonalRecord]

    @AppStorage("unitMetricWeight") private var metricWeight = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    /// (workout, its sets of this exercise) for finished workouts, oldest first.
    private var history: [(workout: Workout, sets: [ExerciseSet])] {
        workouts.compactMap { workout in
            guard workout.endDate != nil else { return nil }
            let sets = workout.sortedExercises
                .filter { $0.exercise?.seedID == exercise.seedID }
                .flatMap(\.sortedSets)
                .filter { $0.completed && $0.setType != .warmup }
            return sets.isEmpty ? nil : (workout, sets)
        }
    }

    private var myRecords: [PersonalRecord] {
        records.filter { $0.exercise?.seedID == exercise.seedID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                headerCard
                statTiles
                if history.count > 1 { charts }
                if !myRecords.isEmpty { recordsSection }
                if !history.isEmpty { historySection }
                notesCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Edit exercise") { showEdit = true }
                    Button(exercise.isHidden ? "Restore to library" : "Hide from library") {
                        exercise.isHidden.toggle()
                    }
                    if exercise.isCustom {
                        Button("Delete exercise", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) { ExerciseFormView(exercise: exercise) }
        .confirmationDialog("Delete this custom exercise?",
                            isPresented: $showDeleteConfirm) {
            Button("Delete exercise", role: .destructive) {
                context.delete(exercise)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("Past workouts keep their sets, but lose the exercise link.")
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("\(exercise.equipment) · \(exercise.primaryMuscles.joined(separator: ", "))")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondaryText)
                if exercise.isUnilateral {
                    Text("Unilateral")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.insetControl)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            if !exercise.secondaryMuscles.isEmpty {
                Text("Also: \(exercise.secondaryMuscles.joined(separator: ", "))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.tertiaryText)
            }
            if !exercise.instructions.isEmpty {
                DisclosureGroup("Instructions") {
                    Text(exercise.instructions)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            }
        }
        .card()
        .padding(.top, 8)
    }

    // MARK: - Stats

    private var allSets: [ExerciseSet] { history.flatMap(\.sets) }

    private var statTiles: some View {
        let volume = allSets.reduce(0) { $0 + $1.volume }
        let bestWeight = allSets.flatMap { [$0.weight, $0.weightRight] }.compactMap { $0 }.max() ?? 0
        let bestReps = allSets.flatMap { [$0.reps, $0.repsRight] }.compactMap { $0 }.max() ?? 0
        let bestSetVolume = allSets.map(\.volume).max() ?? 0
        let best1RM = allSets.flatMap { set -> [Double] in
            var c: [Double] = []
            if let w = set.weight, let r = set.reps { c.append(WorkoutStats.estimated1RM(weight: w, reps: r)) }
            if let w = set.weightRight, let r = set.repsRight { c.append(WorkoutStats.estimated1RM(weight: w, reps: r)) }
            return c
        }.max() ?? 0

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                   GridItem(.flexible())], spacing: 10) {
            statTile("VOLUME", weightLabel(volume))
            statTile("EST 1RM", weightLabel(best1RM), color: Theme.gold)
            statTile("BEST WT", weightLabel(bestWeight))
            statTile("BEST REPS", "\(bestReps)")
            statTile("BEST SET", weightLabel(bestSetVolume))
            statTile("SESSIONS", "\(history.count)")
        }
    }

    private func statTile(_ label: String, _ value: String, color: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            EyebrowText(text: label)
            Text(value)
                .font(.mono(16, .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .card(padding: 12)
    }

    private func weightLabel(_ lbs: Double) -> String {
        WorkoutStats.grouped(Units.displayWeight(lbs, metric: metricWeight))
    }

    // MARK: - Charts

    private var charts: some View {
        VStack(spacing: 10) {
            ChartCardView(
                title: "\(exercise.name) · est. 1RM",
                points: history.map { entry in
                    ChartPoint(
                        date: entry.workout.startDate,
                        value: Units.displayWeight(
                            entry.sets.flatMap { set -> [Double] in
                                var c: [Double] = []
                                if let w = set.weight, let r = set.reps { c.append(WorkoutStats.estimated1RM(weight: w, reps: r)) }
                                if let w = set.weightRight, let r = set.repsRight { c.append(WorkoutStats.estimated1RM(weight: w, reps: r)) }
                                return c
                            }.max() ?? 0,
                            metric: metricWeight))
                },
                color: Theme.gold)
            ChartCardView(
                title: "\(exercise.name) · max weight",
                points: history.map { entry in
                    ChartPoint(
                        date: entry.workout.startDate,
                        value: Units.displayWeight(
                            entry.sets.flatMap { [$0.weight, $0.weightRight] }.compactMap { $0 }.max() ?? 0,
                            metric: metricWeight))
                },
                color: Theme.accent)
        }
    }

    // MARK: - Records

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowText(text: "RECORDS")
            VStack(spacing: 0) {
                ForEach(myRecords, id: \.typeRaw) { record in
                    HStack {
                        Text(record.type.label)
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(recordValue(record))
                            .font(.mono(14, .semibold))
                            .foregroundStyle(Theme.gold)
                        Text(record.date.formatted(.dateTime.month(.abbreviated).day()).uppercased())
                            .font(.mono(11))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .padding(.vertical, 9)
                    if record.typeRaw != myRecords.last?.typeRaw {
                        Divider().overlay(Theme.separator)
                    }
                }
            }
            .card(padding: 14)
        }
    }

    private func recordValue(_ record: PersonalRecord) -> String {
        switch record.type {
        case .maxReps: "\(Int(record.value))"
        default: "\(weightLabel(record.value)) \(Units.weightUnit(metric: metricWeight))"
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowText(text: "HISTORY")
            ForEach(history.reversed(), id: \.workout.persistentModelID) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.workout.startDate
                        .formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                        .uppercased())
                        .font(.mono(11))
                        .foregroundStyle(Theme.tertiaryText)
                    Text(entry.sets.map { setLabel($0) }.joined(separator: ", "))
                        .font(.mono(13))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .card(padding: 12)
            }
        }
    }

    private func setLabel(_ set: ExerciseSet) -> String {
        if exercise.isUnilateral {
            let left = sideLabel(weight: set.weight, reps: set.reps, duration: set.durationSec)
            let right = sideLabel(weight: set.weightRight, reps: set.repsRight, duration: set.durationSecRight)
            if left != "—" || right != "—" { return "L \(left) · R \(right)" }
            return "—"
        }
        return sideLabel(weight: set.weight, reps: set.reps, duration: set.durationSec)
    }

    private func sideLabel(weight: Double?, reps: Int?, duration: Int?) -> String {
        if let w = weight, let r = reps {
            return "\(Int(Units.displayWeight(w, metric: metricWeight)))×\(r)"
        }
        if let r = reps { return "×\(r)" }
        if let d = duration { return WorkoutStats.clock(TimeInterval(d)) }
        return "—"
    }

    private var notesCard: some View {
        TextField("Notes", text: $exercise.notes, axis: .vertical)
            .font(.system(size: 14))
            .lineLimit(2...)
            .card(padding: 13)
    }
}
