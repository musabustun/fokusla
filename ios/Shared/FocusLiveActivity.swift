import ActivityKit
import FokusDomain
import Foundation

/// Odak/mola Live Activity'sinin öznitelikleri (kilit ekranı + Dynamic Island). Uygulama ve widget
/// uzantısı AYNI tanımı kullanır (`ios/Shared`). Süre SAKLANMAZ: `ContentState.timerStart` yalnızca
/// "sayaç ne zaman başlamış gibi" bilgisidir; saniyeleri sistem `Text(timerInterval:)` ile sayar.
struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: FocusActivityCalc.Phase
        var timerStart: Date

        init(_ state: FocusActivityCalc.State) {
            phase = state.phase
            timerStart = state.timerStart
        }

        var state: FocusActivityCalc.State { .init(phase: phase, timerStart: timerStart) }
    }

    /// Etkinliğin ait olduğu odak oturumu.
    var sessionId: UUID
    /// "TYT Matematik" gibi; ders seçilmediyse `nil`.
    var subjectLabel: String?
}

/// Canlı etkinliği veri deposundaki açık oturumla eşitler (başlat / güncelle / bitir). İdempotenttir:
/// uygulama öne gelince, veri kaydedilince ve intent'lerden sonra çağrılır.
///
/// `Activity.request` yalnızca uygulama ön plandayken başarılı olur; arka plandaki intent'te başarısız
/// olursa (`canStart` true olsa bile) sessizce geçilir ve uygulama bir sonraki açılışta başlatır.
enum FocusLiveActivitySync {
    static func sync(canStart: Bool, now: Date = .now) async {
        let snapshot = await MainActor.run { try? FokusSystem.snapshot(now: now) }
        await apply(snapshot, canStart: canStart)
    }

    /// `Activity` Sendable değildir: tüm etkinlik işlemleri tek bir (izole olmayan) fonksiyonda kalır.
    private static func apply(_ snapshot: FokusSystemSnapshot?, canStart: Bool) async {
        let running = Activity<FocusActivityAttributes>.activities
        guard let snapshot, let sessionId = snapshot.activeSessionId, let desired = snapshot.activity else {
            for activity in running { await activity.end(nil, dismissalPolicy: .immediate) }
            return
        }
        // Başka bir oturuma ait kalıntıları kapat.
        for activity in running where activity.attributes.sessionId != sessionId {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        let content = FocusActivityAttributes.ContentState(desired)
        if let current = running.first(where: { $0.attributes.sessionId == sessionId }) {
            if !current.content.state.state.isEquivalent(to: desired) {
                await current.update(ActivityContent(state: content, staleDate: nil))
            }
        } else if canStart, ActivityAuthorizationInfo().areActivitiesEnabled {
            let attributes = FocusActivityAttributes(
                sessionId: sessionId, subjectLabel: snapshot.activeSubjectLabel)
            _ = try? Activity.request(
                attributes: attributes, content: ActivityContent(state: content, staleDate: nil))
        }
    }
}
