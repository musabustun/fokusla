import FokusDomain
import Foundation

// MockSocialService'in sabit sahte dünyası (web `simulatedUsers.ts`): simüle edilen kullanıcılar,
// odaları ve durum geçişleri. Saf veri + saf fonksiyonlar; zamanlayıcı ve depolama yoktur.
// Simüle kullanıcıların canlı durumu SAKLANMAZ: her açılışta `now`'a göre yeniden üretilir.

private let minuteSeconds = 60.0

/// Simüle kullanıcının başlangıç durumu (dakika önce cinsinden).
public struct SimulatedInitialPresence: Sendable, Hashable {
    public let state: PresenceState
    /// Oturum başlangıcı (dakika önce); çevrimdışıysa nil.
    public let sessionStartedMinutesAgo: Double?
    /// Mevcut durumun başlangıcı (dakika önce); çevrimdışıysa nil.
    public let stateSinceMinutesAgo: Double?
    public let todayFocusMinutes: Double
}

public struct SimulatedUser: Sendable, Hashable {
    public let userId: String
    public let username: String
    public let inviteCode: String
    public let initialPresence: SimulatedInitialPresence

    public var user: SocialUser { SocialUser(userId: userId, username: username) }
}

public struct SimulatedRoomMember: Sendable, Hashable {
    public let userId: String
    /// Dünyanın kurulduğu andan kaç dakika önce katıldı.
    public let joinedMinutesAgo: Double
}

public struct SimulatedRoom: Sendable, Hashable {
    public let id: String
    public let name: String
    public let inviteCode: String
    public let hostUserId: String
    public let createdMinutesAgo: Double
    /// Ev sahibi dahil üyeler.
    public let members: [SimulatedRoomMember]
}

/// Her simülasyon adımında (varsayılan 4 sn) durum geçiş olasılıkları. Ortalama odak bloğu
/// ≈ 3 dk, mola ≈ 40 sn: prototipte değişimler görülebilsin ama süreler anlamlı kalsın.
public enum TransitionProbability {
    public static let focusingToBreak = 0.02
    public static let focusingToOffline = 0.002
    public static let breakToFocusing = 0.1
    public static let offlineToFocusing = 0.005
}

public enum SimulatedUsers {
    /// Simüle kullanıcı kimliği: `mock-user-<kullanıcı adı, . ve _ yerine ->`.
    public static func simulatedUserId(_ username: String) -> String {
        "mock-user-" + username.replacingOccurrences(of: ".", with: "-").replacingOccurrences(of: "_", with: "-")
    }

    private static func user(
        _ username: String, _ inviteCode: String, state: PresenceState, session: Double?, since: Double?,
        today: Double
    ) -> SimulatedUser {
        SimulatedUser(
            userId: simulatedUserId(username), username: username, inviteCode: inviteCode,
            initialPresence: SimulatedInitialPresence(
                state: state, sessionStartedMinutesAgo: session, stateSinceMinutesAgo: since,
                todayFocusMinutes: today))
    }

    /// Sıra önemlidir: simülasyon adımı her kullanıcı için bu sırayla bir rastgele sayı tüketir.
    public static let users: [SimulatedUser] = [
        user("elif.say", "ELIF42", state: .focusing, session: 70, since: 25, today: 130),
        user("mert_ayt", "MERT27", state: .onBreak, session: 50, since: 4, today: 65),
        user("zeynep2027", "ZEYNP7", state: .focusing, session: 15, since: 15, today: 40),
        user("deniz_ea", "DENIZ3", state: .focusing, session: 35, since: 12, today: 200),
        user("can.tyt", "CANTYT", state: .onBreak, session: 90, since: 2, today: 100),
        user("ece_dil", "ECEDIL", state: .offline, session: nil, since: nil, today: 55),
    ]

