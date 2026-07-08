import SwiftUI
import SwiftData

// Templates tab (design 3a): split card, favorites, folders.
struct TemplatesView: View {
    @Environment(\.modelContext) private var context
    @Query private var splits: [Split]
    @Query(sort: \Template.name) private var templates: [Template]
    @Query(sort: \TemplateFolder.order) private var folders: [TemplateFolder]

    @State private var editingTemplate: Template?
    @State private var showNewTemplate = false
    @State private var editingSplit: Split?
    @State private var showNewSplit = false
    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @State private var startedWorkout: Workout?
    @State private var deletingTemplate: Template?

    private var activeSplit: Split? { splits.first(where: \.isActive) }
    private var favorites: [Template] { templates.filter(\.isFavorite) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let split = activeSplit {
                        splitCard(split)
                    } else {
                        newSplitButton
                    }
                    if !favorites.isEmpty {
                        EyebrowText(text: "★ FAVORITES").padding(.top, 8)
                        ForEach(favorites) { favoriteCard($0) }
                    }
                    folderSections
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("New Template") { showNewTemplate = true }
                        Button("New Split") { showNewSplit = true }
                        Button("New Folder") { showNewFolder = true }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showNewTemplate) { TemplateEditorView(template: nil) }
            .sheet(item: $editingTemplate) { TemplateEditorView(template: $0) }
            .sheet(isPresented: $showNewSplit) { SplitBuilderView(split: nil) }
            .sheet(item: $editingSplit) { SplitBuilderView(split: $0) }
            .fullScreenCover(item: $startedWorkout) { ActiveWorkoutView(workout: $0) }
            .alert("New Folder", isPresented: $showNewFolder) {
                TextField("Folder name", text: $newFolderName)
                Button("Create") {
                    guard !newFolderName.isEmpty else { return }
                    context.insert(TemplateFolder(name: newFolderName,
                                                  order: folders.count))
                    newFolderName = ""
                }
                Button("Cancel", role: .cancel) { newFolderName = "" }
            }
            .confirmationDialog("Delete this template?", isPresented: .init(
                get: { deletingTemplate != nil }, set: { if !$0 { deletingTemplate = nil } }
            )) {
                Button("Delete template", role: .destructive) {
                    if let template = deletingTemplate { context.delete(template) }
                    deletingTemplate = nil
                }
            }
        }
    }

    // MARK: - Split card

    private func splitCard(_ split: Split) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(split.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text(splitMeta(split))
                        .font(.mono(11, .semibold))
                        .kerning(0.8)
                        .foregroundStyle(Theme.tertiaryText)
                }
                Spacer()
                Button("Edit") { editingSplit = split }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(split.sortedDays, id: \.order) { day in
                        dayChip(day, split: split)
                    }
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.gold)
                Text("Streak follows this split — rest days count as on-track")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiaryText)
                Spacer()
                Text("\(SplitService.displayStreak(context: context))d")
                    .font(.mono(12, .semibold))
                    .foregroundStyle(Theme.success)
            }
            .padding(.top, 2)
        }
        .card(border: Theme.accent.opacity(0.5))
        .padding(.top, 8)
    }

    private func splitMeta(_ split: Split) -> String {
        let count = split.days.count
        if split.flexibleOrder {
            return "\(count)-DAY CYCLE · \(split.completedOrdersThisCycle.count) OF \(count) DONE"
        }
        return "\(count)-DAY CYCLE · DAY \(split.currentDayIndex + 1) OF \(count)"
    }

    private func dayChip(_ day: SplitDay, split: Split) -> some View {
        let isDone = split.flexibleOrder
            ? split.completedOrdersThisCycle.contains(day.order)
            : day.order < split.currentDayIndex
        let isToday = SplitService.upTodayDay(split: split)?.order == day.order
        return VStack(spacing: 3) {
            if day.isRest {
                Image(systemName: "moon.fill").font(.system(size: 12))
            } else if isDone {
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
            } else {
                Text("\(day.order + 1)").font(.mono(13, .semibold))
            }
            Text(isToday ? "TODAY" : (day.template?.name ?? "Rest"))
                .font(.mono(9))
                .lineLimit(1)
        }
        .foregroundStyle(isDone ? Theme.success : isToday ? Theme.accent : Theme.secondaryText)
        .frame(width: 74, height: 48)
        .background(isDone ? Theme.success.opacity(0.12)
                    : isToday ? Theme.accent.opacity(0.12) : Theme.insetControl)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isToday ? Theme.accent : .clear, lineWidth: 1)
        )
    }

    private var newSplitButton: some View {
        Button { showNewSplit = true } label: {
            Text("+ New Split")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, minHeight: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Theme.accent.opacity(0.5),
                                      style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
        }
        .padding(.top, 8)
    }

    // MARK: - Favorites

    private func favoriteCard(_ template: Template) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(favoriteMeta(template))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Button {
                template.isFavorite.toggle()
            } label: {
                Image(systemName: "star.fill")
                    .foregroundStyle(Theme.gold)
            }
            .buttonStyle(.plain)
            Button("Start") { start(template) }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .card(padding: 14)
        .contentShape(Rectangle())
        .onTapGesture { editingTemplate = template }
        .contextMenu { templateMenu(template) }
    }

    private func favoriteMeta(_ template: Template) -> String {
        var parts = ["\(template.exercises.count) exercises"]
        if let split = activeSplit,
           split.days.contains(where: { $0.template?.name == template.name }) {
            parts.append("in \(split.name)")
        } else if let lastUsed = template.lastUsed {
            parts.append("last used \(lastUsed.formatted(.relative(presentation: .named)))")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Folders

    private var folderSections: some View {
        let unfoldered = templates.filter { $0.folder == nil && !$0.isFavorite }
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(folders) { folder in
                let items = templates.filter { $0.folder?.name == folder.name }
                if !items.isEmpty {
                    EyebrowText(text: "📁 \(folder.name.uppercased()) · \(items.count)")
                        .padding(.top, 8)
                    ForEach(items) { templateRow($0) }
                }
            }
            if !unfoldered.isEmpty {
                EyebrowText(text: "TEMPLATES").padding(.top, 8)
                ForEach(unfoldered) { templateRow($0) }
            }
            if templates.isEmpty {
                Text("No templates yet. Create one with the + button.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            }
        }
    }

    private func templateRow(_ template: Template) -> some View {
        Button { editingTemplate = template } label: {
            HStack {
                Text(template.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(template.exercises.count)")
                    .font(.mono(13))
                    .foregroundStyle(Theme.tertiaryText)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .card(padding: 14)
        .contextMenu { templateMenu(template) }
    }

    @ViewBuilder
    private func templateMenu(_ template: Template) -> some View {
        Button("Start workout") { start(template) }
        Button(template.isFavorite ? "Unfavorite" : "Favorite") {
            template.isFavorite.toggle()
        }
        Button("Duplicate") {
            let copy = Template(name: template.name + " copy", folder: template.folder)
            context.insert(copy)
            for te in template.sortedExercises {
                let copied = TemplateExercise(order: te.order, exercise: te.exercise,
                                              targetSets: te.targetSets)
                copied.template = copy
                context.insert(copied)
            }
        }
        Button("Delete", role: .destructive) { deletingTemplate = template }
    }

    private func start(_ template: Template) {
        var splitDayOrder: Int?
        if let split = activeSplit,
           let today = SplitService.upTodayDay(split: split),
           today.template?.name == template.name {
            splitDayOrder = today.order
        }
        startedWorkout = WorkoutSession.start(template: template, context: context,
                                              splitDayOrder: splitDayOrder)
    }
}
