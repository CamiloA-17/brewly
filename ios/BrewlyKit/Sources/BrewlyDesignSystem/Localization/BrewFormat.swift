import Foundation

/// Formats brewing values for display.
public enum BrewFormat {
    /// `16.67` → `"1:16.7"`.
    public static func ratio(_ value: Double) -> String {
        "1:" + number(value, maxFractionDigits: 1)
    }

    /// `15` → `"15 g"`, `15.5` → `"15.5 g"`.
    public static func grams(_ value: Double) -> String {
        number(value, maxFractionDigits: 1) + " g"
    }

    public static func temperature(_ celsius: Double) -> String {
        number(celsius, maxFractionDigits: 1) + " °C"
    }

    /// `185` → `"3:05"`; durations of an hour or more → `"12 h 30 min"`.
    public static func duration(_ seconds: Int) -> String {
        if seconds >= 3_600 {
            let hours = seconds / 3_600
            let minutes = (seconds % 3_600) / 60
            return minutes == 0 ? "\(hours) h" : "\(hours) h \(minutes) min"
        }
        let minutes = seconds / 60
        let rest = seconds % 60
        return "\(minutes):" + (rest < 10 ? "0\(rest)" : "\(rest)")
    }

    public static func percent(_ value: Double) -> String {
        number(value, maxFractionDigits: 2) + " %"
    }

    public static func altitude(min: Int?, max: Int?) -> String? {
        switch (min, max) {
        case let (min?, max?) where min != max: "\(min)–\(max) m"
        case let (min?, _): "\(min) m"
        case let (nil, max?): "\(max) m"
        case (nil, nil): nil
        }
    }

    public static func number(_ value: Double, maxFractionDigits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(0...maxFractionDigits)))
    }
}
