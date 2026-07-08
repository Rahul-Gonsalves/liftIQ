import Foundation
import Observation
import UserNotifications

// Rest timer: state is just an end date. UI ticks via TimelineView, so it's
// automatically correct after backgrounding; completion in background is a
// scheduled local notification, not a running timer.
@Observable
final class RestTimerService {
    static let shared = RestTimerService()

    private(set) var endDate: Date?
    private(set) var totalDuration: TimeInterval = 0

    private static let endDateKey = "restTimerEndDate"
    private static let durationKey = "restTimerDuration"
    private static let notificationID = "restTimerDone"

    private init() {
        // Restore across app kill.
        let saved = UserDefaults.standard.double(forKey: Self.endDateKey)
        if saved > Date.now.timeIntervalSince1970 {
            endDate = Date(timeIntervalSince1970: saved)
            totalDuration = UserDefaults.standard.double(forKey: Self.durationKey)
        }
    }

    var isRunning: Bool { (endDate ?? .distantPast) > .now }
    var remaining: TimeInterval { max(0, endDate?.timeIntervalSinceNow ?? 0) }
    var progress: Double {
        guard totalDuration > 0, isRunning else { return 0 }
        return 1 - remaining / totalDuration
    }

    func start(duration: TimeInterval, sound: Bool, vibrate: Bool) {
        totalDuration = duration
        endDate = .now.addingTimeInterval(duration)
        persist()
        scheduleNotification(sound: sound)
        _ = vibrate // haptic fires with the notification; in-foreground haptic handled by delegate
    }

    func add30() {
        guard let end = endDate, isRunning else { return }
        endDate = end.addingTimeInterval(30)
        totalDuration += 30
        persist()
        scheduleNotification(sound: true)
    }

    func skip() {
        endDate = nil
        totalDuration = 0
        persist()
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    private func persist() {
        UserDefaults.standard.set(endDate?.timeIntervalSince1970 ?? 0, forKey: Self.endDateKey)
        UserDefaults.standard.set(totalDuration, forKey: Self.durationKey)
    }

    private func scheduleNotification(sound: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        guard remaining > 0,
              UserDefaults.standard.bool(forKey: "notifRestTimer") else { return }
        let content = UNMutableNotificationContent()
        content.title = "Rest done"
        content.body = "Time for your next set."
        if sound { content.sound = .default }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.notificationID,
                                         content: content, trigger: trigger))
    }
}
