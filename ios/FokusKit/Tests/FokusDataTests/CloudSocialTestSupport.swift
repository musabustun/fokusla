import FokusDomain
import Foundation
import Testing

@testable import FokusData

/// İstanbul öğleni: testler gün dönümünden etkilenmesin.
final class SocialTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_795_510_800)

    var now: Date { lock.withLock { value } }
    func advance(_ seconds: TimeInterval) { lock.withLock { value += seconds } }
}

/// Aynı sahte sunucuya bağlı birden çok gerçek servis: iki tarafı da gerçek kurallarla çalıştırır.
@MainActor
final class SocialTestWorld {
    let clock = SocialTestClock()
    let server: InMemorySocialServer
    let calendar: Calendar

    init() {
        let clock = self.clock
        server = InMemorySocialServer(now: { clock.now })
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        self.calendar = calendar
    }

    func service(_ account: String, signedIn: Bool = true, scheduler: any SocialScheduler = ManualSocialScheduler())
        -> CloudSocialService {
        let clock = self.clock
        return CloudSocialService(
            sessionProvider: { signedIn ? "apple-\(account)" : nil },
            cloud: InMemorySocialCloud(userId: account, server: server), scheduler: scheduler,
            now: { clock.now }, calendar: calendar)
    }

    /// Kullanıcı adı alınmış, hazır servis. Hesap adı = kullanıcı adı.
    func user(_ username: String) async throws -> CloudSocialService {
        let service = service(username)
        await service.refresh()
        try await service.claimUsername(username)
        return service
    }

    func befriend(_ a: CloudSocialService, _ b: CloudSocialService) async throws {
        let invite = try await a.createFriendInvite()
        try await b.acceptInvite(SocialInvite(url: invite.url))
        await a.refresh()
    }

    func presence(_ state: PresenceState, today: Double = 0) -> SocialPresence {
        let now = clock.now
        return SocialPresence(
            state: state, sessionStartedAt: state == .offline ? nil : now, stateSince: state == .offline ? nil : now,
            todayFocusMs: today, updatedAt: now)
    }
}

/// `#expect(throws:)` ile `SocialError` kodu denetimi.
@MainActor
func expectSocialError(
    _ code: SocialErrorCode, sourceLocation: SourceLocation = #_sourceLocation, _ body: @MainActor () async throws -> Void
) async {
    await #expect(throws: SocialError(code), sourceLocation: sourceLocation) { try await body() }
}
