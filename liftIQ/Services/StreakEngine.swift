import Foundation

// Pure streak/cycle logic. Foundation-only on purpose: SwiftData glue lives in
// SplitService.swift, and Tests/streak_check.swift compiles this file with
// plain swiftc as a self-check.
enum StreakEngine {
    struct CycleDay: Equatable {
        let order: Int
        let isRest: Bool
    }

    struct CycleState: Equatable {
        var currentIndex: Int
        var completedOrders: [Int] // flexible mode only
        var lastAdvanceDate: Date  // startOfDay of last processed day
        var streak: Int
        var longestStreak: Int
    }

    enum DayStatus {
        case worked, restKept, broken, pendingToday
    }

    /// Process every whole day since `state.lastAdvanceDate` up to (not including)
    /// today. A day with a workout keeps the streak; a scheduled rest day keeps it
    /// (and advances the cycle); a scheduled workout day with no workout breaks it.
    /// Today stays pending until midnight.
    static func catchUp(
        state: CycleState,
        cycle: [CycleDay],
        flexibleOrder: Bool,
        workoutDays: Set<Date>, // startOfDay values
        today: Date,
        calendar: Calendar = .current
    ) -> CycleState {
        var s = state
        guard !cycle.isEmpty else { return s }
        let todayStart = calendar.startOfDay(for: today)
        var day = calendar.startOfDay(for: s.lastAdvanceDate)

        while day < todayStart {
            if workoutDays.contains(day) {
                s.streak += 1
            } else if isRestAvailable(state: s, cycle: cycle, flexibleOrder: flexibleOrder) {
                s.streak += 1
                consumeRest(state: &s, cycle: cycle, flexibleOrder: flexibleOrder)
            } else {
                s.streak = 0
            }
            s.longestStreak = max(s.longestStreak, s.streak)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        s.lastAdvanceDate = todayStart
        return s
    }

    /// Called when a workout finishes. `templateOrder` is the cycle order of the
    /// template the workout was started from (nil for ad-hoc workouts).
    /// Ad-hoc workouts keep the streak (via catchUp seeing the workout day) but
    /// only advance the cycle in flexible mode when they match a remaining day.
    static func advance(
        state: CycleState,
        cycle: [CycleDay],
        flexibleOrder: Bool,
        templateOrder: Int?
    ) -> CycleState {
        var s = state
        guard !cycle.isEmpty else { return s }
        if flexibleOrder {
            if let order = templateOrder,
               !s.completedOrders.contains(order),
               cycle.contains(where: { $0.order == order && !$0.isRest }) {
                s.completedOrders.append(order)
                wrapIfCycleDone(state: &s, cycle: cycle)
            }
        } else {
            let current = cycle[s.currentIndex % cycle.count]
            if templateOrder == current.order {
                s.currentIndex = (s.currentIndex + 1) % cycle.count
            }
        }
        return s
    }

    /// The split day to surface as "UP TODAY". Strict: the current cycle day.
    /// Flexible: the first not-yet-completed workout day.
    static func upToday(
        state: CycleState,
        cycle: [CycleDay],
        flexibleOrder: Bool
    ) -> CycleDay? {
        guard !cycle.isEmpty else { return nil }
        if flexibleOrder {
            return cycle.first { !$0.isRest && !state.completedOrders.contains($0.order) }
                ?? cycle.first { $0.isRest && !state.completedOrders.contains($0.order) }
        }
        return cycle[state.currentIndex % cycle.count]
    }

    /// Status for a past/present calendar day, for history/home rest-day rows.
    static func status(
        day: Date,
        workoutDays: Set<Date>,
        scheduledRest: Bool,
        today: Date,
        calendar: Calendar = .current
    ) -> DayStatus {
        let d = calendar.startOfDay(for: day)
        if workoutDays.contains(d) { return .worked }
        if calendar.isDate(d, inSameDayAs: today) { return .pendingToday }
        return scheduledRest ? .restKept : .broken
    }

    /// Fallback when no split drives the streak: consecutive weeks (ending with
    /// the current week) that met the weekly workout goal. Current week counts
    /// once it has met the goal.
    static func weeklyStreak(
        workoutDays: Set<Date>,
        goal: Int,
        today: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard goal > 0 else { return 0 }
        var streak = 0
        var weekStart = calendar.dateInterval(of: .weekOfYear, for: today)!.start
        while true {
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
            let count = workoutDays.count { $0 >= weekStart && $0 < weekEnd }
            if count >= goal {
                streak += 1
            } else if calendar.isDate(weekStart, equalTo: today, toGranularity: .weekOfYear) {
                // current, incomplete week: neutral, keep looking back
            } else {
                break
            }
            guard let prev = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart)
            else { break }
            weekStart = prev
            if streak > 1000 { break } // safety bound
        }
        return streak
    }

    // MARK: - internals

    private static func isRestAvailable(
        state: CycleState, cycle: [CycleDay], flexibleOrder: Bool
    ) -> Bool {
        if flexibleOrder {
            return cycle.contains { $0.isRest && !state.completedOrders.contains($0.order) }
        }
        return cycle[state.currentIndex % cycle.count].isRest
    }

    private static func consumeRest(
        state: inout CycleState, cycle: [CycleDay], flexibleOrder: Bool
    ) {
        if flexibleOrder {
            if let rest = cycle.first(where: { $0.isRest && !state.completedOrders.contains($0.order) }) {
                state.completedOrders.append(rest.order)
                wrapIfCycleDone(state: &state, cycle: cycle)
            }
        } else {
            state.currentIndex = (state.currentIndex + 1) % cycle.count
        }
    }

    private static func wrapIfCycleDone(state: inout CycleState, cycle: [CycleDay]) {
        if state.completedOrders.count >= cycle.count {
            state.completedOrders = []
        }
    }
}
