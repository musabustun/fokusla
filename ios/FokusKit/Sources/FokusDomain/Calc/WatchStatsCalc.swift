import Foundation

/// Saat istatistik ekranının saf derlemesi: bugünkü toplam + hedef, son 7 günün çubukları ve son
/// oturumlar. Tüm süreler segment zaman damgalarından (`FocusCalc`) hesaplanır; hiçbir değer saklanmaz.
public enum WatchStatsCalc {
    public static let weekLength = 7
    public static let recentLimit = 5

    public struct RecentSession: Sendable, Equatable, Identifiable {
        public var id: UUID
        public var startedAt: Date
        public var focusMs: Double
        public var subjectId: UUID?
    }

    public struct Summary: Sendable, Equatable {
        public var todayMs: Double
        /// Günlük hedef (dakika); kapalıysa `nil`.
        public var goalMinutes: Int?
        /// Son 7 gün, eskiden yeniye (son eleman bugün).
        public var week: [FocusCalc.DailyFocusTotal]
        /// Son bitmiş oturumlar, en yeni önce.
        public var recent: [RecentSession]

        /// Hedef oranı (0...1); hedef yoksa `nil`.
        public var goalRatio: Double? {
            guard let goalMinutes, goalMinutes > 0 else { return nil }
            return min(1, todayMs / Double(goalMinutes * 60_000))
        }

        /// Haftanın en uzun günü (çubuk ölçeği); hepsi sıfırsa 0.
        public var weekMaxMs: Double { week.map(\.focusMs).max() ?? 0 }

        /// Son 7 günün toplamı.
        public var weekTotalMs: Double { week.map(\.focusMs).reduce(0, +) }
    }

    public static func summary(
        sessions: [FocusSessionSnapshot], segments: [FocusSegmentSnapshot], subjectIds: [UUID: UUID],
        goalMinutes: Int?, now: Date, calendar: Calendar = .current
    ) -> Summary {
        let days = FocusCalc.recentDays(now: now, count: weekLength, calendar: calendar)
        let week =
            (try? FocusCalc.dailyFocusTotals(
                sessions: sessions, segments: segments, days: days, now: now, calendar: calendar)) ?? []
        let recent = FocusCalc.historyEntries(
            sessions: sessions, segments: segments, now: now, limit: recentLimit
        ).map { entry in
            RecentSession(
                id: entry.id, startedAt: entry.startedAt, focusMs: entry.focusMs, subjectId: subjectIds[entry.id])
        }
        return Summary(
            todayMs: week.last?.focusMs ?? 0, goalMinutes: goalMinutes.flatMap { $0 > 0 ? $0 : nil },
            week: week, recent: recent)
    }
}
