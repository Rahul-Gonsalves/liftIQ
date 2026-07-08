import Foundation

// Stored as raw strings in SwiftData (predicates can't filter enums).

enum ExerciseType: String, CaseIterable, Codable, Identifiable {
    case weightReps, weightOnly, repsOnly, duration, distance
    case bodyweight, assisted, machine, cable, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weightReps: "Weight + reps"
        case .weightOnly: "Weight only"
        case .repsOnly: "Reps only"
        case .duration: "Duration"
        case .distance: "Distance"
        case .bodyweight: "Bodyweight + reps"
        case .assisted: "Assisted"
        case .machine: "Machine"
        case .cable: "Cable"
        case .custom: "Custom"
        }
    }

    var usesWeight: Bool {
        switch self {
        case .weightReps, .weightOnly, .assisted, .machine, .cable, .custom: true
        default: false
        }
    }
    var usesReps: Bool {
        switch self {
        case .weightReps, .repsOnly, .bodyweight, .assisted, .machine, .cable, .custom: true
        default: false
        }
    }
    var usesDuration: Bool { self == .duration || self == .distance }
    var usesDistance: Bool { self == .distance }
}

enum SetType: String, CaseIterable, Codable {
    case normal, warmup, failure, dropSet

    var label: String {
        switch self {
        case .normal: "Normal"
        case .warmup: "Warm-up"
        case .failure: "Failure"
        case .dropSet: "Drop set"
        }
    }
    /// Marker shown in the set-number cell ("W", "F", "D"); nil = show the number.
    var marker: String? {
        switch self {
        case .normal: nil
        case .warmup: "W"
        case .failure: "F"
        case .dropSet: "D"
        }
    }
}

enum PRType: String, CaseIterable, Codable {
    case maxWeight, maxReps, maxSetVolume, best1RM        // per exercise
    case longestWorkout, largestVolumeWorkout, longestStreak // global

    var label: String {
        switch self {
        case .maxWeight: "Highest weight"
        case .maxReps: "Most reps"
        case .maxSetVolume: "Highest volume set"
        case .best1RM: "Best est. 1RM"
        case .longestWorkout: "Longest workout"
        case .largestVolumeWorkout: "Largest volume workout"
        case .longestStreak: "Longest streak"
        }
    }
}

enum MeasurementType: String, Codable {
    case bodyWeight
}
