import FokusDomain
import Foundation
import Testing

@testable import FokusData

// MockSocialService testleri için ortak yardımcılar: sabit saat, tohumlu rastgele, sahte oturum.

/// 2026-11-19T07:00:00Z
let socialNow = Date(timeIntervalSince1970: 1_795_071_600)
let socialMinute: Double = 60 * 1000
let socialSession = "mock-apple-1"
let elifId = SimulatedUsers.simulatedUserId("elif.say")
let mertId = SimulatedUsers.simulatedUserId("mert_ayt")
let zeynepId = SimulatedUsers.simulatedUserId("zeynep2027")
let denizId = SimulatedUsers.simulatedUserId("deniz_ea")
let canId = SimulatedUsers.simulatedUserId("can.tyt")
let eceId = SimulatedUsers.simulatedUserId("ece_dil")
private let inviteCodeAlphabet = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

/// Üretilen davet kodu: 6 karakter, sadece karışmayan alfabeden.
func isGeneratedInviteCode(_ code: String) -> Bool {
    code.count == 6 && code.allSatisfy { inviteCodeAlphabet.contains($0) }
}

/// Deterministik sözde rastgele üreteç (mulberry32 — web testleriyle aynı).
struct SeededRandom {
    private var state: UInt32

    init(seed: UInt32) { state = seed }

    mutating func next() -> Double {
        state = state &+ 0x6D2B_79F5
        var t = (state ^ (state >> 15)) &* (1 | state)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4_294_967_296
    }
}

/// Servisin saat/rastgele/oturum bağımlılıklarını tutan test nesnesi.
@MainActor
final class SocialProbe {
    var session: String?
    var clock = socialNow
    private var queued: [Double] = []
    private var fallback = SeededRandom(seed: 42)

    init(session: String?) { self.session = session }

    func nextRandom() -> Double {
        queued.isEmpty ? fallback.next() : queued.removeFirst()
    }

    func queueRandom(_ values: Double...) { queued.append(contentsOf: values) }
    func advanceClock(ms: Double) { clock = clock.addingTimeInterval(ms / 1000) }
}

@MainActor
struct SocialEnv {
    let service: MockSocialService
    let probe: SocialProbe
    let storage: InMemorySocialStorage
    let scheduler: ManualSocialScheduler

    var snapshot: SocialSnapshot { service.snapshot }

    func signIn(_ id: String? = socialSession) { probe.session = id }
    func advanceClock(ms: Double) { probe.advanceClock(ms: ms) }
    func queueRandom(_ values: Double...) { for value in values { probe.queueRandom(value) } }

    /// Oturum açık, profil `ben.yks`.
    func claimBenYks() async throws {
        await service.refresh()
        try await service.claimUsername("ben.yks")
    }
}

@MainActor
func makeSocialEnv(
    storage: InMemorySocialStorage = InMemorySocialStorage(), session: String? = nil, delayMs: Int = 0,
    tickMs: Int = 0, responseDelayMs: Int = 0
) -> SocialEnv {
    let probe = SocialProbe(session: session)
    let scheduler = ManualSocialScheduler()
    let service = MockSocialService(
        sessionProvider: { probe.session }, storage: storage, scheduler: scheduler,
        now: { probe.clock }, random: { probe.nextRandom() }, delayMs: delayMs, tickMs: tickMs,
        responseDelayMs: responseDelayMs)
    return SocialEnv(service: service, probe: probe, storage: storage, scheduler: scheduler)
}

/// Oturum açık, `ben.yks` profili alınmış hazır ortam.
@MainActor
func makeReadyEnv(
    storage: InMemorySocialStorage = InMemorySocialStorage(), tickMs: Int = 0, responseDelayMs: Int = 0
) async throws -> SocialEnv {
    let env = makeSocialEnv(
        storage: storage, session: socialSession, tickMs: tickMs, responseDelayMs: responseDelayMs)
    try await env.claimBenYks()
    return env
}

/// `operation`'ın `SocialError(code)` fırlatmasını bekler.
@MainActor
func expectSocialError<T>(
    _ code: SocialErrorCode, sourceLocation: SourceLocation = #_sourceLocation,
    _ operation: () async throws -> T
) async {
    do {
        _ = try await operation()
        Issue.record("\(code) hatası bekleniyordu", sourceLocation: sourceLocation)
    } catch let error as SocialError {
        #expect(error.code == code, sourceLocation: sourceLocation)
    } catch {
        Issue.record("Beklenmeyen hata: \(error)", sourceLocation: sourceLocation)
    }
}

func socialPresence(
    state: PresenceState = .focusing, updatedAt: Date = socialNow, todayFocusMs: Double = 30 * socialMinute
) -> SocialPresence {
    SocialPresence(
        state: state, sessionStartedAt: socialNow, stateSince: socialNow, todayFocusMs: todayFocusMs,
        updatedAt: updatedAt)
}
