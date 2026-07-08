import SwiftUI
import SwiftData

// The core logging screen (design 2b). Presented fullScreenCover.
struct ActiveWorkoutView: View {
    @Bindable var workout: Workout

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(RestTimerService.self) private var restTimer
    @AppStorage("unitMetricWeight") private var metricWeight = false
    @AppStorage("restDefaultDuration") private var restDefault = 120.0
    @AppStorage("autoStartRest") private var autoStartRest = true
    @AppStorage("restSound") private var restSound = true
    @AppStorage("restVibrate") private var restVibrate = true

    @State private var showAddExercise = false
    @State private var replacing: WorkoutExercise?
    @State private var showCancelConfirm = false
    @State private var showFinishConfirm = false
    @State private var editingName = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    statStrip
                    if restTimer.isRunning { restBar }
                    exerciseCards
                    addExerciseButton
                    workoutNotes
                    cancelButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { headerTitle }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { showFinishConfirm = true }
                        .font(.system(size: 16, weight: .semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "chevron.down") }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil)
                    }
                }
            }
            .sheet(isPresented: $showAddExercise) {
                ExercisePickerView { addExercise($0) }
            }
            .sheet(item: $replacing) { target in
                ExercisePickerView { replacement in
                    target.exercise = replacement
                }
            }
            .confirmationDialog("Finish workout?", isPresented: $showFinishConfirm) {
                Button("Finish workout") {
                    WorkoutSession.finish(workout, context: context)
                    dismiss()
                }
            } message: {
                Text("\(workout.completedSetCount) sets · \(WorkoutStats.grouped(Units.displayWeight(workout.totalVolume, metric: metricWeight))) \(Units.weightUnit(metric: metricWeight))")
            }
            .confirmationDialog("Cancel this workout?", isPresented: $showCancelConfirm) {
                Button("Discard workout", role: .destructive) {
                    WorkoutSession.cancel(workout, context: context)
                    dismiss()
                }
            } message: {
                Text("All logged sets will be deleted.")
            }
            .alert("Workout name", isPresented: $editingName) {
                TextField("Name", text: $workout.name)
                Button("Done") {}
            }
        }
        .interactiveDismissDisabled()
    }

    private var headerTitle: some View {
        VStack(spacing: 1) {
            Text(workout.name)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Text(workout.startDate.formatted(date: .abbreviated, time: .shortened).uppercased())
                .font(.mono(10))
                .foregroundStyle(Theme.tertiaryText)
        }
        .onTapGesture { editingName = true }
    }

    private var statStrip: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            HStack {
                stat("TIME", WorkoutStats.clock(timeline.date.timeIntervalSince(workout.startDate)))
                stat("VOLUME", WorkoutStats.grouped(Units.displayWeight(workout.totalVolume, metric: metricWeight)))
                stat("SETS", "\(workout.completedSetCount)/\(workout.totalSetCount)")
                stat("REST",
                     restTimer.isRunning ? WorkoutStats.clock(restTimer.remaining) : "—",
                     color: restTimer.isRunning ? Theme.accent : Theme.tertiaryText)
            }
        }
        .card(padding: 13)
        .padding(.top, 8)
    }

    private func stat(_ label: String, _ value: String, color: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.mono(10, .semibold))
                .kerning(0.8)
                .foregroundStyle(Theme.tertiaryText)
            Text(value)
                .font(.mono(16, .semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var restBar: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            HStack(spacing: 12) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.accent.opacity(0.25))
                        Capsule().fill(Theme.accent)
                            .frame(width: geo.size.width * restTimer.progress)
                    }
                }
                .frame(height: 4)
                Text(WorkoutStats.clock(restTimer.remaining))
                    .font(.mono(13, .semibold))
                    .foregroundStyle(Theme.accent)
                Button("+30s") { restTimer.add30() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Button("Skip") { restTimer.skip() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(12)
            .background(Theme.accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var exerciseCards: some View {
        ForEach(workout.sortedExercises) { we in
            ExerciseCardView(
                workoutExercise: we,
                workout: workout,
                collapsed: isCollapsed(we),
                onDelete: { deleteExercise(we) },
                onReplace: { replacing = we },
                onSetCompleted: {
                    if autoStartRest {
                        restTimer.start(duration: restDefault,
                                        sound: restSound, vibrate: restVibrate)
                    }
                }
            )
        }
    }

    /// Upcoming exercises collapse: everything after the first card that still
    /// has incomplete sets stays summarized until it's up.
    private func isCollapsed(_ we: WorkoutExercise) -> Bool {
        let ordered = workout.sortedExercises
        guard let firstOpen = ordered.first(where: { $0.sets.contains { !$0.completed } })
        else { return false }
        return we.order > firstOpen.order && !we.sets.contains(where: \.completed)
    }

    private var addExerciseButton: some View {
        Button { showAddExercise = true } label: {
            Text("+ Add Exercise")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, minHeight: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Theme.accent.opacity(0.5),
                                      style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
        }
    }

    private var workoutNotes: some View {
        TextField("Workout notes", text: $workout.notes, axis: .vertical)
            .font(.system(size: 15))
            .lineLimit(2...)
            .card(padding: 13)
    }

    private var cancelButton: some View {
        Button("Cancel Workout", role: .destructive) { showCancelConfirm = true }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Theme.destructive)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.top, 8)
    }

    private func addExercise(_ exercise: Exercise) {
        let next = (workout.exercises.map(\.order).max() ?? -1) + 1
        let we = WorkoutExercise(order: next, exercise: exercise)
        we.workout = workout
        context.insert(we)
        for i in 0..<3 {
            let set = ExerciseSet(order: i)
            set.workoutExercise = we
            context.insert(set)
        }
    }

    private func deleteExercise(_ we: WorkoutExercise) {
        context.delete(we)
    }
}
