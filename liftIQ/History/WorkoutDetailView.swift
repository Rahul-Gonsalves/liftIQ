import SwiftUI
import SwiftData

// Read/edit a finished workout.
struct WorkoutDetailView: View {
    @Bindable var workout: Workout

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("unitMetricWeight") private var metricWeight = false

    @State private var duplicated: Workout?
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                headerCard
                ForEach(workout.sortedExercises) { we in
                    exerciseCard(we)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Duplicate as new workout") {
                        duplicated = WorkoutSession.duplicate(workout, context: context)
                    }
                    Button("Delete workout", role: .destructive) {
                        showDeleteConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .fullScreenCover(item: $duplicated) { ActiveWorkoutView(workout: $0) }
        .confirmationDialog("Delete this workout?", isPresented: $showDeleteConfirm) {
            Button("Delete workout", role: .destructive) {
                let affected = workout.exercises.compactMap(\.exercise)
                context.delete(workout)
                try? context.save()
                for exercise in affected {
                    PRService.rebuild(exercise: exercise, context: context)
                }
                try? context.save()
                dismiss()
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Workout name", text: $workout.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            DatePicker("Date", selection: $workout.startDate)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryText)
            Text(meta)
                .font(.mono(12))
                .foregroundStyle(Theme.tertiaryText)
            TextField("Notes", text: $workout.notes, axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryText)
        }
        .card()
        .padding(.top, 8)
    }

    private var meta: String {
        let volume = WorkoutStats.grouped(
            Units.displayWeight(workout.totalVolume, metric: metricWeight))
        let unit = Units.weightUnit(metric: metricWeight).uppercased()
        return "\(WorkoutStats.shortDuration(workout.duration)) · \(volume) \(unit) · \(workout.completedSetCount) SETS"
    }

    private func exerciseCard(_ we: WorkoutExercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(we.exercise?.name ?? "Exercise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button(role: .destructive) {
                    let affected = we.exercise
                    context.delete(we)
                    try? context.save()
                    if let affected {
                        PRService.rebuild(exercise: affected, context: context)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            ForEach(we.sortedSets) { set in
                setRow(set, in: we)
            }
        }
        .card(padding: 14)
    }

    private func setRow(_ set: ExerciseSet, in we: WorkoutExercise) -> some View {
        let isUnilateral = we.exercise?.isUnilateral ?? false
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(set.setType.marker ?? "\(we.sortedSets.filter { $0.setType != .warmup }.firstIndex { $0.persistentModelID == set.persistentModelID }.map { $0 + 1 } ?? 0)")
                    .font(.mono(14, .semibold))
                    .foregroundStyle(set.setType == .warmup ? Theme.warmup : Theme.secondaryText)
                    .frame(width: 26)
                if isUnilateral { Text("L").font(.mono(11, .semibold)).foregroundStyle(Theme.accent) }
                if we.exercise?.type.usesWeight ?? true {
                    TextField("wt", value: weightBinding(set), format: .number)
                        .keyboardType(.decimalPad)
                        .font(.mono(14))
                        .frame(width: 70)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 5)
                        .background(Theme.insetControl)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text("×").foregroundStyle(Theme.tertiaryText)
                }
                if we.exercise?.type.usesReps ?? true {
                    TextField("reps", value: Binding(
                        get: { set.reps }, set: { set.reps = $0 }
                    ), format: .number)
                        .keyboardType(.numberPad)
                        .font(.mono(14))
                        .frame(width: 54)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 5)
                        .background(Theme.insetControl)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Spacer()
                if !set.completed {
                    Text("SKIPPED").font(.mono(10)).foregroundStyle(Theme.tertiaryText)
                }
                Button {
                    let affected = we.exercise
                    context.delete(set)
                    try? context.save()
                    if let affected { PRService.rebuild(exercise: affected, context: context) }
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            if isUnilateral {
                HStack(spacing: 10) {
                    Spacer().frame(width: 26)
                    Text("R").font(.mono(11, .semibold)).foregroundStyle(Theme.secondaryText)
                    if we.exercise?.type.usesWeight ?? true {
                        TextField("wt", value: weightRightBinding(set), format: .number)
                            .keyboardType(.decimalPad)
                            .font(.mono(14))
                            .frame(width: 70)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 5)
                            .background(Theme.insetControl)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("×").foregroundStyle(Theme.tertiaryText)
                    }
                    if we.exercise?.type.usesReps ?? true {
                        TextField("reps", value: Binding(
                            get: { set.repsRight }, set: { set.repsRight = $0 }
                        ), format: .number)
                            .keyboardType(.numberPad)
                            .font(.mono(14))
                            .frame(width: 54)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 5)
                            .background(Theme.insetControl)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .onChange(of: set.weight) { rebuildLater(we) }
        .onChange(of: set.reps) { rebuildLater(we) }
        .onChange(of: set.weightRight) { rebuildLater(we) }
        .onChange(of: set.repsRight) { rebuildLater(we) }
    }

    private func weightBinding(_ set: ExerciseSet) -> Binding<Double?> {
        Binding(
            get: { set.weight.map { Units.displayWeight($0, metric: metricWeight) } },
            set: { set.weight = $0.map { Units.storeWeight($0, metric: metricWeight) } }
        )
    }

    private func weightRightBinding(_ set: ExerciseSet) -> Binding<Double?> {
        Binding(
            get: { set.weightRight.map { Units.displayWeight($0, metric: metricWeight) } },
            set: { set.weightRight = $0.map { Units.storeWeight($0, metric: metricWeight) } }
        )
    }

    private func rebuildLater(_ we: WorkoutExercise) {
        guard let exercise = we.exercise else { return }
        PRService.rebuild(exercise: exercise, context: context)
    }
}
