import SwiftUI
import SwiftData

// New/edit custom exercise (design 4a).
struct ExerciseFormView: View {
    var exercise: Exercise? = nil // nil = create
    var prefillName: String = ""
    var onCreate: ((Exercise) -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: ExerciseType = .weightReps
    @State private var equipment = "Barbell"
    @State private var primaryMuscles: Set<String> = []
    @State private var secondaryMuscles: Set<String> = []
    @State private var instructions = ""
    @State private var isUnilateral = false
    @State private var loaded = false

    static let equipmentOptions = ["Barbell", "Dumbbell", "Machine", "Cable",
                                   "Bodyweight", "Kettlebell", "Band", "Other"]
    static let muscles = ["Chest", "Upper Back", "Lats", "Traps", "Front Delts",
                          "Side Delts", "Rear Delts", "Biceps", "Triceps", "Forearms",
                          "Quads", "Hamstrings", "Glutes", "Calves", "Abs", "Obliques",
                          "Lower Back", "Hip Flexors", "Adductors", "Abductors",
                          "Full Body", "Cardio"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Exercise name", text: $name)
                }
                .listRowBackground(Theme.card)

                Section {
                    typeChips
                        .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                } header: {
                    EyebrowText(text: "TYPE")
                }
                .listRowBackground(Theme.card)

                Section {
                    Toggle("Unilateral (log left & right)", isOn: $isUnilateral)
                        .tint(Theme.accent)
                } header: {
                    EyebrowText(text: "SIDES")
                } footer: {
                    Text("Each set records the left and right side separately.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .listRowBackground(Theme.card)

                Section {
                    Picker("Equipment", selection: $equipment) {
                        ForEach(Self.equipmentOptions, id: \.self) { Text($0) }
                    }
                    NavigationLink {
                        muscleList(title: "Primary muscles", selection: $primaryMuscles)
                    } label: {
                        detailsRow("Primary muscles", value: primaryMuscles)
                    }
                    NavigationLink {
                        muscleList(title: "Secondary muscles", selection: $secondaryMuscles)
                    } label: {
                        detailsRow("Secondary muscles", value: secondaryMuscles)
                    }
                } header: {
                    EyebrowText(text: "DETAILS")
                }
                .listRowBackground(Theme.card)

                Section {
                    TextField("Notes or instructions (optional)",
                              text: $instructions, axis: .vertical)
                        .lineLimit(3...)
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(exercise == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private var typeChips: some View {
        // Simple wrapping chip flow via LazyVGrid.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 8)],
                  alignment: .leading, spacing: 8) {
            ForEach(ExerciseType.allCases) { option in
                Button {
                    type = option
                } label: {
                    Text(option.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(type == option ? Theme.accent : Theme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(type == option
                                    ? Theme.accent.opacity(0.15) : Theme.insetControl)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(type == option ? Theme.accent : .clear,
                                              lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func detailsRow(_ label: String, value: Set<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value.isEmpty ? "None" : value.sorted().joined(separator: ", "))
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
        }
    }

    private func muscleList(title: String, selection: Binding<Set<String>>) -> some View {
        List(Self.muscles, id: \.self) { muscle in
            Button {
                if selection.wrappedValue.contains(muscle) {
                    selection.wrappedValue.remove(muscle)
                } else {
                    selection.wrappedValue.insert(muscle)
                }
            } label: {
                HStack {
                    Text(muscle).foregroundStyle(.white)
                    Spacer()
                    if selection.wrappedValue.contains(muscle) {
                        Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                    }
                }
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let exercise {
            name = exercise.name
            type = exercise.type
            equipment = exercise.equipment
            primaryMuscles = Set(exercise.primaryMuscles)
            secondaryMuscles = Set(exercise.secondaryMuscles)
            instructions = exercise.instructions
            isUnilateral = exercise.isUnilateral
        } else {
            name = prefillName
        }
    }

    private func save() {
        if let exercise {
            exercise.name = name
            exercise.typeRaw = type.rawValue
            exercise.equipment = equipment
            exercise.primaryMuscles = primaryMuscles.sorted()
            exercise.secondaryMuscles = secondaryMuscles.sorted()
            exercise.instructions = instructions
            exercise.isUnilateral = isUnilateral
        } else {
            let created = Exercise(seedID: "custom.\(UUID().uuidString)",
                                   name: name, type: type, equipment: equipment,
                                   primaryMuscles: primaryMuscles.sorted(),
                                   secondaryMuscles: secondaryMuscles.sorted(),
                                   instructions: instructions, isCustom: true,
                                   isUnilateral: isUnilateral)
            context.insert(created)
            try? context.save()
            onCreate?(created)
        }
        dismiss()
    }
}
