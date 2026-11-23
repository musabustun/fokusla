import Foundation

/// Live Activity / Dynamic Island için odak durumu — SAF. Süre SAKLANMAZ: sistem `Text(timerInterval:)`
/// ile saniyeleri kendisi sayar; burada yalnızca "hangi anda başlamış gibi say" bilgileri hesaplanır.
///
/// - Ana sayaç (`timerStart`): odakta SON DEVAMDAN beri (açık odak segmentinin başlangıcı — moladan sonra
///   oturum toplamı değil, "moladan geldiğimden beri ne kadardır çalışıyorum" sorusunun cevabı); molada
///   açık mola segmentinin başlangıcı. Tam ekran odak sayfasındaki saatle aynı değer
///   (`FocusCalc.currentSegmentElapsedMs`).
/// - İkincil sayaç (`sessionFocusStart`): oturumun toplam odak süresi (molalar hariç). Odakta akar
///   (`now − toplam`); molada DONAR: mola başlangıcına göre hesaplanır ve arayüz `pauseTime = timerStart`
///   ile mola başında durdurur.
/// - Günlük hedef (`dayFocusStart` + `goalMinutes`): bugünkü toplam odak için aynı yöntemle; hedef kapalıysa
///   `goalMinutes == nil`.
///
/// Mola/devam her seferinde yeni segment açtığı için duraklatılmış sayaç gerekmez; durum değişince
/// etkinlik yeni `State` ile güncellenir.
public enum FocusActivityCalc {
    public enum Phase: String, Sendable, Codable, Equatable {
        case focus
        case `break`
    }

    /// Etkinliğin görünen durumu. Yeni alanlar opsiyoneldir: eski sürümle başlatılmış etkinliğin kayıtlı
    /// durumu (alanlar olmadan) hâlâ çözülür.
    public struct State: Sendable, Codable, Hashable {
        public var phase: Phase
        /// Ana sayacın sıfır kabul edildiği an (`Text(timerInterval: timerStart...distantFuture)`).
        public var timerStart: Date
        /// Oturum toplam odak sayacının sıfır anı (molada `timerStart`'ta durdurulur).
        public var sessionFocusStart: Date?
        /// Bugünkü toplam odak sayacının sıfır anı (hedef çubuğu için).
        public var dayFocusStart: Date?
        /// Günlük hedef (dakika); kapalıysa `nil`.
        public var goalMinutes: Int?

        public init(
            phase: Phase, timerStart: Date, sessionFocusStart: Date? = nil, dayFocusStart: Date? = nil,
            goalMinutes: Int? = nil
        ) {
            self.phase = phase
            self.timerStart = timerStart
            self.sessionFocusStart = sessionFocusStart
            self.dayFocusStart = dayFocusStart
            self.goalMinutes = goalMinutes
        }

        /// Odak, moladan dönüşten sonra mı? Ana sayaç (son devam) oturum toplamından farklıysa ikincil
        /// "Toplam" satırı anlamlıdır; ilk kesintisiz odakta iki sayaç aynıdır ve gizlenir.
        public var hasResumedAfterBreak: Bool {
            guard phase == .focus, let sessionFocusStart else { return false }
            return abs(sessionFocusStart.timeIntervalSince(timerStart)) > 1
        }

        /// Aynı görünüm mü? Faz/hedef aynı ve zaman çapaları `tolerance` saniye içinde (her hesapta `now`
        /// farklı olduğundan milisaniye sapmaları gereksiz güncelleme üretmesin).
        public func isEquivalent(to other: State, tolerance: TimeInterval = 1.5) -> Bool {
            phase == other.phase && goalMinutes == other.goalMinutes
                && Self.isClose(timerStart, other.timerStart, tolerance)
                && Self.isClose(sessionFocusStart, other.sessionFocusStart, tolerance)
                && Self.isClose(dayFocusStart, other.dayFocusStart, tolerance)
        }

        private static func isClose(_ lhs: Date, _ rhs: Date, _ tolerance: TimeInterval) -> Bool {
            abs(lhs.timeIntervalSince(rhs)) <= tolerance
        }

        private static func isClose(_ lhs: Date?, _ rhs: Date?, _ tolerance: TimeInterval) -> Bool {
            switch (lhs, rhs) {
            case (nil, nil): true
            case let (lhs?, rhs?): isClose(lhs, rhs, tolerance)
            default: false
            }
        }
    }

    /// Açık oturum varsa etkinlik durumu, yoksa `nil` (etkinlik kapatılmalı).
    public static func state(
        sessions: [FocusSessionSnapshot], segments: [FocusSegmentSnapshot], now: Date,
        goalMinutes: Int? = nil, calendar: Calendar = .current
    ) -> State? {
        guard
            let active = sessions.filter({ $0.endedAt == nil && $0.deletedAt == nil })
                .max(by: { $0.startedAt < $1.startedAt })
        else { return nil }
        let own = segments.filter { $0.sessionId == active.id && $0.deletedAt == nil }
        let phase: Phase
        switch FocusCalc.focusPhase(session: active, segments: segments) {
        case .ended: return nil
        case .break: phase = .break
        case .focus: phase = .focus
        }

        // Molada sayaç mola başında, odakta "şimdi"de durur/akar; çapalar buna göre geriye sayılır.
        let openStart = FocusCalc.findOpenSegment(own)?.startedAt
        let timerStart: Date
        let reference: Date
        switch phase {
        case .focus:
            timerStart = Swift.min(openStart ?? now, now)
            reference = now
        case .break:
            timerStart = openStart ?? now
            reference = timerStart
        }
        let sessionMs = FocusCalc.computeSessionStats(own, now: now).focusMs
        let dayMs = try? FocusCalc.dailyFocusTotalMs(
            sessions: sessions, segments: segments, day: Identifiers.isoDate(now, calendar: calendar),
            now: now, calendar: calendar)
        let goal = DailyGoalCalc.normalized(goalMinutes)
        return State(
            phase: phase, timerStart: timerStart,
            sessionFocusStart: reference.addingTimeInterval(-sessionMs / 1000),
            dayFocusStart: goal == nil ? nil : dayMs.map { reference.addingTimeInterval(-$0 / 1000) },
            goalMinutes: goal)
    }
}
