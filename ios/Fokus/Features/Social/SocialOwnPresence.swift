import FokusData
import FokusDomain
import Foundation
import SwiftData
import SwiftUI

/// Kendi paylaşılacak durumumu odak kayıtlarından YALNIZCA OKUYARAK üretir (focus verisine yazmaz,
/// focus feature tiplerine dokunmaz: ortak hesap `SocialCalc.ownPresenceFromFocus`, FokusDomain).
enum SocialOwnPresence {
    static func make(
        sessions: [FocusSession], segments: [FocusSegment], now: Date, calendar: Calendar = .current
    ) -> SocialPresence {
        let active = sessions.filter { $0.endedAt == nil && $0.deletedAt == nil }
            .max { $0.startedAt < $1.startedAt }
        return SocialCalc.ownPresenceFromFocus(
            activeSession: active?.snapshot, segments: segments.map(\.snapshot), now: now, calendar: calendar)
    }

    /// Durum değişince yeniden yayınlamak için kararlı anahtar (süre değil, yalnızca geçişler).
    static func changeKey(sessions: [FocusSession], segments: [FocusSegment]) -> String {
        let presence = make(sessions: sessions, segments: segments, now: .now)
        let stateSince = presence.stateSince.map { String($0.timeIntervalSince1970) } ?? "-"
        return "\(presence.state.rawValue)|\(stateSince)|\(segments.count)"
    }
}

/// Kendi durumumu sosyal servise yayınlar: durum değişince ve ~60 sn'de bir (kalp atışı). Hangi
/// sekmede olursan ol çalışır; odadayken kendi odak oturumun odadakilere yansır. Giriş yoksa, profil
/// hazır değilse ya da "Sosyalde görün" kapalıysa hiçbir şey yayınlamaz.
struct SocialPresencePublisher: ViewModifier {
    static let heartbeat: Duration = .seconds(60)

    @Environment(\.socialService) private var social
    @Query(filter: #Predicate<FocusSession> { $0.deletedAt == nil }) private var sessions: [FocusSession]
    @Query(filter: #Predicate<FocusSegment> { $0.deletedAt == nil }) private var segments: [FocusSegment]

    func body(content: Content) -> some View {
        content.task(id: SocialOwnPresence.changeKey(sessions: sessions, segments: segments)) {
            await publishLoop()
        }
    }

    private func publishLoop() async {
        guard let social else { return }
        // Sosyal ekranı hiç açılmadıysa (ör. uygulama yeniden açıldı) kayıtlı oturumu/odayı yükle.
        if social.snapshot.status == .loading { await social.refresh() }
        while !Task.isCancelled {
            let snapshot = social.snapshot
            if snapshot.status == .ready, snapshot.profile?.isDiscoverable == true {
                let presence = SocialOwnPresence.make(sessions: sessions, segments: segments, now: .now)
                try? await social.publishPresence(presence)
            }
            try? await Task.sleep(for: Self.heartbeat)
        }
    }
}

extension View {
    /// Kendi odak durumumu (odadaysam) sosyal servise yayınlar. Kabuk kökünde bir kez uygulanır.
    func publishesSocialPresence() -> some View { modifier(SocialPresencePublisher()) }
}
