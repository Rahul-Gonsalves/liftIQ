import SwiftUI
import SwiftData

// One exercise's spreadsheet logging grid inside the active workout.
struct ExerciseCardView: View {
    @Bindable var workoutExercise: WorkoutExercise
    let workout: Workout
    var collapsed: Bool
    var onDelete: () -> Void
    var onReplace: () -> Void
    var onSetCompleted: () -> Void

    @Environment(\.modelContext) private var context
    @AppStorage("unitMetricWeight") private var metricWeight = false
    @State private var showNotes = false
    @State private var showHistory = false
    @State private var previous: [ExerciseSet] = []

    private var exercise: Exercise? { workoutExercise.exercise }
    private var type: ExerciseType { exercise?.type ?? .weightReps }
    private var sets: [ExerciseSet] { workoutExercise.sortedSets }
    private var best1RM: Double {
        previous.map { WorkoutStats.estimated1RM(weight: $0.weight ?? 0, reps: $0.reps ?? 0) }
            .max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if !collapsed {
                grid
                addSetButton
            }
        }
        .card(padding: 13)
        .task { previous = exercise.map {
            WorkoutSession.previousSets(exercise: $0, context: context, excluding: workout)
        } ?? [] }
        .sheet(isPresented: $showNotes) { notesSheet }
        .sheet(isPresented: $showHistory) {
            if let exercise {
                NavigationStack { ExerciseDetailView(exercise: exercise) }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise?.name ?? "Exercise")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                if collapsed {
                    Text("\(sets.count(where: \.completed))/\(sets.count) sets")
                        .font(.mono(12))
                        .foregroundStyle(Theme.tertiaryText)
                } else {
                    Text(exercise?.equipment ?? "")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Spacer()
            if best1RM > 0, !collapsed {
                Text("1RM \(WorkoutStats.grouped(Units.displayWeight(best1RM, metric: metricWeight)))")
                    .font(.mono(11, .semibold))
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.gold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            Menu {
                Button("Exercise notes") { showNotes = true }
                Button("History & records") { showHistory = true }
                Button("Replace exercise") { onReplace() }
                Button("Delete exercise", role: .destructive) { onDelete() }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 34, height: 34)
            }
        }
    }

    private var grid: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                Text("SET").frame(width: 34)
                Text("PREVIOUS").frame(maxWidth: .infinity, alignment: .leading)
                if type.usesWeight {
                    Text(Units.weightUnit(metric: metricWeight).uppercased()).frame(width: 62)
                }
                if type.usesReps { Text("REPS").frame(width: 62) }
                if type.usesDuration { Text("MIN").frame(width: 62) }
                if type.usesDistance { Text("DIST").frame(width: 62) }
                Text("✓").frame(width: 30)
            }
            .font(.mono(11, .semibold))
            .foregroundStyle(Theme.tertiaryText)
            .padding(.horizontal, 8)
            .padding(.top, 10)

            ForEach(sets) { set in
                SetRowView(
                    set: set,
                    index: displayIndex(of: set),
                    previous: previousMatch(for: set),
                    isCurrent: set.persistentModelID == currentSet?.persistentModelID,
                    exerciseType: type,
                    isUnilateral: exercise?.isUnilateral ?? false,
                    onComplete: onSetCompleted
                )
                .contextMenu {
                    Button("Duplicate set") { duplicate(set) }
                    Button("Delete set", role: .destructive) { delete(set) }
                }
            }
        }
    }

    private var addSetButton: some View {
        Button {
            let next = (sets.last?.order ?? -1) + 1
            let set = ExerciseSet(order: next, setType: .normal)
            set.workoutExercise = workoutExercise
            context.insert(set)
        } label: {
            Text("+ Add Set")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, minHeight: 40)
        }
    }

    // First incomplete set is "current".
    private var currentSet: ExerciseSet? { sets.first { !$0.completed } }

    private func displayIndex(of set: ExerciseSet) -> Int {
        let working = sets.filter { $0.setType != .warmup }
        return (working.firstIndex { $0.persistentModelID == set.persistentModelID } ?? 0) + 1
    }

    /// Autofill source: previous workout's set at the same working-set position.
    private func previousMatch(for set: ExerciseSet) -> ExerciseSet? {
        guard set.setType != .warmup else { return nil }
        let position = displayIndex(of: set) - 1
        let workingPrev = previous.filter { $0.setType != .warmup }
        return position < workingPrev.count ? workingPrev[position] : workingPrev.last
    }

    private func duplicate(_ set: ExerciseSet) {
        let copy = ExerciseSet(order: set.order + 1, weight: set.weight, reps: set.reps,
                               durationSec: set.durationSec, distance: set.distance,
                               setType: set.setType,
                               weightRight: set.weightRight, repsRight: set.repsRight,
                               durationSecRight: set.durationSecRight, distanceRight: set.distanceRight)
        for later in sets where later.order > set.order { later.order += 1 }
        copy.workoutExercise = workoutExercise
        context.insert(copy)
    }

    private func delete(_ set: ExerciseSet) {
        context.delete(set)
    }

    private var notesSheet: some View {
        NavigationStack {
            Form {
                TextField("Notes for this exercise", text: $workoutExercise.notes, axis: .vertical)
                    .lineLimit(4...)
            }
            .navigationTitle("Exercise notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showNotes = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
