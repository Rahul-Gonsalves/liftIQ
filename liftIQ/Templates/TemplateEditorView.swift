import SwiftUI
import SwiftData

// Create/edit a template (sheet).
struct TemplateEditorView: View {
    let template: Template? // nil = new

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TemplateFolder.order) private var folders: [TemplateFolder]

    @State private var name = ""
    @State private var isFavorite = false
    @State private var folderName: String = ""
    @State private var rows: [Row] = []
    @State private var showPicker = false

    struct Row: Identifiable {
        let id = UUID()
        var exercise: Exercise?
        var targetSets: Int
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Template name", text: $name)
                    Picker("Folder", selection: $folderName) {
                        Text("None").tag("")
                        ForEach(folders) { Text($0.name).tag($0.name) }
                    }
                    Toggle("Favorite", isOn: $isFavorite)
                }
                .listRowBackground(Theme.card)

                Section("Exercises") {
                    ForEach($rows) { $row in
                        HStack {
                            Text(row.exercise?.name ?? "?")
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
                            Stepper("\(row.targetSets) sets", value: $row.targetSets, in: 1...10)
                                .font(.mono(13))
                                .fixedSize()
                        }
                    }
                    .onMove { rows.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { rows.remove(atOffsets: $0) }
                    Button {
                        showPicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .foregroundStyle(Theme.accent)
                    }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .environment(\.editMode, .constant(.active))
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { exercise in
                    rows.append(Row(exercise: exercise, targetSets: 3))
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard rows.isEmpty, let template else { return }
        name = template.name
        isFavorite = template.isFavorite
        folderName = template.folder?.name ?? ""
        rows = template.sortedExercises.map {
            Row(exercise: $0.exercise, targetSets: $0.targetSets)
        }
    }

    private func save() {
        let target: Template
        if let template {
            target = template
            // Rewrite exercise rows.
            for old in template.exercises { context.delete(old) }
        } else {
            target = Template(name: name)
            context.insert(target)
        }
        target.name = name
        target.isFavorite = isFavorite
        target.folder = folders.first { $0.name == folderName }
        for (i, row) in rows.enumerated() {
            let te = TemplateExercise(order: i, exercise: row.exercise,
                                      targetSets: row.targetSets)
            te.template = target
            context.insert(te)
        }
        try? context.save()
        dismiss()
    }
}
