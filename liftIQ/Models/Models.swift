import Foundation
import SwiftData

// All entities co-located. Rules baked in:
// - enums stored as raw strings (predicates can't filter enums)
// - relationships are unordered -> ordered children carry `order: Int`,
//   read through the `sorted…` accessors only
// - weights stored in lbs, distance in miles; converted for display

@Model
final class Exercise {
    @Attribute(.unique) var seedID: String // "seed.<slug>" or "custom.<uuid>"
    var name: String
    var typeRaw: String
    var equipment: String
    var primaryMuscles: [String]
    var secondaryMuscles: [String]
    var instructions: String
    var isCustom: Bool
    var isHidden: Bool
    var notes: String
    var isUnilateral: Bool = false // modifier: log L+R per set; combines with any base type

    var type: ExerciseType { ExerciseType(rawValue: typeRaw) ?? .weightReps }

    init(seedID: String, name: String, type: ExerciseType, equipment: String,
         primaryMuscles: [String] = [], secondaryMuscles: [String] = [],
         instructions: String = "", isCustom: Bool = false, isHidden: Bool = false,
         notes: String = "", isUnilateral: Bool = false) {
        self.seedID = seedID
        self.name = name
        self.typeRaw = type.rawValue
        self.equipment = equipment
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.instructions = instructions
        self.isCustom = isCustom
        self.isHidden = isHidden
        self.notes = notes
        self.isUnilateral = isUnilateral
    }
}

@Model
final class Workout {
    var name: String
    var startDate: Date
    var endDate: Date? // nil == in progress; this IS the crash/kill persistence
    var notes: String
    var splitDayOrder: Int? // which split day this satisfied ("DAY n" tag)
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise] = []

    var sortedExercises: [WorkoutExercise] { exercises.sorted { $0.order < $1.order } }
    var isActive: Bool { endDate == nil }
    var duration: TimeInterval { (endDate ?? .now).timeIntervalSince(startDate) }
    /// Total volume in lbs across completed weight×reps sets.
    var totalVolume: Double {
        exercises.flatMap(\.sets).filter(\.completed)
            .reduce(0) { $0 + $1.volume }
    }
    var completedSetCount: Int { exercises.flatMap(\.sets).filter(\.completed).count }
    var totalSetCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }

    init(name: String, startDate: Date = .now, endDate: Date? = nil,
         notes: String = "", splitDayOrder: Int? = nil) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.splitDayOrder = splitDayOrder
    }
}

@Model
final class WorkoutExercise {
    var order: Int
    var exercise: Exercise? // built-ins never delete; custom deletes nullify
    var notes: String
    var workout: Workout?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workoutExercise)
    var sets: [ExerciseSet] = []

    var sortedSets: [ExerciseSet] { sets.sorted { $0.order < $1.order } }

    init(order: Int, exercise: Exercise?, notes: String = "") {
        self.order = order
        self.exercise = exercise
        self.notes = notes
    }
}

@Model
final class ExerciseSet {
    var order: Int
    var weight: Double? // lbs — left side for unilateral
    var reps: Int?
    var durationSec: Int?
    var distance: Double? // miles
    var rpe: Double?
    var completed: Bool
    var setTypeRaw: String
    var notes: String
    var workoutExercise: WorkoutExercise?
    // Right-side mirrors for unilateral exercises; nil for bilateral.
    var weightRight: Double?
    var repsRight: Int?
    var durationSecRight: Int?
    var distanceRight: Double?

    var setType: SetType {
        get { SetType(rawValue: setTypeRaw) ?? .normal }
        set { setTypeRaw = newValue.rawValue }
    }
    var volume: Double {
        (weight ?? 0) * Double(reps ?? 0)
        + (weightRight ?? 0) * Double(repsRight ?? 0)
    }

