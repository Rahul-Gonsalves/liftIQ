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
            upsert(.maxWeight, value: done.compactMap(\.weight).max() ?? 0, exercise: exercise)
            upsert(.maxReps, value: Double(done.compactMap(\.reps).max() ?? 0), exercise: exercise)
            upsert(.maxSetVolume, value: done.map(\.volume).max() ?? 0, exercise: exercise)
            upsert(.best1RM,
                   value: done.map { WorkoutStats.estimated1RM(weight: $0.weight ?? 0, reps: $0.reps ?? 0) }.max() ?? 0,
                   exercise: exercise)
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
                let candidates: [PRType: Double] = [
                    .maxWeight: done.compactMap(\.weight).max() ?? 0,
                    .maxReps: Double(done.compactMap(\.reps).max() ?? 0),
                    .maxSetVolume: done.map(\.volume).max() ?? 0,
                    .best1RM: done.map { WorkoutStats.estimated1RM(weight: $0.weight ?? 0, reps: $0.reps ?? 0) }.max() ?? 0,
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
