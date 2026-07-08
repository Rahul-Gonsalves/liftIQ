import SwiftUI
import SwiftData

// Searchable exercise list used by workout logging and the template editor.
// Presents as a sheet; calls onSelect for each chosen exercise.
struct ExercisePickerView: View {
    var onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var search = ""
    @State private var showNewExercise = false

    private var filtered: [Exercise] {
        exercises.filter { exercise in
            !exercise.isHidden
                && (search.isEmpty
                    || exercise.name.localizedCaseInsensitiveContains(search)
                    || exercise.primaryMuscles.contains {
                        $0.localizedCaseInsensitiveContains(search)
                    })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { exercise in
                    Button {
                        onSelect(exercise)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                            Text("\(exercise.equipment) · \(exercise.primaryMuscles.joined(separator: ", "))")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .listRowBackground(Theme.card)
                }
                if !search.isEmpty {
                    Button {
                        showNewExercise = true
                    } label: {
                        Label("Add \"\(search)\"…", systemImage: "plus.circle.fill")
                            .foregroundStyle(Theme.accent)
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showNewExercise = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showNewExercise) {
                ExerciseFormView(prefillName: search) { created in
                    onSelect(created)
                    dismiss()
                }
            }
        }
    }
}
