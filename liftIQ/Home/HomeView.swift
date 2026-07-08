import SwiftUI
import SwiftData

// Home (design 3c): wordmark, hero card, stat tiles, recent list.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @Query private var splits: [Split]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @Query private var records: [PersonalRecord]
    @Query private var templates: [Template]

    @AppStorage("unitMetricWeight") private var metricWeight = false
    @AppStorage("lastBackupDate") private var lastBackup = 0.0

    @State private var presentedWorkout: Workout?
    @State private var showTemplatePicker = false

    private var activeSplit: Split? { splits.first(where: \.isActive) }
    private var activeWorkout: Workout? { workouts.first { $0.endDate == nil } }
    private var finished: [Workout] { workouts.filter { $0.endDate != nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    heroCard
                    secondaryButtons
                    statTiles
                    if backupOverdue { backupNudge }
                    recentSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .fullScreenCover(item: $presentedWorkout) { workout in
                ActiveWorkoutView(workout: workout)
            }
            .sheet(isPresented: $showTemplatePicker) { templatePicker }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Wordmark()
            Text(subline)
                .font(.mono(12, .semibold))
                .kerning(1)
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.top, 8)
    }

    private var subline: String {
        let date = Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            .uppercased()
        guard let split = activeSplit else {
            let week = Calendar.current.component(.weekOfYear, from: .now)
            return "\(date) · WEEK \(week)"
        }
        let dayCount = split.days.count
        if split.flexibleOrder {
            return "\(date) · \(split.name.uppercased()) · \(split.completedOrdersThisCycle.count)/\(dayCount) DONE"
        }
        return "\(date) · \(split.name.uppercased()) · DAY \(split.currentDayIndex + 1)/\(dayCount)"
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroCard: some View {
        if let active = activeWorkout {
            inProgressHero(active)
        } else {
            upTodayHero
        }
    }

    private func inProgressHero(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                EyebrowText(
                    text: "IN PROGRESS · \(WorkoutStats.clock(timeline.date.timeIntervalSince(workout.startDate)))",
                    color: Theme.accent)
            }
            Text(workout.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text("\(doneExerciseCount(workout))/\(workout.exercises.count) exercises · \(volumeLabel(workout.totalVolume)) so far")
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryText)
            Button {
                presentedWorkout = workout
            } label: {
                Text("Resume")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .card(border: Theme.accent.opacity(0.5))
    }

    @ViewBuilder
    private var upTodayHero: some View {
        if let split = activeSplit, let day = SplitService.upTodayDay(split: split) {
            VStack(alignment: .leading, spacing: 10) {
                EyebrowText(text: "UP TODAY · FROM YOUR SPLIT", color: Theme.accent)
                Text(day.template?.name ?? "Rest Day")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text(heroMeta(split: split, day: day))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondaryText)
                if let template = day.template {
                    Button {
                        presentedWorkout = WorkoutSession.start(
                            template: template, context: context, splitDayOrder: day.order)
                    } label: {
                        Text("Start")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                } else {
                    Label("Rest day — your streak is safe", systemImage: "moon.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.success)
                }
            }
            .card(border: Theme.accent.opacity(0.5))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                EyebrowText(text: "READY WHEN YOU ARE")
                Text("Start a workout")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Button {
                    presentedWorkout = WorkoutSession.startEmpty(context: context)
                } label: {
                    Text("Start Empty Workout")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
            .card(border: Theme.accent.opacity(0.5))
        }
    }

    private func heroMeta(split: Split, day: SplitDay) -> String {
        guard let template = day.template else {
            return "Scheduled rest · streak stays safe"
        }
        let count = template.exercises.count
        let days = split.sortedDays
        let nextIndex = (days.firstIndex { $0.order == day.order }.map { $0 + 1 } ?? 0) % max(days.count, 1)
        let next = days.indices.contains(nextIndex)
            ? (days[nextIndex].template?.name ?? "Rest") : "—"
        return "\(count) exercises · next: \(next)"
    }

    private var secondaryButtons: some View {
        HStack(spacing: 10) {
            Button {
                presentedWorkout = WorkoutSession.startEmpty(context: context)
            } label: {
                Text("+ Empty Workout")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            Button {
                showTemplatePicker = true
            } label: {
                Text("From Template")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.white)
        .buttonStyle(.bordered)
        .tint(.white.opacity(0.15))
        .disabled(activeWorkout != nil)
    }

    // MARK: - Stat tiles

    private var statTiles: some View {
        HStack(spacing: 10) {
            cycleTile
            streakTile
            bodyWeightTile
        }
    }

    @ViewBuilder
    private var cycleTile: some View {
        if let split = activeSplit {
            let days = split.sortedDays
            let position = split.flexibleOrder
                ? split.completedOrdersThisCycle.count : split.currentDayIndex
            VStack(alignment: .leading, spacing: 6) {
                EyebrowText(text: "CYCLE")
                Text("\(position + (split.flexibleOrder ? 0 : 1))/\(days.count)")
                    .font(.mono(20, .bold))
                    .foregroundStyle(.white)
                HStack(spacing: 3) {
                    ForEach(days, id: \.order) { day in
                        Capsule()
                            .fill(segmentColor(day: day, split: split))
                            .frame(height: 3)
                    }
                }
            }
            .card(padding: 13)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                EyebrowText(text: "THIS WEEK")
                Text("\(workoutsThisWeek)")
                    .font(.mono(20, .bold))
                    .foregroundStyle(.white)
                Text("workouts")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .card(padding: 13)
        }
    }

    private func segmentColor(day: SplitDay, split: Split) -> Color {
        let isDone = split.flexibleOrder
            ? split.completedOrdersThisCycle.contains(day.order)
            : day.order < split.currentDayIndex
        let isToday = SplitService.upTodayDay(split: split)?.order == day.order
        if isDone { return Theme.success }
        if isToday { return Theme.accent }
        return .white.opacity(0.1)
    }

    private var streakTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowText(text: "STREAK")
            Text(streakLabel)
                .font(.mono(20, .bold))
                .foregroundStyle(.white)
            Text(activeSplit?.streakFollowsSplit == true ? "rest-day safe" : "weekly goal")
                .font(.system(size: 11))
                .foregroundStyle(activeSplit != nil ? Theme.success : Theme.tertiaryText)
        }
        .card(padding: 13)
    }

    private var streakLabel: String {
        let streak = SplitService.displayStreak(context: context)
        return activeSplit?.streakFollowsSplit == true ? "\(streak)d" : "\(streak)wk"
    }

    private var bodyWeightTile: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowText(text: "BODY WT")
            Text(bodyWeightLabel)
                .font(.mono(20, .bold))
                .foregroundStyle(.white)
            if let delta = weeklyDelta {
                Text("\(delta <= 0 ? "▼" : "▲") \(String(format: "%.1f", abs(delta))) this wk")
                    .font(.mono(11))
                    .foregroundStyle(delta <= 0 ? Theme.success : Theme.secondaryText)
            } else {
                Text("log in Progress")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .card(padding: 13)
    }

    private var bodyWeightLabel: String {
        guard let latest = measurements.first else { return "—" }
        return String(format: "%.1f", Units.displayWeight(latest.value, metric: metricWeight))
    }

    private var weeklyDelta: Double? {
        guard let latest = measurements.first else { return nil }
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: latest.date)!
        guard let prior = measurements.first(where: { $0.date <= weekAgo }) else { return nil }
        return Units.displayWeight(latest.value - prior.value, metric: metricWeight)
    }

    // MARK: - Backup nudge

    private var backupOverdue: Bool {
        guard !finished.isEmpty else { return false }
        guard lastBackup > 0 else { return finished.count >= 5 }
        return Date(timeIntervalSince1970: lastBackup)
            < Calendar.current.date(byAdding: .day, value: -14, to: .now)!
    }

    private var backupNudge: some View {
        Label(
            lastBackup > 0
                ? "Last backup was over 2 weeks ago — Settings → Back up now"
                : "No backup yet — Settings → Back up now",
            systemImage: "externaldrive.badge.exclamationmark"
        )
        .font(.system(size: 13))
        .foregroundStyle(Theme.warmup)
        .card(padding: 12)
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowText(text: "RECENT")
            ForEach(recentRows.indices, id: \.self) { i in
                switch recentRows[i] {
                case .workout(let workout):
                    workoutRow(workout)
                case .rest(let date):
                    restRow(date)
                }
            }
            if finished.isEmpty {
                Text("No workouts yet — start your first one above.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.tertiaryText)
                    .card()
            }
        }
        .padding(.top, 4)
    }

    private enum RecentRow {
        case workout(Workout)
        case rest(Date)
    }

    /// Last 7 calendar days: workouts + synthesized rest-day rows.
    private var recentRows: [RecentRow] {
        let cal = Calendar.current
        let byDay = Dictionary(grouping: finished) { cal.startOfDay(for: $0.startDate) }
        var rows: [RecentRow] = []
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -offset,
                                     to: cal.startOfDay(for: .now)) else { continue }
            if let dayWorkouts = byDay[day] {
                rows.append(contentsOf: dayWorkouts.map(RecentRow.workout))
            } else if offset > 0, activeSplit?.streakFollowsSplit == true,
                      SplitService.displayStreak(context: context) > 0 {
                // No workout that day but streak survived it -> it was a kept rest day.
                rows.append(.rest(day))
            }
        }
        return Array(rows.prefix(6))
    }

    private func workoutRow(_ workout: Workout) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(workout.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    if let order = workout.splitDayOrder {
                        Text("DAY \(order + 1)")
                            .font(.mono(10, .semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
                Text(workoutMeta(workout))
                    .font(.mono(11))
                    .foregroundStyle(Theme.tertiaryText)
            }
            Spacer()
            let prCount = PRService.workoutHoldsPR(workout, records: records)
            if prCount > 0 {
                Text("\(prCount) PR")
                    .font(.mono(11, .semibold))
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.gold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .card(padding: 13)
    }

    private func workoutMeta(_ workout: Workout) -> String {
        let cal = Calendar.current
        let dayLabel: String
        if cal.isDateInToday(workout.startDate) {
            dayLabel = "TODAY"
        } else if cal.isDateInYesterday(workout.startDate) {
            dayLabel = "YDA"
        } else {
            dayLabel = workout.startDate.formatted(.dateTime.weekday(.abbreviated)).uppercased()
        }
        return "\(dayLabel) · \(WorkoutStats.shortDuration(workout.duration)) · \(volumeLabel(workout.totalVolume).uppercased())"
    }

    private func restRow(_ date: Date) -> some View {
        HStack {
            Image(systemName: "moon.fill")
                .foregroundStyle(Theme.tertiaryText)
            Text("Rest Day")
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Text("\(date.formatted(.dateTime.weekday(.abbreviated)).uppercased()) · STREAK KEPT")
                .font(.mono(11))
                .foregroundStyle(Theme.tertiaryText)
        }
        .card(padding: 13)
        .opacity(0.7)
    }

    private func doneExerciseCount(_ workout: Workout) -> Int {
        workout.exercises.count { we in
            !we.sets.isEmpty && we.sets.allSatisfy(\.completed)
        }
    }

    private func volumeLabel(_ lbs: Double) -> String {
        "\(WorkoutStats.grouped(Units.displayWeight(lbs, metric: metricWeight))) \(Units.weightUnit(metric: metricWeight))"
    }

    // MARK: - Template picker

    private var templatePicker: some View {
        NavigationStack {
            List(templates.sorted { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }) { template in
                Button {
                    showTemplatePicker = false
                    presentedWorkout = WorkoutSession.start(template: template, context: context)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(template.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                        Text("\(template.exercises.count) exercises")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Start from Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showTemplatePicker = false }
                }
            }
        }
    }
}
