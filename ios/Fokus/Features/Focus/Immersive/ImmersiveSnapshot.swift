import FokusDomain
import Foundation

/// Tam ekran görünümün bir andaki tüm sayıları. Saf değer: `FocusCalc` fonksiyonlarından türetilir,
/// `now` dışarıdan gelir (test edilebilir; görünümler yalnızca okur).
struct ImmersiveSnapshot: Equatable {
    var phase: FocusTimerPhase
    /// Açık oturumun toplam odak süresi (ms).
    var sessionFocusMs: Double
    /// Açık odak segmentinin süresi (ms) = son devamdan (moladan dönüşten) beri; odakta değilse 0.
    var currentFocusMs: Double
    /// Açık molanın süresi (ms); molada değilse 0.
    var breakMs: Double
    /// Bugünün toplam odak süresi (ms).
    var todayTotalMs: Double
    /// Bugün başlayan (silinmemiş) oturum sayısı.
    var todaySessionCount: Int
    /// Ortalama kesintisiz odak ve ortalama mola (ms); Odak ekranındaki istatistiklerle aynı hesap.
    var averageFocusMs: Double
    var averageBreakMs: Double
    var isLongBreak: Bool

    static let empty = ImmersiveSnapshot(
        phase: .idle, sessionFocusMs: 0, currentFocusMs: 0, breakMs: 0, todayTotalMs: 0, todaySessionCount: 0,
        averageFocusMs: 0, averageBreakMs: 0, isLongBreak: false)

    /// Büyük saatte gösterilen süre: molada mola süresi, odakta son devamdan beri geçen süre.
    var shownMs: Double {
        switch phase {
        case .break: breakMs
        case .focus: currentFocusMs
        case .idle: 0
        }
    }

    /// Halka dolumu: gösterilen sürenin saat içindeki payı (0–1).
    var hourLap: Double { Self.hourLap(shownMs) }

    /// Saatlik tur: geçen sürenin saat içindeki payı (0–1). `FocusTimerPanel` de bunu kullanır.
    static func hourLap(_ ms: Double) -> Double {
        guard ms.isFinite, ms > 0 else { return 0 }
        let hourMs = 3_600_000.0
        return ms.truncatingRemainder(dividingBy: hourMs) / hourMs
    }

    static func make(
        sessions: [FocusSessionSnapshot], segments: [FocusSegmentSnapshot],
        now: Date, calendar: Calendar = .current
    ) -> ImmersiveSnapshot {
        let active = sessions.filter { $0.endedAt == nil && $0.deletedAt == nil }
            .max { $0.startedAt < $1.startedAt }
        var phase = FocusTimerPhase.idle
        var activeSegments: [FocusSegmentSnapshot] = []
        if let active {
            switch FocusCalc.focusPhase(session: active, segments: segments) {
            case .focus: phase = .focus
            case .break: phase = .break
            case .ended: phase = .idle
            }
            activeSegments = segments.filter { $0.sessionId == active.id }
        }
        let overall = FocusCalc.computeSessionStats(segments, now: now)
        let today = Identifiers.isoDate(now, calendar: calendar)
        let todayTotal = (try? FocusCalc.dailyFocusTotalMs(
            sessions: sessions, segments: segments, day: today, now: now, calendar: calendar)) ?? 0
        let todayCount = sessions.filter {
            $0.deletedAt == nil && calendar.isDate($0.startedAt, inSameDayAs: now)
        }.count
        return ImmersiveSnapshot(
            phase: phase,
            sessionFocusMs: FocusCalc.computeSessionStats(activeSegments, now: now).focusMs,
            currentFocusMs: FocusCalc.openSegmentDurationMs(activeSegments, kind: .focus, now: now),
            breakMs: FocusCalc.openSegmentDurationMs(activeSegments, kind: .break, now: now),
            todayTotalMs: todayTotal,
            todaySessionCount: todayCount,
            averageFocusMs: overall.averageFocusMs,
            averageBreakMs: overall.averageBreakMs,
            isLongBreak: phase == .break && FocusCalc.isLongBreak(activeSegments, now: now))
    }
}
