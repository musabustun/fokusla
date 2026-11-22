import Foundation

/// Günlük odak hedefi hesapları — SAF fonksiyonlar. Hedef, `UserProfile.dailyFocusGoalMinutes`
/// (dakika, `nil` = kapalı) alanında saklanır. Web karşılığı yoktur (web'de arayüz yok).
///
/// **Bugün ekranı için kullanım:**
/// ```swift
/// let totalMs = try FocusCalc.dailyFocusTotalMs(sessions:segments:day:now:)   // bugünkü odak
/// if let progress = DailyGoalCalc.progress(focusMs: totalMs, goalMinutes: profile.dailyFocusGoalMinutes) {
///     progress.ratio          // 0...1 (halka/çubuk için)
///     progress.remainingMs    // hedefe kalan süre; ulaşıldıysa 0
///     progress.isReached
///     DailyGoalCalc.remainingText(progress)   // "1 sa 20 dk kaldı" / "Hedef tamamlandı"
///     DailyGoalCalc.goalText(minutes: goal)   // "3 saat 30 dk"
/// }
/// ```
/// `focusMs` açık segmenti `now`'a kadar sayan `FocusCalc` çıktısıdır; burada `Date()` çağrılmaz.
public enum DailyGoalCalc {
    /// Seçilebilen en küçük hedef (dakika).
    public static let minMinutes = 60
    /// Seçilebilen en büyük hedef (dakika).
    public static let maxMinutes = 600
    /// Seçim adımı (dakika).
    public static let stepMinutes = 30

    /// Ayarlar'da sunulan hedefler: 1 sa … 10 sa, 30 dk adımla (kapalı seçeneği arayüze aittir).
    public static let options: [Int] = Array(stride(from: minMinutes, through: maxMinutes, by: stepMinutes))

    /// Bugünkü hedef durumu.
    public struct Progress: Sendable, Equatable {
        /// Hedef (dakika).
        public var goalMinutes: Int
        /// Bugünkü odak (ms).
        public var focusMs: Double
        /// İlerleme oranı, 0...1 (hedef aşılsa da 1'de kalır).
        public var ratio: Double
        /// Hedefe kalan süre (ms); ulaşıldıysa 0.
        public var remainingMs: Double
        /// Hedefe ulaşıldı mı? (`focusMs >= hedef`)
        public var isReached: Bool

        public init(goalMinutes: Int, focusMs: Double, ratio: Double, remainingMs: Double, isReached: Bool) {
            self.goalMinutes = goalMinutes
            self.focusMs = focusMs
            self.ratio = ratio
            self.remainingMs = remainingMs
            self.isReached = isReached
        }
    }

    /// Geçerli bir hedefe indirger: `nil`/0/negatif → `nil` (kapalı); aralık dışı sıkıştırılır; adıma yuvarlanır.
    public static func normalized(_ minutes: Int?) -> Int? {
        guard let minutes, minutes > 0 else { return nil }
        let clamped = Swift.min(Swift.max(minutes, minMinutes), maxMinutes)
        let steps = (Double(clamped - minMinutes) / Double(stepMinutes)).rounded()
        return minMinutes + Int(steps) * stepMinutes
    }

    /// Hedefin milisaniye karşılığı.
    public static func goalMs(minutes: Int) -> Double { Double(minutes) * 60_000 }

    /// Bugünkü ilerleme. Hedef kapalıysa (`nil`/geçersiz) `nil`. Negatif/NaN odak 0 sayılır.
    public static func progress(focusMs: Double, goalMinutes: Int?) -> Progress? {
        guard let goal = normalized(goalMinutes) else { return nil }
        let goalMs = goalMs(minutes: goal)
        let focus = focusMs.isFinite && focusMs > 0 ? focusMs : 0
        let reached = focus >= goalMs
        return Progress(
            goalMinutes: goal, focusMs: focus,
            ratio: reached ? 1 : focus / goalMs,
            remainingMs: reached ? 0 : goalMs - focus,
            isReached: reached)
    }

    /// Hedefe ulaşıldı mı? Hedef kapalıysa `false`.
    public static func isReached(focusMs: Double, goalMinutes: Int?) -> Bool {
        progress(focusMs: focusMs, goalMinutes: goalMinutes)?.isReached ?? false
    }

    /// "3 saat 30 dk", "1 saat", "45 dk" (bildirim ve ayar satırları için; tr-TR).
    public static func goalText(minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest) dk"
        case (_, 0): return "\(hours) saat"
        default: return "\(hours) saat \(rest) dk"
        }
    }

    /// "1 sa 20 dk kaldı" ya da "Hedef tamamlandı". Dakikaya YUKARI yuvarlar (kalan süre 0 görünmesin).
    public static func remainingText(_ progress: Progress) -> String {
        if progress.isReached { return "Hedef tamamlandı" }
        let totalMinutes = Int((progress.remainingMs / 60_000).rounded(.up))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        switch (hours, minutes) {
        case (0, _): return "\(minutes) dk kaldı"
        case (_, 0): return "\(hours) sa kaldı"
        default: return "\(hours) sa \(minutes) dk kaldı"
        }
    }
}
