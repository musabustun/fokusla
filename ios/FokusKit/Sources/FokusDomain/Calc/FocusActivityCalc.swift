import Foundation

/// Live Activity / Dynamic Island için odak durumu — SAF. Süre SAKLANMAZ: sistem `Text(timerInterval:)`
/// ile saniyeleri kendisi sayar; burada yalnızca "hangi anda başlamış gibi say" (`timerStart`) hesaplanır.
///
/// - Odakta: oturumun toplam odak süresi (molalar hariç) akar → `timerStart = now − odak süresi`.
///   Odakta olduğu sürece bu değer sabit kalır; mola/devam geçişinde yeniden hesaplanır.
/// - Molada: açık mola segmentinin başlangıcı.
///
/// Mola/devam her seferinde yeni segment açtığı için duraklatılmış sayaç gerekmez; durum değişince
/// etkinlik yeni `State` ile güncellenir (aynı mantık tam ekran odak sayfasındaki saatle birebir).
public enum FocusActivityCalc {
    public enum Phase: String, Sendable, Codable, Equatable {
        case focus
        case `break`
    }

    /// Etkinliğin görünen durumu.
    public struct State: Sendable, Codable, Hashable {
        public var phase: Phase
        /// Sayacın sıfır kabul edildiği an (`Text(timerInterval: timerStart...distantFuture)`).
        public var timerStart: Date

        public init(phase: Phase, timerStart: Date) {
            self.phase = phase
            self.timerStart = timerStart
        }

        /// Aynı görünüm mü? Faz aynı ve sayaç başlangıcı `tolerance` saniye içinde (her hesapta `now`
        /// farklı olduğundan milisaniye sapmaları gereksiz güncelleme üretmesin).
        public func isEquivalent(to other: State, tolerance: TimeInterval = 1.5) -> Bool {
            phase == other.phase && abs(timerStart.timeIntervalSince(other.timerStart)) <= tolerance
        }
    }

    /// Açık oturum varsa etkinlik durumu, yoksa `nil` (etkinlik kapatılmalı).
    public static func state(
        sessions: [FocusSessionSnapshot], segments: [FocusSegmentSnapshot], now: Date
    ) -> State? {
        guard
            let active = sessions.filter({ $0.endedAt == nil && $0.deletedAt == nil })
                .max(by: { $0.startedAt < $1.startedAt })
        else { return nil }
        let own = segments.filter { $0.sessionId == active.id && $0.deletedAt == nil }
        switch FocusCalc.focusPhase(session: active, segments: segments) {
        case .ended:
            return nil
        case .break:
            let start = FocusCalc.findOpenSegment(own)?.startedAt ?? now
            return State(phase: .break, timerStart: start)
        case .focus:
            let focusMs = FocusCalc.computeSessionStats(own, now: now).focusMs
            return State(phase: .focus, timerStart: now.addingTimeInterval(-focusMs / 1000))
        }
    }
}
