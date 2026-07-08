import Foundation
import SwiftData

// Glue between SwiftData models and the pure StreakEngine.
enum SplitService {
    static let longestStreakKey = "longestStreakEver"

    static func activeSplit(context: ModelContext) -> Split? {
        var d = FetchDescriptor<Split>(predicate: #Predicate { $0.isActive })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    static func cycle(for split: Split) -> [StreakEngine.CycleDay] {
        split.sortedDays.map { .init(order: $0.order, isRest: $0.isRest) }
    }

    static func state(for split: Split) -> StreakEngine.CycleState {
        .init(currentIndex: split.currentDayIndex,
              completedOrders: split.completedOrdersThisCycle,
              lastAdvanceDate: split.lastAdvanceDate,
              streak: UserDefaults.standard.integer(forKey: "currentStreak"),
              longestStreak: UserDefaults.standard.integer(forKey: longestStreakKey))
    }

    static func apply(_ s: StreakEngine.CycleState, to split: Split) {
        split.currentDayIndex = s.currentIndex
        split.completedOrdersThisCycle = s.completedOrders
        split.lastAdvanceDate = s.lastAdvanceDate
        UserDefaults.standard.set(s.streak, forKey: "currentStreak")
        UserDefaults.standard.set(s.longestStreak, forKey: longestStreakKey)
    }

    /// Set of startOfDay dates that have at least one finished workout.
    static func workoutDays(context: ModelContext) -> Set<Date> {
        let workouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        let cal = Calendar.current
        return Set(workouts.filter { $0.endDate != nil }.map { cal.startOfDay(for: $0.startDate) })
    }

    /// Process elapsed days (rest-day catch-up + streak). Call on app foreground.
    static func catchUp(context: ModelContext) {
        guard let split = activeSplit(context: context), split.streakFollowsSplit else { return }
        let s = StreakEngine.catchUp(
            state: state(for: split),
            cycle: cycle(for: split),
            flexibleOrder: split.flexibleOrder,
            workoutDays: workoutDays(context: context),
            today: .now
        )
        apply(s, to: split)
    }

    /// Advance cycle after finishing a workout started from a split-day template.
    static func advance(context: ModelContext, finished workout: Workout) {
        guard let split = activeSplit(context: context) else { return }
        var s = state(for: split)
        s = StreakEngine.advance(
            state: s,
            cycle: cycle(for: split),
            flexibleOrder: split.flexibleOrder,
            templateOrder: workout.splitDayOrder
        )
        // A finished workout today makes today's streak status immediate.
        let cal = Calendar.current
        if cal.isDateInToday(workout.startDate),
           s.lastAdvanceDate <= cal.startOfDay(for: .now) {
            // streak for today counts once; catchUp won't double it because
            // lastAdvanceDate moves to tomorrow after today is processed.
        }
        apply(s, to: split)
        // Longest-streak PR row.
        let longest = s.longestStreak
        let records = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        if let row = records.first(where: { $0.typeRaw == PRType.longestStreak.rawValue }) {
            if Double(longest) > row.value {
                row.value = Double(longest)
                row.date = .now
            }
        } else if longest > 0 {
            context.insert(PersonalRecord(type: .longestStreak, value: Double(longest)))
        }
    }

    /// Streak to display now: processed streak + 1 if today already has a workout.
    static func displayStreak(context: ModelContext) -> Int {
        let base = UserDefaults.standard.integer(forKey: "currentStreak")
        guard let split = activeSplit(context: context), split.streakFollowsSplit else {
            let goal = max(1, UserDefaults.standard.integer(forKey: "weeklyGoal"))
            return StreakEngine.weeklyStreak(workoutDays: workoutDays(context: context),
                                             goal: goal, today: .now)
        }
        let todayWorked = workoutDays(context: context)
            .contains(Calendar.current.startOfDay(for: .now))
        return base + (todayWorked ? 1 : 0)
    }

    /// Template order of "up today", for tagging workouts started from the split.
    static func upTodayDay(split: Split) -> SplitDay? {
        let engineDay = StreakEngine.upToday(
            state: state(for: split),
            cycle: cycle(for: split),
            flexibleOrder: split.flexibleOrder
        )
        return split.sortedDays.first { $0.order == engineDay?.order }
    }
}
