import SwiftUI
import SwiftData
import UIKit

// Notifications subpage (design 4b). All local, generated on-device.
struct NotificationSettingsView: View {
    @Environment(\.modelContext) private var context

    @AppStorage("notifMaster") private var master = false
    @AppStorage("notifRestTimer") private var restTimerDone = true
    @AppStorage("notifDailyReminder") private var dailyReminder = false
    @AppStorage("reminderTime") private var reminderTime = 0.0
    @AppStorage("notifSkipRestDays") private var skipRestDays = true
    @AppStorage("notifStreakNudge") private var streakNudge = false
    @AppStorage("nudgeTime") private var nudgeTime = 0.0

    @State private var showDeniedAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Allow notifications", isOn: $master)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .tint(Theme.accent)
                    Text("All reminders are generated on-device")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .card()
                .padding(.top, 8)

                Group {
                    section("WORKOUT") {
                        toggleRow("Rest timer done", $restTimerDone)
                        divider
                        toggleRow("Daily workout reminder", $dailyReminder,
                                  caption: "“Up today: …” from your split")
                        divider
                        timeRow("Reminder time", storage: $reminderTime, defaultHour: 8)
                        divider
                        toggleRow("Skip on rest days", $skipRestDays)
                    }
                    section("STREAK") {
                        toggleRow("Streak at risk", $streakNudge,
                                  caption: "Evening nudge if a scheduled workout is unlogged")
                        divider
                        timeRow("Nudge time", storage: $nudgeTime, defaultHour: 19)
                    }
                }
                .disabled(!master)
                .opacity(master ? 1 : 0.45)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: master) { _, on in
            if on {
                Task {
                    let granted = await NotificationScheduler.requestPermission()
                    if !granted {
                        master = false
                        showDeniedAlert = true
                    }
                    NotificationScheduler.rescheduleAll(context: context)
                }
            } else {
                NotificationScheduler.rescheduleAll(context: context)
            }
        }
        .onDisappear {
            NotificationScheduler.rescheduleAll(context: context)
        }
        .alert("Notifications are off in Settings", isPresented: $showDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow notifications for liftIQ in the system Settings app first.")
        }
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowText(text: title).padding(.top, 8)
            VStack(alignment: .leading, spacing: 0, content: content)
                .card(padding: 14)
        }
    }

    private var divider: some View {
        Divider().overlay(Theme.separator)
    }

    private func toggleRow(_ label: String, _ binding: Binding<Bool>,
                           caption: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(label, isOn: binding)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .tint(Theme.accent)
            if let caption {
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .padding(.vertical, 6)
    }

    private func timeRow(_ label: String, storage: Binding<Double>,
                         defaultHour: Int) -> some View {
        let binding = Binding<Date>(
            get: {
                if storage.wrappedValue > 0 {
                    return Date(timeIntervalSince1970: storage.wrappedValue)
                }
                return Calendar.current.date(
                    bySettingHour: defaultHour, minute: 0, second: 0, of: .now) ?? .now
            },
            set: { storage.wrappedValue = $0.timeIntervalSince1970 }
        )
        return DatePicker(label, selection: binding, displayedComponents: .hourAndMinute)
            .font(.system(size: 14))
            .foregroundStyle(.white)
            .padding(.vertical, 6)
    }
}
