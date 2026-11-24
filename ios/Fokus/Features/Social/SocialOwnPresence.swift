import FokusData
import FokusDomain
import Foundation
import SwiftData

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

    /// Depodan yalnız gerekli kayıtları okur: açık oturumlar ve bugüne düşen ya da onlara ait segmentler.
    @MainActor
    static func load(context: ModelContext, now: Date, calendar: Calendar = .current) throws -> SocialPresence {
        let dayStart = calendar.startOfDay(for: now)
        let sessions = try context.fetch(
            FetchDescriptor<FocusSession>(predicate: #Predicate { $0.deletedAt == nil && $0.endedAt == nil }))
        let earliest = min(dayStart, sessions.map(\.startedAt).min() ?? dayStart)
        // Segment gece yarısını geçmiş olabilir: bir gün öncesinden başlayanlar da okunur, hesap kırpar.
        let from = earliest.addingTimeInterval(-24 * 3600)
        let segments = try context.fetch(
            FetchDescriptor<FocusSegment>(predicate: #Predicate { $0.deletedAt == nil && $0.startedAt >= from }))
        return make(sessions: sessions, segments: segments, now: now, calendar: calendar)
    }

    /// Durum geçişi anahtarı (süre değil): değişmediyse yeniden yayın kalp atışına bırakılır.
    static func changeKey(_ presence: SocialPresence) -> String {
        let since = presence.stateSince.map { String($0.timeIntervalSince1970) } ?? "-"
        // Çevrimdışıyken (elle eklenen/silinen oturum) bugünkü toplam da değişim sayılır.
        let today = presence.state == .offline ? String(Int(presence.todayFocusMs)) : "-"
        return "\(presence.state.rawValue)|\(since)|\(today)"
    }
}
