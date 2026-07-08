import Foundation
import SwiftData

// Full JSON backup/restore — the data-safety net for a sideloaded, local-only
// app. Codable mirror of every entity; restore is wipe-and-replace.
enum BackupService {
    static let lastBackupKey = "lastBackupDate"

    struct Backup: Codable {
        var version = 1
        var exportedAt = Date()
        var exercises: [BExercise] = []
        var workouts: [BWorkout] = []
        var folders: [String] = []
        var templates: [BTemplate] = []
        var splits: [BSplit] = []
        var measurements: [BMeasurement] = []
        var seedVersion: Int = 0
        var currentStreak: Int = 0
        var longestStreak: Int = 0
    }
    struct BExercise: Codable {
        var seedID, name, type, equipment, instructions, notes: String
        var primaryMuscles, secondaryMuscles: [String]
        var isCustom, isHidden: Bool
    }
    struct BSet: Codable {
        var order: Int
        var weight: Double?; var reps: Int?; var durationSec: Int?
        var distance: Double?; var rpe: Double?
        var completed: Bool; var setType, notes: String
    }
    struct BWorkoutExercise: Codable {
        var order: Int; var exerciseSeedID: String?; var notes: String; var sets: [BSet]
    }
    struct BWorkout: Codable {
        var name, notes: String
        var startDate: Date; var endDate: Date?
        var splitDayOrder: Int?
        var exercises: [BWorkoutExercise]
    }
    struct BTemplateExercise: Codable {
        var order, targetSets: Int; var exerciseSeedID: String?
    }
    struct BTemplate: Codable {
        var name: String; var isFavorite: Bool; var folder: String?
        var lastUsed: Date?; var exercises: [BTemplateExercise]
    }
    struct BSplitDay: Codable { var order: Int; var templateName: String? }
    struct BSplit: Codable {
        var name: String
        var isActive, streakFollowsSplit, flexibleOrder: Bool
        var currentDayIndex: Int
        var completedOrdersThisCycle: [Int]
        var lastAdvanceDate: Date
        var days: [BSplitDay]
    }
    struct BMeasurement: Codable { var date: Date; var type: String; var value: Double }

    // MARK: - Export

