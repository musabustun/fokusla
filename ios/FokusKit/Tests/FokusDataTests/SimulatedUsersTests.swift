import FokusDomain
import Foundation
import Testing

@testable import FokusData

// Simüle dünya — web `simulatedUsers.test.ts` vakalarıyla birebir.

private let now = Date(timeIntervalSince1970: 1_795_071_600)  // 2026-11-19T07:00:00Z
private let later = now.addingTimeInterval(60)

private func presence(
    state: PresenceState = .focusing,
    sessionStartedAt: Date? = now.addingTimeInterval(-3600),
    stateSince: Date? = now.addingTimeInterval(-1800),
    todayFocusMs: Double = 1000,
    updatedAt: Date = now
) -> SocialPresence {
    SocialPresence(
        state: state, sessionStartedAt: sessionStartedAt, stateSince: stateSince,
        todayFocusMs: todayFocusMs, updatedAt: updatedAt)
}

private struct TransitionCase: Sendable, CustomTestStringConvertible {
    let state: PresenceState
    let r: Double
    let expected: PresenceState
    var testDescription: String { "nextPresenceState(\(state), \(r)) → \(expected)" }
}

private let transitionCases: [TransitionCase] = [
    TransitionCase(state: .focusing, r: 0, expected: .onBreak),
    TransitionCase(state: .focusing, r: 0.019, expected: .onBreak),
    TransitionCase(state: .focusing, r: 0.02, expected: .offline),
    TransitionCase(state: .focusing, r: 0.0219, expected: .offline),
    TransitionCase(state: .focusing, r: 0.022, expected: .focusing),
    TransitionCase(state: .onBreak, r: 0.099, expected: .focusing),
    TransitionCase(state: .onBreak, r: 0.1, expected: .onBreak),
    TransitionCase(state: .offline, r: 0.0049, expected: .focusing),
    TransitionCase(state: .offline, r: 0.005, expected: .offline),
]

@Suite("simulatedUsers")
struct SimulatedUsersTests {
    @Test("derives stable user ids from usernames")
    func stableIds() {
        #expect(SimulatedUsers.simulatedUserId("elif.say") == "mock-user-elif-say")
        #expect(SimulatedUsers.simulatedUserId("mert_ayt") == "mock-user-mert-ayt")
        #expect(SimulatedUsers.users.map(\.userId).contains("mock-user-can-tyt"))
    }

    @Test("has unique usernames, invite codes and rooms hosted by simulated users")
    func uniqueWorld() {
        let codes = SimulatedUsers.users.map(\.inviteCode) + SimulatedUsers.rooms.map(\.inviteCode)
        #expect(Set(codes).count == codes.count)
        let usernames = SimulatedUsers.users.map(\.username)
        #expect(Set(usernames).count == usernames.count)
        let ids = Set(SimulatedUsers.users.map(\.userId))
        for room in SimulatedUsers.rooms {
            #expect(ids.contains(room.hostUserId))
            #expect(room.members.allSatisfy { ids.contains($0.userId) })
        }
    }

    @Test("sabit dünya: 6 kullanıcı, 2 oda, ayrılmış adlar")
    func fixedWorld() {
        #expect(SimulatedUsers.users.map(\.username) == ["elif.say", "mert_ayt", "zeynep2027", "deniz_ea", "can.tyt", "ece_dil"])
        #expect(SimulatedUsers.rooms.map(\.id) == ["mock-room-sabah", "mock-room-tytmat"])
        #expect(SimulatedUsers.reservedUsernames == ["fokus", "admin", "destek", "yardim", "moderator"])
        #expect(SimulatedUsers.seedFriendUsernames == ["elif.say", "mert_ayt"])
        #expect(SimulatedUsers.seedIncomingRequestUsernames == ["zeynep2027"])
    }

    @Test("nextPresenceState", arguments: transitionCases)
    fileprivate func nextState(_ testCase: TransitionCase) {
        #expect(SimulatedUsers.nextPresenceState(testCase.state, testCase.r) == testCase.expected)
    }

    @Test("heartbeat accrues focus time only while focusing")
    func heartbeatAccrual() {
        #expect(
            SimulatedUsers.heartbeat(presence(), now: later)
                == presence(todayFocusMs: 61_000, updatedAt: later))
        #expect(
            SimulatedUsers.heartbeat(presence(state: .onBreak), now: later)
                == presence(state: .onBreak, updatedAt: later))
        let offline = presence(state: .offline)
        #expect(SimulatedUsers.heartbeat(offline, now: later) == offline)
    }

    @Test("heartbeat ignores negative clock drift")
    func heartbeatDrift() {
        let earlier = now.addingTimeInterval(-5)
        #expect(SimulatedUsers.heartbeat(presence(), now: earlier).todayFocusMs == 1000)
    }

    @Test("simulatePresence keeps the session when switching between focus and break")
    func keepsSession() {
        let input = presence()
        let next = SimulatedUsers.simulatePresence(input, 0.01, now: later)
        #expect(
            next
                == SocialPresence(
                    state: .onBreak, sessionStartedAt: input.sessionStartedAt, stateSince: later,
                    todayFocusMs: 61_000, updatedAt: later))
        #expect(input.state == .focusing)
    }

    @Test("simulatePresence starts a new session when coming online")
    func newSession() {
        let offline = presence(state: .offline, sessionStartedAt: nil, stateSince: nil)
        let online = SimulatedUsers.simulatePresence(offline, 0, now: later)
        #expect(online.state == .focusing)
        #expect(online.sessionStartedAt == later)
        #expect(online.stateSince == later)
        #expect(online.todayFocusMs == 1000)
        #expect(SimulatedUsers.simulatePresence(offline, 0.9, now: later) == offline)
    }

    @Test("simulatePresence: odaktan çevrimdışına geçiş oturumu ve durum başlangıcını siler")
    func goingOffline() {
        let next = SimulatedUsers.simulatePresence(presence(), 0.021, now: later)
        #expect(next.state == .offline)
        #expect(next.sessionStartedAt == nil)
        #expect(next.stateSince == nil)
        #expect(next.todayFocusMs == 61_000)
        #expect(next.updatedAt == later)
    }

    @Test("initialPresence: dakika önce değerlerini now'a göre üretir")
    func initialPresence() {
        let elif = SimulatedUsers.initialPresence(SimulatedUsers.users[0], now: now)
        #expect(elif.state == .focusing)
        #expect(elif.sessionStartedAt == now.addingTimeInterval(-70 * 60))
        #expect(elif.stateSince == now.addingTimeInterval(-25 * 60))
        #expect(elif.todayFocusMs == 130 * 60_000)
        let ece = SimulatedUsers.initialPresence(SimulatedUsers.users[5], now: now)
        #expect(ece.state == .offline)
        #expect(ece.sessionStartedAt == nil)
        #expect(ece.stateSince == nil)
    }
}
