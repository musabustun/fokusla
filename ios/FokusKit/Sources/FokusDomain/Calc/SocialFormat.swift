import Foundation

/// Sosyal ekranının Türkçe süre/durum biçimleri — web `features/social/format.ts` karşılığı.
/// Girdi milisaniyedir; değerler aşağı yuvarlanır. Negatif/NaN/sonsuz → 0.
public enum SocialFormat {
    private static let minuteMs = 60_000.0
    /// Taşmayı önlemek için üst sınır; gerçek verilerde asla erişilmez.
    private static let maxUnits = 1e12

    private static func safeMs(_ ms: Double) -> Double {
        ms.isFinite && ms > 0 ? ms : 0
    }

    private static func wholeUnits(_ ms: Double, per unitMs: Double) -> Int {
        Int(Swift.min((safeMs(ms) / unitMs).rounded(.down), maxUnits))
    }

    private static func pad2(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    /// Kısa süre: "2 sa 05 dk", "25 dk", "1 dk'dan az", hiç yoksa "0 dk".
    public static func formatDurationShort(_ ms: Double) -> String {
        if safeMs(ms) == 0 { return "0 dk" }
        let totalMinutes = wholeUnits(ms, per: minuteMs)
        if totalMinutes < 1 { return "1 dk'dan az" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes) dk" }
        return "\(hours) sa \(pad2(minutes)) dk"
    }

    private static func clockParts(_ ms: Double) -> (hours: Int, minutes: Int, seconds: Int) {
        let totalSeconds = wholeUnits(ms, per: 1000)
        return (totalSeconds / 3600, (totalSeconds % 3600) / 60, totalSeconds % 60)
    }

    /// Kronometre: "04:09", "1:05:09".
    public static func formatClock(_ ms: Double) -> String {
        let (hours, minutes, seconds) = clockParts(ms)
        let minutesAndSeconds = "\(pad2(minutes)):\(pad2(seconds))"
        return hours > 0 ? "\(hours):\(minutesAndSeconds)" : minutesAndSeconds
    }

    /// Ekran okuyucu için kronometre: "1 saat 5 dakika 9 saniye".
    public static func formatClockLabel(_ ms: Double) -> String {
        let (hours, minutes, seconds) = clockParts(ms)
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) saat") }
        if minutes > 0 { parts.append("\(minutes) dakika") }
        parts.append("\(seconds) saniye")
        return parts.joined(separator: " ")
    }

    /// Durum etiketi: "Odakta" / "Molada" / "Çevrimdışı".
    public static func presenceLabel(_ state: PresenceState) -> String {
        switch state {
        case .focusing: "Odakta"
        case .onBreak: "Molada"
        case .offline: "Çevrimdışı"
        }
    }

    /// Durum + süre: "Odakta · 25 dk", "Çevrimdışı".
    public static func formatPresenceLine(_ state: PresenceState, _ stateMs: Double) -> String {
        if state == .offline { return presenceLabel(.offline) }
        return "\(presenceLabel(state)) · \(formatDurationShort(stateMs))"
    }

    /// Paylaşılabilir davet metni (web `inviteLink`'in native karşılığı).
    public static func inviteMessage(code: String) -> String {
        "Fokus'ta beni ekle: davet kodum \(code)"
    }
}
