import SwiftUI
import SwiftData
import UIKit

// Settings tab (design 2f).
struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @AppStorage("unitMetricWeight") private var metricWeight = false
    @AppStorage("unitMetricDistance") private var metricDistance = false
    @AppStorage("use24HourTime") private var use24Hour = false
    @AppStorage("appTheme") private var appTheme = "dark"
    @AppStorage("restDefaultDuration") private var restDefault = 120.0
    @AppStorage("autoStartRest") private var autoStartRest = true
    @AppStorage("restSound") private var restSound = true
    @AppStorage("restVibrate") private var restVibrate = true
    @AppStorage("weeklyGoal") private var weeklyGoal = 3
    @AppStorage(BackupService.lastBackupKey) private var lastBackup = 0.0

    @State private var csvURLs: [URL] = []
    @State private var backupURL: URL?
    @State private var showRestorePicker = false
    @State private var restoreCandidate: URL?
    @State private var showResetFirst = false
    @State private var showResetSecond = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    section("UNITS") {
                        pickerRow("Weight", selection: $metricWeight,
                                  options: [(false, "lbs"), (true, "kg")])
                        divider
                        pickerRow("Distance", selection: $metricDistance,
                                  options: [(false, "miles"), (true, "km")])
                        divider
                        pickerRow("Time", selection: $use24Hour,
                                  options: [(false, "12h"), (true, "24h")])
                    }
                    section("APPEARANCE") {
                        HStack {
                            Text("Theme").font(.system(size: 14)).foregroundStyle(.white)
                            Spacer()
                            Picker("", selection: $appTheme) {
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                                Text("System").tag("system")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }
                        .padding(.vertical, 6)
                    }
                    section("REST TIMER") {
                        HStack {
                            Text("Default duration")
                                .font(.system(size: 14)).foregroundStyle(.white)
                            Spacer()
                            Menu {
                                ForEach(Array(stride(from: 30, through: 300, by: 15)), id: \.self) { seconds in
                                    Button(WorkoutStats.clock(TimeInterval(seconds))) {
                                        restDefault = Double(seconds)
                                    }
                                }
                            } label: {
                                Text(WorkoutStats.clock(restDefault))
                                    .font(.mono(14, .semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.vertical, 6)
                        divider
                        toggleRow("Auto-start after set", $autoStartRest)
                        divider
                        toggleRow("Sound", $restSound)
                        divider
                        toggleRow("Vibration", $restVibrate)
                    }
                    section("GOAL") {
                        Stepper("Weekly workout goal: \(weeklyGoal)",
                                value: $weeklyGoal, in: 1...7)
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .padding(.vertical, 4)
                    }
                    section("NOTIFICATIONS") {
                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            HStack {
                                Text("Notifications")
                                    .font(.system(size: 14)).foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    dataSection
                    Text("LIFTIQ 1.0 · LOCAL ONLY")
                        .font(.mono(10))
                        .kerning(1)
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Settings")
            .sheet(isPresented: .init(
                get: { !csvURLs.isEmpty }, set: { if !$0 { csvURLs = [] } }
            )) {
                ShareSheet(items: csvURLs)
            }
            .sheet(item: $backupURL) { url in
                ShareSheet(items: [url])
            }
            .fileImporter(isPresented: $showRestorePicker,
                          allowedContentTypes: [.json]) { result in
                if case .success(let url) = result { restoreCandidate = url }
            }
            .confirmationDialog(
                "Replace ALL current data with this backup?",
                isPresented: .init(get: { restoreCandidate != nil },
                                   set: { if !$0 { restoreCandidate = nil } }),
                titleVisibility: .visible
            ) {
                Button("Restore and replace everything", role: .destructive) {
                    if let url = restoreCandidate {
                        do {
                            try BackupService.restore(from: url, context: context)
                        } catch {
                            errorMessage = "Restore failed: \(error.localizedDescription)"
                        }
                    }
                    restoreCandidate = nil
                }
            }
            .confirmationDialog("Reset all app data?", isPresented: $showResetFirst,
                                titleVisibility: .visible) {
                Button("Continue…", role: .destructive) { showResetSecond = true }
            } message: {
                Text("Workouts, templates, splits, and records will be deleted.")
            }
            .alert("This cannot be undone. Really delete everything?",
                   isPresented: $showResetSecond) {
                Button("Delete everything", role: .destructive) { resetAll() }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Data section

    private var dataSection: some View {
        section("DATA") {
            Button {
                csvURLs = CSVExporter.exportAll(context: context)
            } label: {
                Text("Export all data as CSV")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .padding(.vertical, 8)
            }
            divider
            VStack(alignment: .leading, spacing: 2) {
                Button {
                    do {
                        backupURL = try BackupService.export(context: context)
                    } catch {
                        errorMessage = "Backup failed: \(error.localizedDescription)"
                    }
                } label: {
                    Text("Back up now (JSON)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                Text(lastBackupLabel)
                    .font(.mono(10))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(.vertical, 8)
            divider
            Button {
                showRestorePicker = true
            } label: {
                Text("Restore from backup…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .padding(.vertical, 8)
            }
            divider
            Button {
                showResetFirst = true
            } label: {
                Text("Reset app data…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.destructive)
                    .padding(.vertical, 8)
            }
        }
    }

    private var lastBackupLabel: String {
        guard lastBackup > 0 else { return "LAST BACKUP: NEVER" }
        let days = Calendar.current.dateComponents(
            [.day], from: Date(timeIntervalSince1970: lastBackup), to: .now).day ?? 0
        return days == 0 ? "LAST BACKUP: TODAY" : "LAST BACKUP: \(days) DAY\(days == 1 ? "" : "S") AGO"
    }

    private func resetAll() {
        do {
            try BackupService.wipe(context: context)
        } catch {
            errorMessage = "Reset failed: \(error.localizedDescription)"
            return
        }
        let defaults = UserDefaults.standard
        for key in [SeedImporter.seedVersionKey, "currentStreak",
                    SplitService.longestStreakKey, BackupService.lastBackupKey] {
            defaults.removeObject(forKey: key)
        }
        SeedImporter.importIfNeeded(context: context)
    }

    // MARK: - Building blocks

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

    private func pickerRow(_ label: String, selection: Binding<Bool>,
                           options: [(Bool, String)]) -> some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundStyle(.white)
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.0) { value, name in
                    Text(name).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
        }
        .padding(.vertical, 6)
    }

    private func toggleRow(_ label: String, _ binding: Binding<Bool>) -> some View {
        Toggle(label, isOn: binding)
            .font(.system(size: 14))
            .foregroundStyle(.white)
            .tint(Theme.accent)
            .padding(.vertical, 6)
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// Multi-item share sheet (ShareLink can't take a dynamic [URL] cleanly).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
