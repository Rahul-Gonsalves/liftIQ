import Foundation
import SwiftData

// CSV export: small data, build strings in memory, share from tmp.
enum CSVExporter {
    static func escape(_ field: String) -> String {
        field.contains(where: { ",\"\n".contains($0) })
            ? "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
            : field
    }

    private static func row(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    /// Writes all CSV files to tmp and returns their URLs for a share sheet.
    static func exportAll(context: ModelContext) -> [URL] {
        let df = ISO8601DateFormatter()
        var files: [String: String] = [:]

        // Workouts + sets, flattened Strong-style.
        var lines = [row(["workout", "startDate", "endDate", "durationSec", "workoutNotes",
                          "exercise", "exerciseOrder", "setOrder", "setType", "weightLbs",
                          "reps", "durationSecSet", "distanceMiles",
                          "weightRightLbs", "repsRight", "durationSecRightSet", "distanceRightMiles",
                          "rpe", "completed", "setNotes"])]
        let workouts = (try? context.fetch(FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.startDate)]))) ?? []
        for w in workouts {
            for we in w.sortedExercises {
                for set in we.sortedSets {
                    lines.append(row([
                        w.name, df.string(from: w.startDate),
                        w.endDate.map(df.string(from:)) ?? "", String(Int(w.duration)),
                        w.notes, we.exercise?.name ?? "?", String(we.order),
                        String(set.order), set.setTypeRaw,
                        set.weight.map { String($0) } ?? "",
                        set.reps.map(String.init) ?? "",
                        set.durationSec.map(String.init) ?? "",
                        set.distance.map { String($0) } ?? "",
                        set.weightRight.map { String($0) } ?? "",
                        set.repsRight.map(String.init) ?? "",
                        set.durationSecRight.map(String.init) ?? "",
                        set.distanceRight.map { String($0) } ?? "",
                        set.rpe.map { String($0) } ?? "",
                        String(set.completed), set.notes,
                    ]))
                }
            }
        }
        files["workouts.csv"] = lines.joined(separator: "\n")

        // Exercises.
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        files["exercises.csv"] = ([row(["seedID", "name", "type", "equipment",
                                        "primaryMuscles", "secondaryMuscles", "isCustom",
                                        "isHidden", "isUnilateral", "notes"])]
            + exercises.map {
                row([$0.seedID, $0.name, $0.typeRaw, $0.equipment,
                     $0.primaryMuscles.joined(separator: ";"),
                     $0.secondaryMuscles.joined(separator: ";"),
                     String($0.isCustom), String($0.isHidden), String($0.isUnilateral), $0.notes])
            }).joined(separator: "\n")

        // Templates.
        let templates = (try? context.fetch(FetchDescriptor<Template>())) ?? []
        files["templates.csv"] = ([row(["template", "folder", "favorite", "exercise",
                                        "order", "targetSets"])]
            + templates.flatMap { t in
                t.sortedExercises.map {
                    row([t.name, t.folder?.name ?? "", String(t.isFavorite),
                         $0.exercise?.name ?? "?", String($0.order), String($0.targetSets)])
                }
            }).joined(separator: "\n")

        // Measurements.
        let measurements = (try? context.fetch(FetchDescriptor<BodyMeasurement>(
            sortBy: [SortDescriptor(\.date)]))) ?? []
        files["measurements.csv"] = ([row(["date", "type", "value"])]
            + measurements.map {
                row([df.string(from: $0.date), $0.typeRaw, String($0.value)])
            }).joined(separator: "\n")

        // Records.
        let records = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        files["records.csv"] = ([row(["type", "exercise", "value", "date"])]
            + records.map {
                row([$0.typeRaw, $0.exercise?.name ?? "", String($0.value),
                     df.string(from: $0.date)])
            }).joined(separator: "\n")

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("liftIQ-export", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return files.compactMap { name, contents in
            let url = dir.appendingPathComponent(name)
            return (try? contents.write(to: url, atomically: true, encoding: .utf8)) != nil
                ? url : nil
        }
    }
}