    static func export(context: ModelContext) throws -> URL {
        var backup = Backup()
        let defaults = UserDefaults.standard
        backup.seedVersion = defaults.integer(forKey: SeedImporter.seedVersionKey)
        backup.currentStreak = defaults.integer(forKey: "currentStreak")
        backup.longestStreak = defaults.integer(forKey: SplitService.longestStreakKey)

        backup.exercises = ((try? context.fetch(FetchDescriptor<Exercise>())) ?? []).map {
            BExercise(seedID: $0.seedID, name: $0.name, type: $0.typeRaw,
                      equipment: $0.equipment, instructions: $0.instructions,
                      notes: $0.notes, primaryMuscles: $0.primaryMuscles,
                      secondaryMuscles: $0.secondaryMuscles,
                      isCustom: $0.isCustom, isHidden: $0.isHidden)
        }
        backup.workouts = ((try? context.fetch(FetchDescriptor<Workout>())) ?? []).map { w in
            BWorkout(name: w.name, notes: w.notes, startDate: w.startDate,
                     endDate: w.endDate, splitDayOrder: w.splitDayOrder,
                     exercises: w.sortedExercises.map { we in
                         BWorkoutExercise(order: we.order,
                                          exerciseSeedID: we.exercise?.seedID,
                                          notes: we.notes,
                                          sets: we.sortedSets.map {
                                              BSet(order: $0.order, weight: $0.weight,
                                                   reps: $0.reps, durationSec: $0.durationSec,
                                                   distance: $0.distance, rpe: $0.rpe,
                                                   completed: $0.completed,
                                                   setType: $0.setTypeRaw, notes: $0.notes)
                                          })
                     })
        }
        backup.folders = ((try? context.fetch(FetchDescriptor<TemplateFolder>())) ?? []).map(\.name)
        backup.templates = ((try? context.fetch(FetchDescriptor<Template>())) ?? []).map { t in
            BTemplate(name: t.name, isFavorite: t.isFavorite, folder: t.folder?.name,
                      lastUsed: t.lastUsed,
                      exercises: t.sortedExercises.map {
                          BTemplateExercise(order: $0.order, targetSets: $0.targetSets,
                                            exerciseSeedID: $0.exercise?.seedID)
                      })
        }
        backup.splits = ((try? context.fetch(FetchDescriptor<Split>())) ?? []).map { s in
            BSplit(name: s.name, isActive: s.isActive,
                   streakFollowsSplit: s.streakFollowsSplit, flexibleOrder: s.flexibleOrder,
                   currentDayIndex: s.currentDayIndex,
                   completedOrdersThisCycle: s.completedOrdersThisCycle,
                   lastAdvanceDate: s.lastAdvanceDate,
                   days: s.sortedDays.map {
                       BSplitDay(order: $0.order, templateName: $0.template?.name)
                   })
        }
        backup.measurements = ((try? context.fetch(FetchDescriptor<BodyMeasurement>())) ?? []).map {
            BMeasurement(date: $0.date, type: $0.typeRaw, value: $0.value)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(backup)
        let stamp = Date.now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("liftIQ-backup-\(stamp).json")
        try data.write(to: url)
        defaults.set(Date.now.timeIntervalSince1970, forKey: lastBackupKey)
        return url
    }

    // MARK: - Restore (wipe and replace)

    static func restore(from url: URL, context: ModelContext) throws {
        let needsStop = url.startAccessingSecurityScopedResource()
        defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Backup.self, from: try Data(contentsOf: url))

        try wipe(context: context)

        var exercisesByID: [String: Exercise] = [:]
        for e in backup.exercises {
            let exercise = Exercise(seedID: e.seedID, name: e.name,
                                    type: ExerciseType(rawValue: e.type) ?? .weightReps,
                                    equipment: e.equipment,
                                    primaryMuscles: e.primaryMuscles,
                                    secondaryMuscles: e.secondaryMuscles,
                                    instructions: e.instructions,
                                    isCustom: e.isCustom, isHidden: e.isHidden,
                                    notes: e.notes)
            context.insert(exercise)
            exercisesByID[e.seedID] = exercise
        }
        for w in backup.workouts {
            let workout = Workout(name: w.name, startDate: w.startDate, endDate: w.endDate,
                                  notes: w.notes, splitDayOrder: w.splitDayOrder)
            context.insert(workout)
            for we in w.exercises {
                let workoutExercise = WorkoutExercise(
                    order: we.order,
                    exercise: we.exerciseSeedID.flatMap { exercisesByID[$0] },
                    notes: we.notes)
                workoutExercise.workout = workout
                context.insert(workoutExercise)
                for s in we.sets {
                    let set = ExerciseSet(order: s.order, weight: s.weight, reps: s.reps,
                                          durationSec: s.durationSec, distance: s.distance,
                                          rpe: s.rpe, completed: s.completed,
                                          setType: SetType(rawValue: s.setType) ?? .normal,
                                          notes: s.notes)
                    set.workoutExercise = workoutExercise
                    context.insert(set)
                }
            }
        }
        var foldersByName: [String: TemplateFolder] = [:]
        for (i, name) in backup.folders.enumerated() {
            let folder = TemplateFolder(name: name, order: i)
            context.insert(folder)
            foldersByName[name] = folder
        }
        var templatesByName: [String: Template] = [:]
        for t in backup.templates {
            let template = Template(name: t.name, isFavorite: t.isFavorite,
                                    folder: t.folder.flatMap { foldersByName[$0] })
            template.lastUsed = t.lastUsed
            context.insert(template)
            templatesByName[t.name] = template
            for te in t.exercises {
                let templateExercise = TemplateExercise(
                    order: te.order,
                    exercise: te.exerciseSeedID.flatMap { exercisesByID[$0] },
                    targetSets: te.targetSets)
                templateExercise.template = template
                context.insert(templateExercise)
            }
        }
        for s in backup.splits {
            let split = Split(name: s.name, isActive: s.isActive,
                              streakFollowsSplit: s.streakFollowsSplit,
                              flexibleOrder: s.flexibleOrder)
            split.currentDayIndex = s.currentDayIndex
            split.completedOrdersThisCycle = s.completedOrdersThisCycle
            split.lastAdvanceDate = s.lastAdvanceDate
            context.insert(split)
            for d in s.days {
                let day = SplitDay(order: d.order,
                                   template: d.templateName.flatMap { templatesByName[$0] })
                day.split = split
                context.insert(day)
            }
        }
        for m in backup.measurements {
            context.insert(BodyMeasurement(date: m.date,
                                       type: MeasurementType(rawValue: m.type) ?? .bodyWeight,
                                       value: m.value))
        }
        try context.save()

        let defaults = UserDefaults.standard
        defaults.set(backup.seedVersion, forKey: SeedImporter.seedVersionKey)
        defaults.set(backup.currentStreak, forKey: "currentStreak")
        defaults.set(backup.longestStreak, forKey: SplitService.longestStreakKey)

        // Records are derived; rebuild them from restored history.
        for exercise in exercisesByID.values {
            PRService.rebuild(exercise: exercise, context: context)
        }
        try context.save()
    }

    static func wipe(context: ModelContext) throws {
        try context.delete(model: PersonalRecord.self)
        try context.delete(model: ExerciseSet.self)
        try context.delete(model: WorkoutExercise.self)
        try context.delete(model: Workout.self)
        try context.delete(model: SplitDay.self)
        try context.delete(model: Split.self)
        try context.delete(model: TemplateExercise.self)
        try context.delete(model: Template.self)
        try context.delete(model: TemplateFolder.self)
        try context.delete(model: BodyMeasurement.self)
        try context.delete(model: Exercise.self)
        try context.save()
    }
}
