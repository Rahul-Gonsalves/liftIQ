import SwiftUI
import SwiftData

// One row of the logging grid: SET | PREVIOUS | LBS | REPS | ✓
// For unilateral exercises, renders two side-lines (L/R) with a shared checkmark.
struct SetRowView: View {
    @Bindable var set: ExerciseSet
    let index: Int // display number among non-warmup sets
    let previous: ExerciseSet? // matching set from last workout, for autofill
    let isCurrent: Bool
    let exerciseType: ExerciseType
    let isUnilateral: Bool
    var onComplete: () -> Void

    @Environment(\.modelContext) private var context
    @AppStorage("unitMetricWeight") private var metricWeight = false
    @State private var showDetail = false

    var body: some View {
        Group {
            if isUnilateral {
                unilateralBody
            } else {
                bilateralBody
            }
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

    // MARK: - Bilateral (unchanged layout)

    private var bilateralBody: some View {
        HStack(spacing: 8) {
            setMenu

            Text(previousLabel(previous))
                .font(.mono(13))
                .foregroundStyle(Theme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            inputFields(weight: leftWeightBinding, reps: leftRepsBinding,
                        duration: leftDurationBinding, distance: leftDistanceBinding,
                        weightPH: previous?.weight.map { format(Units.displayWeight($0, metric: metricWeight)) } ?? "—",
                        repsPH: previous?.reps.map(String.init) ?? "—")

            checkmark
        }
    }

    // MARK: - Unilateral (L / R rows, shared checkmark)

    private var unilateralBody: some View {
        HStack(spacing: 8) {
            setMenu

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("L")
                        .font(.mono(11, .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 14)
                    Text(previousLabel(previous))
                        .font(.mono(13))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    inputFields(weight: leftWeightBinding, reps: leftRepsBinding,
                                duration: leftDurationBinding, distance: leftDistanceBinding,
                                weightPH: previous?.weight.map { format(Units.displayWeight($0, metric: metricWeight)) } ?? "—",
                                repsPH: previous?.reps.map(String.init) ?? "—")
                }
                HStack(spacing: 8) {
                    Text("R")
                        .font(.mono(11, .semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 14)
                    Text(previousLabelRight)
                        .font(.mono(13))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    inputFields(weight: rightWeightBinding, reps: rightRepsBinding,
                                duration: rightDurationBinding, distance: rightDistanceBinding,
                                weightPH: previous?.weightRight.map { format(Units.displayWeight($0, metric: metricWeight)) } ?? "—",
                                repsPH: previous?.repsRight.map(String.init) ?? "—")
                }
            }

            checkmark
        }
    }

    // MARK: - Shared subviews

    private var setMenu: some View {
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
    }

    private var checkmark: some View {
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

    @ViewBuilder
    private func inputFields(weight: Binding<Double?>, reps: Binding<Double?>,
                             duration: Binding<Double?>, distance: Binding<Double?>,
                             weightPH: String, repsPH: String) -> some View {
        if exerciseType.usesWeight {
            numberField(value: weight, placeholder: weightPH, decimal: true)
        }
        if exerciseType.usesReps {
            numberField(value: reps, placeholder: repsPH, decimal: false)
        }
        if exerciseType.usesDuration {
            numberField(value: duration, placeholder: "min", decimal: true)
        }
        if exerciseType.usesDistance {
            numberField(value: distance, placeholder: Units.distanceUnit(metric: false), decimal: true)
        }
    }

    // MARK: - Bindings

    private var leftWeightBinding: Binding<Double?> {
        Binding(
            get: { set.weight.map { Units.displayWeight($0, metric: metricWeight) } },
            set: { set.weight = $0.map { Units.storeWeight($0, metric: metricWeight) } }
        )
    }
    private var leftRepsBinding: Binding<Double?> {
        Binding(get: { set.reps.map(Double.init) }, set: { set.reps = $0.map(Int.init) })
    }
    private var leftDurationBinding: Binding<Double?> {
        Binding(
            get: { set.durationSec.map { Double($0) / 60 } },
            set: { set.durationSec = $0.map { Int($0 * 60) } }
        )
    }
    private var leftDistanceBinding: Binding<Double?> {
        Binding(get: { set.distance }, set: { set.distance = $0 })
    }

    private var rightWeightBinding: Binding<Double?> {
        Binding(
            get: { set.weightRight.map { Units.displayWeight($0, metric: metricWeight) } },
            set: { set.weightRight = $0.map { Units.storeWeight($0, metric: metricWeight) } }
        )
    }
    private var rightRepsBinding: Binding<Double?> {
        Binding(get: { set.repsRight.map(Double.init) }, set: { set.repsRight = $0.map(Int.init) })
    }
    private var rightDurationBinding: Binding<Double?> {
        Binding(
            get: { set.durationSecRight.map { Double($0) / 60 } },
            set: { set.durationSecRight = $0.map { Int($0 * 60) } }
        )
    }
    private var rightDistanceBinding: Binding<Double?> {
        Binding(get: { set.distanceRight }, set: { set.distanceRight = $0 })
    }

    // MARK: - Helpers

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

    private func previousLabel(_ prev: ExerciseSet?) -> String {
        guard let prev else { return "—" }
        if let w = prev.weight, let r = prev.reps {
            return "\(format(Units.displayWeight(w, metric: metricWeight))) × \(r)"
        }
        if let r = prev.reps { return "× \(r)" }
        if let d = prev.durationSec { return WorkoutStats.clock(TimeInterval(d)) }
        return "—"
    }

    private var previousLabelRight: String {
        guard let previous else { return "—" }
        if let w = previous.weightRight, let r = previous.repsRight {
            return "\(format(Units.displayWeight(w, metric: metricWeight))) × \(r)"
        }
        if let r = previous.repsRight { return "× \(r)" }
        if let d = previous.durationSecRight { return WorkoutStats.clock(TimeInterval(d)) }
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
        if exerciseType.usesWeight {
            if set.weight == nil { set.weight = previous?.weight }
            if isUnilateral, set.weightRight == nil { set.weightRight = previous?.weightRight }
        }
        if exerciseType.usesReps {
            if set.reps == nil { set.reps = previous?.reps }
            if isUnilateral, set.repsRight == nil { set.repsRight = previous?.repsRight }
        }
        if exerciseType.usesDuration {
            if set.durationSec == nil { set.durationSec = previous?.durationSec }
            if isUnilateral, set.durationSecRight == nil { set.durationSecRight = previous?.durationSecRight }
        }
        if exerciseType.usesDistance {
            if set.distance == nil { set.distance = previous?.distance }
            if isUnilateral, set.distanceRight == nil { set.distanceRight = previous?.distanceRight }
        }
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
