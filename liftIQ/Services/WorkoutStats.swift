import Foundation

// Shared math + formatting for stats, timers, and unit display.
enum WorkoutStats {
    /// Epley estimated 1RM.
    static func estimated1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0, weight > 0 else { return 0 }
        return reps == 1 ? weight : weight * (1 + Double(reps) / 30)
    }

    /// "32:14" or "1:02:33".
    static func clock(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval))
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }

    /// "52:08" style short duration for meta lines; hours become "1h 12m".
    static func shortDuration(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval))
        return s >= 3600 ? "\(s / 3600)h \((s % 3600) / 60)m" : clock(interval)
    }

    /// Grouped mono number: 6240 -> "6,240".
    static func grouped(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = value < 100 ? 1 : 0
        return f.string(from: value as NSNumber) ?? "0"
    }
}

// Unit conversion: storage is always lbs / miles.
enum Units {
    static let lbsPerKg = 2.2046226218
    static let milesPerKm = 0.6213711922

    static func displayWeight(_ lbs: Double, metric: Bool) -> Double {
        metric ? lbs / lbsPerKg : lbs
    }
    static func storeWeight(_ entered: Double, metric: Bool) -> Double {
        metric ? entered * lbsPerKg : entered
    }
    static func weightUnit(metric: Bool) -> String { metric ? "kg" : "lbs" }

    static func displayDistance(_ miles: Double, metric: Bool) -> Double {
        metric ? miles / milesPerKm : miles
    }
    static func storeDistance(_ entered: Double, metric: Bool) -> Double {
        metric ? entered * milesPerKm : entered
    }
    static func distanceUnit(metric: Bool) -> String { metric ? "km" : "mi" }
}
