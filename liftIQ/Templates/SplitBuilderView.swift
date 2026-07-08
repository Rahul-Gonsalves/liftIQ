import SwiftUI
import SwiftData

// Split builder (design 3b), presented as sheet.
struct SplitBuilderView: View {
    let split: Split? // nil = new

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Template.name) private var templates: [Template]
    @Query private var allSplits: [Split]

    @State private var name = ""
    @State private var days: [DayRow] = []
    @State private var streakFollowsSplit = true
    @State private var flexibleOrder = false
    @State private var showTemplatePicker = false

    struct DayRow: Identifiable {
        let id = UUID()
        var template: Template? // nil = rest
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Split name (e.g. PPL + Rest)", text: $name)
                }
                .listRowBackground(Theme.card)

                Section {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        dayRow(index: index, day: day)
                    }
                    .onMove { days.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { days.remove(atOffsets: $0) }
                } header: {
                    EyebrowText(text: "CYCLE · \(days.count) DAYS")
                }
                .listRowBackground(Theme.card)

                Section {
                    Button {
                        showTemplatePicker = true
                    } label: {
                        Label("Template Day", systemImage: "plus")
                            .foregroundStyle(Theme.accent)
                    }
                    Button {
                        days.append(DayRow(template: nil))
                    } label: {
                        Label("Rest Day", systemImage: "moon")
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .listRowBackground(Theme.card)

                Section {
                    Toggle(isOn: $streakFollowsSplit) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Streak follows this split")
                            Text("Rest days in the cycle keep the streak alive")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                    }
                    Toggle(isOn: $flexibleOrder) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Flexible order")
                            Text("Any day from the cycle counts, in any order")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                    }
                } header: {
                    EyebrowText(text: "STREAK RULES")
                }
                .listRowBackground(Theme.card)

                if split != nil {
                    Section {
                        Button("Delete split", role: .destructive) { deleteSplit() }
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(split == nil ? "New Split" : "Edit Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || days.isEmpty)
                }
            }
            .sheet(isPresented: $showTemplatePicker) { templatePicker }
            .onAppear(perform: load)
        }
    }

    private func dayRow(index: Int, day: DayRow) -> some View {
        HStack(spacing: 12) {
            if let template = day.template {
                Text("\(index + 1)")
                    .font(.mono(13, .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28, height: 28)
                    .background(Theme.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name).font(.system(size: 15, weight: .medium))
                    Text("Template · \(template.exercises.count) exercises")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.tertiaryText)
                }
            } else {
                Image(systemName: "moon.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(Theme.insetControl)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest Day").font(.system(size: 15, weight: .medium))
                    Text("Counts as on-track")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
        }
    }

    private var templatePicker: some View {
        NavigationStack {
            List(templates) { template in
                Button {
                    days.append(DayRow(template: template))
                    showTemplatePicker = false
                } label: {
                    HStack {
                        Text(template.name).foregroundStyle(.white)
                        Spacer()
                        Text("\(template.exercises.count) exercises")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Choose Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showTemplatePicker = false }
                }
            }
        }
    }

    private func load() {
        guard days.isEmpty, let split else { return }
        name = split.name
        streakFollowsSplit = split.streakFollowsSplit
        flexibleOrder = split.flexibleOrder
        days = split.sortedDays.map { DayRow(template: $0.template) }
    }

    private func save() {
        let target: Split
        if let split {
            target = split
            for old in split.days { context.delete(old) }
            // Cycle shape changed: restart position rather than point past the end.
            target.currentDayIndex = 0
            target.completedOrdersThisCycle = []
        } else {
            target = Split(name: name)
            target.lastAdvanceDate = Calendar.current.startOfDay(for: .now)
            context.insert(target)
        }
        target.name = name
        target.streakFollowsSplit = streakFollowsSplit
        target.flexibleOrder = flexibleOrder
        target.isActive = true
        for other in allSplits where other.persistentModelID != target.persistentModelID {
            other.isActive = false
        }
        for (i, day) in days.enumerated() {
            let splitDay = SplitDay(order: i, template: day.template)
            splitDay.split = target
            context.insert(splitDay)
        }
        try? context.save()
        NotificationScheduler.rescheduleAll(context: context)
        dismiss()
    }

    private func deleteSplit() {
        if let split {
            context.delete(split)
            try? context.save()
            NotificationScheduler.rescheduleAll(context: context)
        }
        dismiss()
    }
}
