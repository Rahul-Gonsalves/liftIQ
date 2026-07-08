import SwiftUI
import SwiftData

// All personal records, grouped by exercise.
struct RecordsListView: View {
    @Query private var records: [PersonalRecord]
    @AppStorage("unitMetricWeight") private var metricWeight = false

    private var workoutRecords: [PersonalRecord] {
        records.filter { $0.exercise == nil }
            .sorted { $0.typeRaw < $1.typeRaw }
    }

    private var byExercise: [(name: String, items: [PersonalRecord])] {
        Dictionary(grouping: records.filter { $0.exercise != nil }) {
            $0.exercise?.name ?? "?"
        }
        .map { ($0.key, $0.value.sorted { $0.typeRaw < $1.typeRaw }) }
        .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if records.isEmpty {
                    Text("No records yet — finish a workout to set your first PRs.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 60)
                }
                if !workoutRecords.isEmpty {
                    EyebrowText(text: "WORKOUT RECORDS").padding(.top, 8)
                    recordsCard(workoutRecords)
                }
                ForEach(byExercise, id: \.name) { group in
                    EyebrowText(text: group.name.uppercased()).padding(.top, 8)
                    recordsCard(group.items)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle("Personal records")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func recordsCard(_ items: [PersonalRecord]) -> some View {
        VStack(spacing: 0) {
            ForEach(items, id: \.persistentModelID) { record in
                HStack {
                    Text(record.type.label)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(value(record))
                        .font(.mono(14, .semibold))
                        .foregroundStyle(Theme.gold)
                    Text(record.date.formatted(.dateTime.month(.abbreviated).day().year())
                        .uppercased())
                        .font(.mono(10))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.vertical, 9)
                if record.persistentModelID != items.last?.persistentModelID {
                    Divider().overlay(Theme.separator)
                }
            }
        }
        .card(padding: 14)
    }

    private func value(_ record: PersonalRecord) -> String {
        switch record.type {
        case .maxReps:
            "\(Int(record.value))"
        case .longestWorkout:
            WorkoutStats.shortDuration(record.value)
        case .longestStreak:
            "\(Int(record.value)) days"
        default:
            "\(WorkoutStats.grouped(Units.displayWeight(record.value, metric: metricWeight))) \(Units.weightUnit(metric: metricWeight))"
        }
    }
}
