import Foundation
import SwiftData

// Imports the bundled exercise database on first launch (idempotent).
enum SeedImporter {
    static let seedVersionKey = "seedVersion"

    struct SeedFile: Decodable {
        let version: Int
        let exercises: [SeedExercise]
    }
    struct SeedExercise: Decodable {
        let seedID: String
        let name: String
        let type: String
        let equipment: String
        let primaryMuscles: [String]
        let secondaryMuscles: [String]
        let instructions: String
    }

    static func importIfNeeded(context: ModelContext) {
        guard let url = Bundle.main.url(forResource: "exercises_seed", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let seed = try? JSONDecoder().decode(SeedFile.self, from: data)
        else {
            assertionFailure("exercises_seed.json missing or malformed")
            return
        }
        // Fast path: already imported this version.
        guard UserDefaults.standard.integer(forKey: seedVersionKey) < seed.version else { return }

        // Insert only missing IDs; never touch user edits (hidden/notes) on re-import.
        let existing = Set(
            ((try? context.fetch(FetchDescriptor<Exercise>())) ?? []).map(\.seedID)
        )
        for e in seed.exercises where !existing.contains(e.seedID) {
            context.insert(Exercise(
                seedID: e.seedID,
                name: e.name,
                type: ExerciseType(rawValue: e.type) ?? .weightReps,
                equipment: e.equipment,
                primaryMuscles: e.primaryMuscles,
                secondaryMuscles: e.secondaryMuscles,
                instructions: e.instructions
            ))
        }
        try? context.save()
        UserDefaults.standard.set(seed.version, forKey: seedVersionKey)
    }
}
