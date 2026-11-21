import Foundation

/// Odak ekranındaki süre biçimleri — web `features/focus/formatDuration.ts` karşılığı (aynı vakalar).
/// Girdi milisaniyedir; değerler aşağı yuvarlanır (floor). Negatif/NaN/sonsuz → 0.
public enum FocusFormat {
    /// "1 sa 5 dk" içindeki tek bir (sayı, birim) çifti.
    public struct DurationPart: Sendable, Equatable {
        public var value: Int
        public var unit: String

        public init(value: Int, unit: String) {
            self.value = value
            self.unit = unit
        }
    }

    private static let msPerSecond = 1000.0
    private static let secondsPerMinute = 60
    private static let secondsPerHour = 3600
    /// Taşmayı önlemek için üst sınır (≈ 31 bin yıl); gerçek verilerde asla erişilmez.
    private static let maxSeconds = 1e12

    private static func wholeSeconds(_ ms: Double) -> Int {
        guard ms.isFinite, ms > 0 else { return 0 }
        return Int(Swift.min((ms / msPerSecond).rounded(.down), maxSeconds))
    }

    private static func pad2(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    /// Kronometre görünümü: "05:09"; 1 saatten itibaren "1:05:09".
    public static func clock(_ ms: Double) -> String {
        let total = wholeSeconds(ms)
        let hours = total / secondsPerHour
        let minutes = (total % secondsPerHour) / secondsPerMinute
        let seconds = total % secondsPerMinute
        let minutesAndSeconds = "\(pad2(minutes)):\(pad2(seconds))"
        return hours > 0 ? "\(hours):\(minutesAndSeconds)" : minutesAndSeconds
    }

    /// Süre parçaları: "45 sn" → [45 sn]; "1 sa 5 dk" → [1 sa, 5 dk]; 1 dakikadan itibaren saniye düşer.
    public static func durationParts(_ ms: Double) -> [DurationPart] {
        let totalSeconds = wholeSeconds(ms)
        if totalSeconds < secondsPerMinute { return [DurationPart(value: totalSeconds, unit: "sn")] }
        let totalMinutes = totalSeconds / secondsPerMinute
        let hours = totalMinutes / secondsPerMinute
        let minutes = totalMinutes % secondsPerMinute
        if hours == 0 { return [DurationPart(value: minutes, unit: "dk")] }
        if minutes == 0 { return [DurationPart(value: hours, unit: "sa")] }
        return [DurationPart(value: hours, unit: "sa"), DurationPart(value: minutes, unit: "dk")]
    }

    /// Metin olarak süre: "45 sn", "25 dk", "1 sa", "1 sa 5 dk".
    public static func durationText(_ ms: Double) -> String {
        durationParts(ms).map { "\($0.value) \($0.unit)" }.joined(separator: " ")
    }
}
