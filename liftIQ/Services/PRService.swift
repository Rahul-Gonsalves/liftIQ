import Foundation
import SwiftData

// PR detection at workout finish. Records are stored rows (cheap to badge),
// re-evaluated for affected exercises when history is edited.
enum PRService {
    /// Compare the finished workout against stored records; insert/update rows.
    /// Returns the records that were newly set or beaten (for gold-badge flash).
    @discardableResult
    static func evaluate(workout: Workout, context: ModelContext) -> [PersonalRecord] {
        var newRecords: [PersonalRecord] = []
        let all = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []

        func upsert(_ type: PRType, value: Double, exercise: Exercise?) {
            guard value > 0 else { return }
            let existing = all.first {
                $0.typeRaw == type.rawValue && $0.exercise?.seedID == exercise?.seedID
            }
            if let existing {
                guard value > existing.value else { return }
                existing.value = value
                existing.date = workout.endDate ?? .now
                existing.workout = workout
                newRecords.append(existing)
            } else {
                let record = PersonalRecord(type: type, value: value,
                                            date: workout.endDate ?? .now,
                                            exercise: exercise, workout: workout)
                context.insert(record)
                newRecords.append(record)
            }
        }

        for we in workout.exercises {
            guard let exercise = we.exercise else { continue }
            let done = we.sets.filter { $0.completed && $0.setType != .warmup }
            let weights = done.flatMap { [$0.weight, $0.weightRight] }.compactMap { $0 }
            let repsAll = done.flatMap { [$0.reps, $0.repsRight] }.compactMap { $0 }
            let best1RM = done.flatMap { set -> [Double] in
                var candidates: [Double] = []
                if let w = set.weight, let r = set.reps { candidates.append(WorkoutStats.estimated1RM(weight: w, reps: r)) }
                if let w = set.weightRight, let r = set.repsRight { candidates.append(WorkoutStats.estimated1RM(weight: w, reps: r)) }
                return candidates
            }.max() ?? 0
            upsert(.maxWeight, value: weights.max() ?? 0, exercise: exercise)
            upsert(.maxReps, value: Double(repsAll.max() ?? 0), exercise: exercise)
            upsert(.maxSetVolume, value: done.map(\.volume).max() ?? 0, exercise: exercise)
            upsert(.best1RM, value: best1RM, exercise: exercise)
        }
        upsert(.longestWorkout, value: workout.duration, exercise: nil)
        upsert(.largestVolumeWorkout, value: workout.totalVolume, exercise: nil)
        return newRecords
    }

    /// Recompute all records for one exercise from full history (after edits/deletes).
    static func rebuild(exercise: Exercise, context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        for record in all where record.exercise?.seedID == exercise.seedID {
            context.delete(record)
        }
        let workouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        var best: [PRType: (Double, Workout)] = [:]
        for workout in workouts where workout.endDate != nil {
            for we in workout.exercises where we.exercise?.seedID == exercise.seedID {
                let done = we.sets.filter { $0.completed && $0.setType != .warmup }
                let weights = done.flatMap { [$0.weight, $0.weightRight] }.compactMap { $0 }
                let repsAll = done.flatMap { [$0.reps, $0.repsRight] }.compactMap { $0 }
                let best1RM = done.flatMap { set -> [Double] in
                    var c: [Double] = []
                    if let w = set.weight, let r = set.reps { c.append(WorkoutStats.estimated1RM(weight: w, reps: r)) }
                    if let w = set.weightRight, let r = set.repsRight { c.append(WorkoutStats.estimated1RM(weight: w, reps: r)) }
                    return c
                }.max() ?? 0
                let candidates: [PRType: Double] = [
                    .maxWeight: weights.max() ?? 0,
                    .maxReps: Double(repsAll.max() ?? 0),
                    .maxSetVolume: done.map(\.volume).max() ?? 0,
                    .best1RM: best1RM,
                ]
                for (type, value) in candidates where value > (best[type]?.0 ?? 0) {
                    best[type] = (value, workout)
                }
            }
        }
        for (type, (value, workout)) in best {
            context.insert(PersonalRecord(type: type, value: value,
                                          date: workout.endDate ?? .now,
                                          exercise: exercise, workout: workout))
        }
    }

    /// Does this workout hold any PR? (gold badge on history rows)
    static func workoutHoldsPR(_ workout: Workout, records: [PersonalRecord]) -> Int {
        records.count { $0.workout?.persistentModelID == workout.persistentModelID }
    }
}
