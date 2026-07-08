import Foundation
import SwiftData

// Start/finish/cancel flows shared by Home, Templates, and History.
enum WorkoutSession {
    static func activeWorkout(context: ModelContext) -> Workout? {
        var d = FetchDescriptor<Workout>(predicate: #Predicate { $0.endDate == nil })
        d.sortBy = [SortDescriptor(\.startDate, order: .reverse)]
        let all = (try? context.fetch(d)) ?? []
        // Guard against strays: keep the newest, close out any older ones.
        for stray in all.dropFirst() {
            stray.endDate = stray.startDate
        }
        return all.first
    }

    static func startEmpty(context: ModelContext) -> Workout {
        let workout = Workout(name: defaultName())
        context.insert(workout)
        return workout
    }

    static func start(template: Template, context: ModelContext,
                      splitDayOrder: Int? = nil) -> Workout {
        let workout = Workout(name: template.name, splitDayOrder: splitDayOrder)
        context.insert(workout)
        for te in template.sortedExercises {
            let we = WorkoutExercise(order: te.order, exercise: te.exercise)
            we.workout = workout
            context.insert(we)
            for i in 0..<te.targetSets {
                let set = ExerciseSet(order: i)
                set.workoutExercise = we
                context.insert(set)
            }
        }
        template.lastUsed = .now
        return workout
    }

    /// Duplicate a past workout as a new in-progress one.
    static func duplicate(_ source: Workout, context: ModelContext) -> Workout {
        let workout = Workout(name: source.name)
        context.insert(workout)
        for sourceExercise in source.sortedExercises {
            let we = WorkoutExercise(order: sourceExercise.order,
                                     exercise: sourceExercise.exercise,
                                     notes: sourceExercise.notes)
            we.workout = workout
            context.insert(we)
            for sourceSet in sourceExercise.sortedSets {
                let set = ExerciseSet(order: sourceSet.order, weight: sourceSet.weight,
                                      reps: sourceSet.reps, durationSec: sourceSet.durationSec,
                                      distance: sourceSet.distance, setType: sourceSet.setType,
                                      weightRight: sourceSet.weightRight, repsRight: sourceSet.repsRight,
                                      durationSecRight: sourceSet.durationSecRight,
                                      distanceRight: sourceSet.distanceRight)
                set.workoutExercise = we
                context.insert(set)
            }
        }
        return workout
    }

    /// Finish: stamp end date, drop never-completed empty sets, detect PRs,
    /// advance the split cycle, refresh notifications.
    static func finish(_ workout: Workout, context: ModelContext) {
        workout.endDate = .now
        for we in workout.exercises {
            for set in we.sets where !set.completed && set.weight == nil
                && set.reps == nil && set.durationSec == nil && set.distance == nil
                && set.weightRight == nil && set.repsRight == nil
                && set.durationSecRight == nil && set.distanceRight == nil {
                context.delete(set)
            }
        }
        RestTimerService.shared.skip()
        PRService.evaluate(workout: workout, context: context)
        SplitService.advance(context: context, finished: workout)
        try? context.save()
        NotificationScheduler.rescheduleAll(context: context)
    }

    static func cancel(_ workout: Workout, context: ModelContext) {
        RestTimerService.shared.skip()
        context.delete(workout) // autosaved live edits die with the model
        try? context.save()
    }

    /// Previous performance of an exercise for autofill: latest finished
    /// workout containing it, its sorted sets.
    static func previousSets(exercise: Exercise, context: ModelContext,
                             excluding current: Workout) -> [ExerciseSet] {
        let workouts = ((try? context.fetch(FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]))) ?? [])
        for workout in workouts where workout.endDate != nil
            && workout.persistentModelID != current.persistentModelID {
            if let match = workout.sortedExercises.first(where: {
                $0.exercise?.seedID == exercise.seedID
            }) {
                let done = match.sortedSets.filter(\.completed)
                if !done.isEmpty { return done }
            }
        }
        return []
    }

    private static func defaultName() -> String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Morning Workout"
        case 12..<17: return "Afternoon Workout"
        default: return "Evening Workout"
        }
    }
}