    init(order: Int, weight: Double? = nil, reps: Int? = nil, durationSec: Int? = nil,
         distance: Double? = nil, rpe: Double? = nil, completed: Bool = false,
         setType: SetType = .normal, notes: String = "",
         weightRight: Double? = nil, repsRight: Int? = nil,
         durationSecRight: Int? = nil, distanceRight: Double? = nil) {
        self.order = order
        self.weight = weight
        self.reps = reps
        self.durationSec = durationSec
        self.distance = distance
        self.rpe = rpe
        self.completed = completed
        self.setTypeRaw = setType.rawValue
        self.notes = notes
        self.weightRight = weightRight
        self.repsRight = repsRight
        self.durationSecRight = durationSecRight
        self.distanceRight = distanceRight
    }
}

@Model
final class TemplateFolder {
    var name: String
    var order: Int
    @Relationship(deleteRule: .nullify, inverse: \Template.folder)
    var templates: [Template] = []

    init(name: String, order: Int = 0) {
        self.name = name
        self.order = order
    }
}

@Model
final class Template {
    var name: String
    var isFavorite: Bool
    var lastUsed: Date?
    var folder: TemplateFolder?
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise] = []

    var sortedExercises: [TemplateExercise] { exercises.sorted { $0.order < $1.order } }

    init(name: String, isFavorite: Bool = false, folder: TemplateFolder? = nil) {
        self.name = name
        self.isFavorite = isFavorite
        self.folder = folder
    }
}

@Model
final class TemplateExercise {
    var order: Int
    var exercise: Exercise?
    var targetSets: Int
    var template: Template?

    init(order: Int, exercise: Exercise?, targetSets: Int = 3) {
        self.order = order
        self.exercise = exercise
        self.targetSets = targetSets
    }
}

@Model
final class Split {
    var name: String
    var isActive: Bool
    var streakFollowsSplit: Bool
    var flexibleOrder: Bool
    var currentDayIndex: Int
    /// Cycle-day orders already completed this cycle (used when flexibleOrder is on).
    var completedOrdersThisCycle: [Int]
    /// Start of the calendar day the cycle position was last advanced/caught up to.
    var lastAdvanceDate: Date
    @Relationship(deleteRule: .cascade, inverse: \SplitDay.split)
    var days: [SplitDay] = []

    var sortedDays: [SplitDay] { days.sorted { $0.order < $1.order } }

    init(name: String, isActive: Bool = true, streakFollowsSplit: Bool = true,
         flexibleOrder: Bool = false) {
        self.name = name
        self.isActive = isActive
        self.streakFollowsSplit = streakFollowsSplit
        self.flexibleOrder = flexibleOrder
        self.currentDayIndex = 0
        self.completedOrdersThisCycle = []
        self.lastAdvanceDate = Calendar.current.startOfDay(for: .now)
    }
}

@Model
final class SplitDay {
    var order: Int
    var template: Template? // nil == rest day
    var split: Split?

    var isRest: Bool { template == nil }

    init(order: Int, template: Template?) {
        self.order = order
        self.template = template
    }
}

@Model
final class BodyMeasurement {
    var date: Date
    var typeRaw: String
    var value: Double // lbs for bodyWeight

    init(date: Date = .now, type: MeasurementType = .bodyWeight, value: Double) {
        self.date = date
        self.typeRaw = type.rawValue
        self.value = value
    }
}

@Model
final class PersonalRecord {
    var typeRaw: String
    var value: Double
    var date: Date
    var exercise: Exercise? // nil for workout-level records
    var workout: Workout?

    var type: PRType { PRType(rawValue: typeRaw) ?? .maxWeight }

    init(type: PRType, value: Double, date: Date = .now,
         exercise: Exercise? = nil, workout: Workout? = nil) {
        self.typeRaw = type.rawValue
        self.value = value
        self.date = date
        self.exercise = exercise
        self.workout = workout
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self,
        TemplateFolder.self, Template.self, TemplateExercise.self,
        Split.self, SplitDay.self, BodyMeasurement.self, PersonalRecord.self,
    ]
}
