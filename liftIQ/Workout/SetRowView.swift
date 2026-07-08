import SwiftUI
import SwiftData

// One row of the logging grid: SET | PREVIOUS | LBS | REPS | ✓
struct SetRowView: View {
    @Bindable var set: ExerciseSet
    let index: Int // display number among non-warmup sets
    let previous: ExerciseSet? // matching set from last workout, for autofill
    let isCurrent: Bool
    let exerciseType: ExerciseType
    var onComplete: () -> Void

    @Environment(\.modelContext) private var context
    @AppStorage("unitMetricWeight") private var metricWeight = false
    @State private var showDetail = false

    var body: some View {
        HStack(spacing: 8) {
            // Set number / type marker — tap cycles nothing, opens type menu.
            Menu {
                ForEach(SetType.allCases, id: \.self) { type in
                    Button {
                        set.setType = type
                    } label: {
                        if set.setType == type {
                            Label(type.label, systemImage: "checkmark")
                        } else {
                            Text(type.label)
                        }
                    }
                }
                Divider()
                Button("RPE & notes…") { showDetail = true }
            } label: {
                Text(set.setType.marker ?? "\(index)")
                    .font(.mono(15, .semibold))
                    .foregroundStyle(markerColor)
                    .frame(width: 34, height: 30)
            }

            Text(previousLabel)
                .font(.mono(13))
                .foregroundStyle(Theme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            if exerciseType.usesWeight {
                numberField(
                    value: Binding(
                        get: { set.weight.map { Units.displayWeight($0, metric: metricWeight) } },
                        set: { set.weight = $0.map { Units.storeWeight($0, metric: metricWeight) } }
                    ),
                    placeholder: previous?.weight.map {
                        format(Units.displayWeight($0, metric: metricWeight))
                    } ?? "—",
                    decimal: true
                )
            }
            if exerciseType.usesReps {
                numberField(
                    value: Binding(
                        get: { set.reps.map(Double.init) },
                        set: { set.reps = $0.map(Int.init) }
                    ),
                    placeholder: previous?.reps.map(String.init) ?? "—",
                    decimal: false
                )
            }
            if exerciseType.usesDuration {
                numberField(
                    value: Binding(
                        get: { set.durationSec.map { Double($0) / 60 } },
                        set: { set.durationSec = $0.map { Int($0 * 60) } }
                    ),
                    placeholder: "min", decimal: true
                )
            }
            if exerciseType.usesDistance {
                numberField(
                    value: Binding(
                        get: { set.distance },
                        set: { set.distance = $0 }
                    ),
                    placeholder: Units.distanceUnit(metric: false), decimal: true
                )
            }

            Button(action: toggleComplete) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(set.completed ? .black : Theme.secondaryText)
                    .frame(width: 30, height: 30)
                    .background(set.completed ? Theme.success : Theme.insetControl)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(rowBackground)
        .overlay(alignment: .leading) {
            if isCurrent && !set.completed {
                Rectangle().fill(Theme.accent).frame(width: 2)
            }
        }
        .sheet(isPresented: $showDetail) { detailSheet }
    }

    private var markerColor: Color {
        switch set.setType {
        case .warmup: Theme.warmup
        case .failure, .dropSet: Theme.destructive
        case .normal: Theme.secondaryText
        }
    }

    private var rowBackground: Color {
        if set.completed { return Theme.completedRowTint }
        if isCurrent { return Theme.currentRowTint }
        return .clear
    }

    private var previousLabel: String {
        guard let previous else { return "—" }
        if let w = previous.weight, let r = previous.reps {
            return "\(format(Units.displayWeight(w, metric: metricWeight))) × \(r)"
        }
        if let r = previous.reps { return "× \(r)" }
        if let d = previous.durationSec { return WorkoutStats.clock(TimeInterval(d)) }
        return "—"
    }

    private func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func numberField(value: Binding<Double?>, placeholder: String, decimal: Bool) -> some View {
        TextField(placeholder, value: value, format: .number)
            .keyboardType(decimal ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .font(.mono(15, .medium))
            .frame(width: 62, height: 30)
            .background(Theme.insetControl)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isCurrent && !set.completed ? Theme.accent : .clear, lineWidth: 1)
            )
    }

    private func toggleComplete() {
        if set.completed {
            set.completed = false
            return
        }
        // Commit: adopt autofill suggestions if fields were left empty.
        if exerciseType.usesWeight, set.weight == nil { set.weight = previous?.weight }
        if exerciseType.usesReps, set.reps == nil { set.reps = previous?.reps }
        set.completed = true
        onComplete()
    }

    private var detailSheet: some View {
        NavigationStack {
            Form {
                Section("RPE") {
                    Picker("RPE", selection: Binding(
                        get: { set.rpe ?? 0 },
                        set: { set.rpe = $0 == 0 ? nil : $0 }
                    )) {
                        Text("None").tag(0.0)
                        ForEach(Array(stride(from: 6.0, through: 10.0, by: 0.5)), id: \.self) {
                            Text(String(format: "%g", $0)).tag($0)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                Section("Set notes") {
                    TextField("Notes", text: Bindable(set).notes, axis: .vertical)
                }
            }
            .navigationTitle("Set \(index)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showDetail = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