    public static let rooms: [SimulatedRoom] = [
        SimulatedRoom(
            id: "mock-room-sabah", name: "Sabah kampı", inviteCode: "SABAH1",
            hostUserId: simulatedUserId("elif.say"), createdMinutesAgo: 70,
            members: [
                SimulatedRoomMember(userId: simulatedUserId("elif.say"), joinedMinutesAgo: 70),
                SimulatedRoomMember(userId: simulatedUserId("mert_ayt"), joinedMinutesAgo: 50),
            ]),
        SimulatedRoom(
            id: "mock-room-tytmat", name: "TYT Matematik", inviteCode: "TYTMAT",
            hostUserId: simulatedUserId("deniz_ea"), createdMinutesAgo: 35,
            members: [
                SimulatedRoomMember(userId: simulatedUserId("deniz_ea"), joinedMinutesAgo: 35),
                SimulatedRoomMember(userId: simulatedUserId("can.tyt"), joinedMinutesAgo: 30),
            ]),
    ]

    /// Kimsenin alamayacağı kullanıcı adları.
    public static let reservedUsernames: [String] = ["fokus", "admin", "destek", "yardim", "moderator"]
    /// İlk kullanıcı adı alındığında hazır gelen arkadaşlar.
    public static let seedFriendUsernames: [String] = ["elif.say", "mert_ayt"]
    /// İlk kullanıcı adı alındığında bekleyen gelen istekler.
    public static let seedIncomingRequestUsernames: [String] = ["zeynep2027"]

    public static func find(userId: String) -> SimulatedUser? { users.first { $0.userId == userId } }
    public static func find(username: String) -> SimulatedUser? { users.first { $0.username == username } }
    public static func find(inviteCode: String) -> SimulatedUser? { users.first { $0.inviteCode == inviteCode } }

    /// `date`'ten `minutes` dakika önceki an.
    public static func minutesBefore(_ date: Date, _ minutes: Double) -> Date {
        date.addingTimeInterval(-minutes * minuteSeconds)
    }

    /// Simüle kullanıcının `now`'a göre başlangıç durumu.
    public static func initialPresence(_ simulated: SimulatedUser, now: Date) -> SocialPresence {
        let initial = simulated.initialPresence
        return SocialPresence(
            state: initial.state,
            sessionStartedAt: initial.sessionStartedMinutesAgo.map { minutesBefore(now, $0) },
            stateSince: initial.stateSinceMinutesAgo.map { minutesBefore(now, $0) },
            todayFocusMs: initial.todayFocusMinutes * minuteSeconds * 1000, updatedAt: now)
    }

    // MARK: - Simülasyon adımı

    /// Tek bir rastgele sayıyla (0 ≤ r < 1) sonraki durumu seçer.
    /// focusing: r < 0.02 → onBreak, 0.02 ≤ r < 0.022 → offline.
    public static func nextPresenceState(_ state: PresenceState, _ r: Double) -> PresenceState {
        typealias P = TransitionProbability
        switch state {
        case .focusing:
            if r < P.focusingToBreak { return .onBreak }
            return r < P.focusingToBreak + P.focusingToOffline ? .offline : .focusing
        case .onBreak:
            return r < P.breakToFocusing ? .focusing : .onBreak
        case .offline:
            return r < P.offlineToFocusing ? .focusing : .offline
        }
    }

    /// Kalp atışı: çevrimiçi kullanıcının odak süresini `now`'a kadar biriktirir ve `updatedAt`'i
    /// günceller. Çevrimdışı kullanıcı aynen döner.
    public static func heartbeat(_ presence: SocialPresence, now: Date) -> SocialPresence {
        if presence.state == .offline { return presence }
        let elapsedMs = Swift.max(0, ((now.timeIntervalSince(presence.updatedAt)) * 1000).rounded())
        var next = presence
        next.todayFocusMs += presence.state == .focusing ? elapsedMs : 0
        next.updatedAt = now
        return next
    }

    /// Kalp atışı + (r'ye göre) durum geçişi. Girdiyi değiştirmez.
    public static func simulatePresence(_ presence: SocialPresence, _ r: Double, now: Date) -> SocialPresence {
        var next = heartbeat(presence, now: now)
        let state = nextPresenceState(presence.state, r)
        if state == presence.state { return next }
        next.state = state
        next.updatedAt = now
        if state == .offline {
            next.sessionStartedAt = nil
            next.stateSince = nil
        } else {
            next.stateSince = now
            if presence.state == .offline { next.sessionStartedAt = now }
        }
        return next
    }
}
