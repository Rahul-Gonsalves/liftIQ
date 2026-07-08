import Foundation
import SwiftData
import UserNotifications

// Local notifications only. Triggers can't be conditional, so we concretely
// schedule the next 7 days and re-run on foreground / workout finish /
// split edit / settings change.
enum NotificationScheduler {
    private static let reminderPrefix = "dailyReminder."
    private static let nudgePrefix = "streakNudge."

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func rescheduleAll(context: ModelContext) {
        let center = UNUserNotificationCenter.current()
        let defaults = UserDefaults.standard

        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter {
                $0.hasPrefix(reminderPrefix) || $0.hasPrefix(nudgePrefix)
            }
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        guard defaults.bool(forKey: "notifMaster") else { return }

        let split = SplitService.activeSplit(context: context)
        let cal = Calendar.current
        let workedToday = SplitService.workoutDays(context: context)
            .contains(cal.startOfDay(for: .now))

        // Simulate the cycle forward to know what each of the next 7 days holds.
        var dayInfo: [(date: Date, template: Template?, isRest: Bool)] = []
        if let split {
            var state = SplitService.state(for: split)
            let cycle = SplitService.cycle(for: split)
            let sorted = split.sortedDays
            for offset in 0..<7 {
                let date = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: .now))!
                let engineDay = StreakEngine.upToday(state: state, cycle: cycle,
                                                     flexibleOrder: split.flexibleOrder)
                let splitDay = sorted.first { $0.order == engineDay?.order }
                dayInfo.append((date, splitDay?.template, splitDay?.isRest ?? true))
                // Assume the day gets satisfied so the simulation moves forward.
                if let engineDay {
                    if engineDay.isRest {
                        state = StreakEngine.catchUp(
                            state: .init(currentIndex: state.currentIndex,
                                         completedOrders: state.completedOrders,
                                         lastAdvanceDate: date,
                                         streak: state.streak,
                                         longestStreak: state.longestStreak),
                            cycle: cycle, flexibleOrder: split.flexibleOrder,
                            workoutDays: [], today: cal.date(byAdding: .day, value: 1, to: date)!,
                            calendar: cal)
                    } else {
                        state = StreakEngine.advance(state: state, cycle: cycle,
                                                     flexibleOrder: split.flexibleOrder,
                                                     templateOrder: engineDay.order)
                    }
                }
            }
        }

        // Daily workout reminder.
        if defaults.bool(forKey: "notifDailyReminder") {
            let time = reminderTime(key: "reminderTime", defaultHour: 8)
            let skipRest = defaults.bool(forKey: "notifSkipRestDays")
            for offset in 0..<7 {
                let date = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: .now))!
                let info = dayInfo.first { cal.isDate($0.date, inSameDayAs: date) }
                if skipRest, info?.isRest == true { continue }
                if offset == 0, workedToday { continue }
                var comps = cal.dateComponents([.year, .month, .day], from: date)
                comps.hour = time.hour
                comps.minute = time.minute
                guard let fire = cal.date(from: comps), fire > .now else { continue }
                let content = UNMutableNotificationContent()
                if let template = info?.template {
                    content.title = "Up today: \(template.name)"
                    content.body = "\(template.exercises.count) exercises. Keep the cycle going."
                } else {
                    content.title = "Time to train"
                    content.body = "Log a workout to keep your streak."
                }
                content.sound = .default
                schedule(center: center, id: reminderPrefix + isoDay(date),
                         at: comps, content: content)
            }
        }

        // Streak-at-risk nudge: only on days the split schedules a workout.
        if defaults.bool(forKey: "notifStreakNudge"), split != nil {
            let time = reminderTime(key: "nudgeTime", defaultHour: 19)
            for offset in 0..<7 {
                let date = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: .now))!
                let info = dayInfo.first { cal.isDate($0.date, inSameDayAs: date) }
                guard info?.isRest == false else { continue }
                if offset == 0, workedToday { continue }
                var comps = cal.dateComponents([.year, .month, .day], from: date)
                comps.hour = time.hour
                comps.minute = time.minute
                guard let fire = cal.date(from: comps), fire > .now else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Streak at risk"
                content.body = info?.template.map { "\($0.name) is still unlogged today." }
                    ?? "Today's workout is still unlogged."
                content.sound = .default
                schedule(center: center, id: nudgePrefix + isoDay(date),
                         at: comps, content: content)
            }
        }
    }

    private static func schedule(center: UNUserNotificationCenter, id: String,
                                 at comps: DateComponents, content: UNMutableNotificationContent) {
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private static func reminderTime(key: String, defaultHour: Int) -> (hour: Int, minute: Int) {
        let stored = UserDefaults.standard.double(forKey: key)
        guard stored > 0 else { return (defaultHour, 0) }
        let date = Date(timeIntervalSince1970: stored)
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? defaultHour, c.minute ?? 0)
    }

    private static func isoDay(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }
}
