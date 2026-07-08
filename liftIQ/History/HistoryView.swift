import SwiftUI
import SwiftData

// Workouts tab (design 2c): searchable month-grouped history.
struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @Query private var records: [PersonalRecord]
    @AppStorage("unitMetricWeight") private var metricWeight = false

    @State private var search = ""
    @State private var duplicated: Workout?
    @State private var deleting: Workout?

    private var finished: [Workout] {
        workouts.filter { $0.endDate != nil }.filter { workout in
            guard !search.isEmpty else { return true }
            return workout.name.localizedCaseInsensitiveContains(search)
                || workout.notes.localizedCaseInsensitiveContains(search)
                || workout.exercises.contains {
                    $0.exercise?.name.localizedCaseInsensitiveContains(search) == true
                        || $0.notes.localizedCaseInsensitiveContains(search)
                        || $0.sets.contains { $0.notes.localizedCaseInsensitiveContains(search) }
                }
        }
    }

    private var byMonth: [(label: String, items: [Workout])] {
        let groups = Dictionary(grouping: finished) { workout in
            Calendar.current.dateComponents([.year, .month], from: workout.startDate)
        }
        return groups
            .sorted { a, b in
                (a.key.year!, a.key.month!) > (b.key.year!, b.key.month!)
            }
            .map { key, items in
                let label = items[0].startDate
                    .formatted(.dateTime.month(.wide).year()).uppercased()
                return ("\(label) · \(items.count) WORKOUT\(items.count == 1 ? "" : "S")", items)
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(byMonth, id: \.label) { group in
                        EyebrowText(text: group.label)
                            .padding(.top, 12)
                        ForEach(group.items) { workout in
                            NavigationLink(value: workout) {
                                workoutCard(workout)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if finished.isEmpty {
                        Text(search.isEmpty
                             ? "No workouts yet. Your history shows up here."
                             : "No matches for “\(search)”.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Workouts")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .searchable(text: $search, prompt: "Search workouts, exercises, notes")
            .fullScreenCover(item: $duplicated) { ActiveWorkoutView(workout: $0) }
            .confirmationDialog("Delete this workout?", isPresented: .init(
                get: { deleting != nil }, set: { if !$0 { deleting = nil } }
            )) {
                Button("Delete workout", role: .destructive) {
                    if let workout = deleting {
                        context.delete(workout)
                        try? context.save()
                    }
                    deleting = nil
                }
            } message: {
                Text("This permanently removes the workout and its sets.")
            }
        }
    }

    private func workoutCard(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(workout.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                let prs = PRService.workoutHoldsPR(workout, records: records)
                if prs > 0 {
                    Text("\(prs) PR")
                        .font(.mono(11, .semibold))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.gold.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            Text(meta(workout))
                .font(.mono(11))
                .foregroundStyle(Theme.tertiaryText)
            Text(summary(workout))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .card(padding: 14)
        .contextMenu {
            Button("Duplicate") {
                duplicated = WorkoutSession.duplicate(workout, context: context)
            }
            Button("Delete", role: .destructive) { deleting = workout }
        }
    }

    private func meta(_ workout: Workout) -> String {
        let date = workout.startDate
            .formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            .uppercased()
        let volume = WorkoutStats.grouped(
            Units.displayWeight(workout.totalVolume, metric: metricWeight))
        let unit = Units.weightUnit(metric: metricWeight).uppercased()
        return "\(date) · \(WorkoutStats.shortDuration(workout.duration)) · \(volume) \(unit) · \(workout.completedSetCount) SETS"
    }

    private func summary(_ workout: Workout) -> String {
        workout.sortedExercises.prefix(3).compactMap { we -> String? in
            guard let name = we.exercise?.name else { return nil }
            let done = we.sets.filter(\.completed)
            let topReps = done.compactMap(\.reps).max() ?? 0
            return "\(name) \(done.count)×\(topReps)"
        }
        .joined(separator: " · ")
        + (workout.exercises.count > 3 ? " · …" : "")
    }
}
