import FokusDomain
import Foundation
import Testing

@testable import FokusData

// MockSocialService — web `MockSocialService.test.ts` (odalar, kendi durumum, simülasyon).

private struct JoinCase: Sendable, CustomTestStringConvertible {
    let target: RoomTarget
    let code: SocialErrorCode
    var testDescription: String { "joinRoom(\(target)) → \(code)" }
}

private let joinCases: [JoinCase] = [
    JoinCase(target: .room(id: "yok"), code: .roomNotFound),
    JoinCase(target: .inviteCode("XXXXXX"), code: .roomNotFound),
    JoinCase(target: .inviteCode("12"), code: .invalidInviteCode),
]

@MainActor
@Suite("MockSocialService — odalar")
struct MockSocialServiceRoomsTests {
    private func memberNames(_ room: SocialRoom?) -> [String] { room?.members.map(\.username) ?? [] }

    @Test("lists friends' rooms with member and focusing counts")
    func friendRooms() async throws {
        let env = try await makeReadyEnv()

        #expect(
            env.snapshot.friendRooms == [
                RoomSummary(
                    id: "mock-room-sabah", name: "Sabah kampı",
                    host: SocialUser(userId: elifId, username: "elif.say"), memberCount: 2, focusingCount: 1)
            ])

        try await env.service.sendFriendRequest(.username("deniz_ea"))
        #expect(env.snapshot.friendRooms.map(\.id) == ["mock-room-sabah", "mock-room-tytmat"])
    }

    @Test("joins a friend's room by id; host first, me last")
    func joinsById() async throws {
        let env = try await makeReadyEnv()
        env.advanceClock(ms: socialMinute)

        let room = try await env.service.joinRoom(.room(id: "mock-room-sabah"))

        #expect(room.id == "mock-room-sabah")
        #expect(room.name == "Sabah kampı")
        #expect(room.hostUserId == elifId)
        #expect(room.inviteCode == "SABAH1")
        #expect(room.createdAt == socialNow.addingTimeInterval(-70 * 60))
        #expect(room.members.map(\.username) == ["elif.say", "mert_ayt", "ben.yks"])
        #expect(room.members.map(\.isHost) == [true, false, false])
        #expect(room.members.map(\.isSelf) == [false, false, true])
        #expect(room.members[2].joinedAt == socialNow.addingTimeInterval(60))
        #expect(room.members[0].presence?.state == .focusing)
        #expect(env.snapshot.room == room)
        #expect(env.snapshot.friendRooms.isEmpty)
    }

    @Test("joins by invite code, leaving the previous room; re-joining is a no-op")
    func joinsByCode() async throws {
        let env = try await makeReadyEnv()
        try await env.service.joinRoom(.room(id: "mock-room-sabah"))

        let room = try await env.service.joinRoom(.inviteCode("tyt mat"))

        #expect(room.id == "mock-room-tytmat")
        #expect(memberNames(room) == ["deniz_ea", "can.tyt", "ben.yks"])
        #expect(env.snapshot.friendRooms.map(\.id) == ["mock-room-sabah"])
        #expect(try await env.service.joinRoom(.room(id: "mock-room-tytmat")) == room)
        #expect(try await env.service.joinRoom(.inviteCode("TYTMAT")) == room)
    }

    @Test("joinRoom errors", arguments: joinCases)
    fileprivate func joinErrors(_ testCase: JoinCase) async throws {
        let env = try await makeReadyEnv()
        await expectSocialError(testCase.code) { try await env.service.joinRoom(testCase.target) }
    }

    @Test("createRoom validates the name and hosts a new room")
    func createsRoom() async throws {
        let env = try await makeReadyEnv(responseDelayMs: 1000)
        await expectSocialError(.invalidRoomName) { try await env.service.createRoom(name: "   ") }
        await expectSocialError(.invalidRoomName) {
            try await env.service.createRoom(name: String(repeating: "a", count: socialRoomNameMaxLength + 1))
        }

        let room = try await env.service.createRoom(name: "  Gece  çalışması ")

        let profile = try #require(env.snapshot.profile)
        #expect(!room.id.isEmpty)
        #expect(room.name == "Gece  çalışması")
        #expect(room.hostUserId == profile.userId)
        #expect(isGeneratedInviteCode(room.inviteCode))
        #expect(room.createdAt == socialNow)
        #expect(
            room.members == [
                RoomMember(
                    userId: profile.userId, username: "ben.yks", isSelf: true, isHost: true, presence: nil,
                    joinedAt: socialNow)
            ])
        #expect(room.inviteCode != profile.inviteCode)
        #expect(try await env.service.joinRoom(.inviteCode(room.inviteCode)) == room)
    }

    @Test("createRoom accepts a name of exactly the maximum length")
    func createsMaxLengthRoom() async throws {
        let env = try await makeReadyEnv()
        let name = String(repeating: "a", count: socialRoomNameMaxLength)
        #expect(try await env.service.createRoom(name: name).name == name)
    }

    @Test("the first online friend joins my room after responseDelayMs")
    func guestJoinsAfterDelay() async throws {
        let env = try await makeReadyEnv(responseDelayMs: 1500)
        let room = try await env.service.createRoom(name: "Gece")
        #expect(room.members.count == 1)

        env.scheduler.advance(milliseconds: 1500)

        let members = env.snapshot.room?.members ?? []
        #expect(members.map(\.username) == ["ben.yks", "elif.say"])
        #expect(members.map(\.isHost) == [true, false])
    }

    @Test("a reload reschedules the guest join for my still-empty hosted room")
    func reloadReschedules() async throws {
        let env = try await makeReadyEnv(responseDelayMs: 1500)
        try await env.service.createRoom(name: "Gece")
        env.service.dispose()

        let reloaded = makeSocialEnv(storage: env.storage, session: socialSession, responseDelayMs: 1500)
        await reloaded.service.refresh()
        #expect(reloaded.snapshot.room?.members.count == 1)

        reloaded.scheduler.advance(milliseconds: 1500)

        #expect(memberNames(reloaded.snapshot.room) == ["ben.yks", "elif.say"])
    }

    @Test("a friend joins immediately when responseDelayMs is 0")
    func guestJoinsImmediately() async throws {
        let env = try await makeReadyEnv()
        try await env.service.removeFriend(userId: elifId)

        let room = try await env.service.createRoom(name: "Gece")

        #expect(memberNames(room) == ["ben.yks", "mert_ayt"])
    }

    @Test("nobody joins when all friends are offline (stale presence)")
    func nobodyJoinsWhenStale() async throws {
        let env = try await makeReadyEnv()
        env.advanceClock(ms: 11 * socialMinute)

        let room = try await env.service.createRoom(name: "Gece")

        #expect(room.members.count == 1)
    }

    @Test("leaving my hosted room closes it and cancels the pending guest")
    func leavingHostedRoom() async throws {
        let env = try await makeReadyEnv(responseDelayMs: 1500)
        try await env.service.createRoom(name: "Gece")

        await env.service.leaveRoom()
        env.scheduler.advance(milliseconds: 1500)

        #expect(env.snapshot.room == nil)
        #expect(env.scheduler.pendingCount == 0)
    }

    @Test("switching rooms cancels the pending guest of my previous room")
    func switchingRooms() async throws {
        let env = try await makeReadyEnv(responseDelayMs: 1500)
        try await env.service.createRoom(name: "Gece")

        try await env.service.createRoom(name: "Sabah")
        #expect(env.scheduler.pendingCount == 1)
        env.scheduler.advance(milliseconds: 1500)

        let room = env.snapshot.room
        #expect(room?.name == "Sabah")
        #expect(memberNames(room) == ["ben.yks", "elif.say"])
    }

    @Test("leaving a joined room removes me; leaveRoom is a no-op without a room or session")
    func leavingJoinedRoom() async throws {
        let env = try await makeReadyEnv()
        try await env.service.joinRoom(.room(id: "mock-room-sabah"))

        await env.service.leaveRoom()
        #expect(env.snapshot.room == nil)
        #expect(env.snapshot.friendRooms.count == 1)

        let before = env.snapshot
        await env.service.leaveRoom()
        #expect(env.snapshot == before)

        env.signIn(nil)
        await env.service.leaveRoom()
        #expect(env.snapshot.status == .signedOut)
    }

    @Test("persists room membership across reloads")
    func persistsRoom() async throws {
        let env = try await makeReadyEnv()
        try await env.service.joinRoom(.room(id: "mock-room-tytmat"))

        let reloaded = makeSocialEnv(storage: env.storage, session: socialSession)
        await reloaded.service.refresh()

        #expect(reloaded.snapshot.room?.id == "mock-room-tytmat")
    }
}

private enum SessionBoundCall: String, CaseIterable, Sendable {
    case setDiscoverable, publishPresence, sendFriendRequest, respondToRequest, cancelRequest
    case removeFriend, createRoom, joinRoom

    @MainActor
    func perform(on service: MockSocialService) async throws {
        switch self {
        case .setDiscoverable: try await service.setDiscoverable(true)
        case .publishPresence: try await service.publishPresence(socialPresence())
        case .sendFriendRequest: try await service.sendFriendRequest(.username("elif.say"))
        case .respondToRequest: try await service.respondToRequest(id: "x", accept: true)
        case .cancelRequest: try await service.cancelRequest(id: "x")
        case .removeFriend: try await service.removeFriend(userId: "x")
        case .createRoom: try await service.createRoom(name: "Oda")
        case .joinRoom: try await service.joinRoom(.room(id: "mock-room-sabah"))
        }
    }
}

@MainActor
@Suite("MockSocialService — kendi durumum")
struct MockSocialServiceSelfPresenceTests {
    @Test("publishPresence shows up on my room member row and is persisted")
    func publishes() async throws {
        let env = try await makeReadyEnv()
        try await env.service.joinRoom(.room(id: "mock-room-sabah"))
        let mine = socialPresence()

        try await env.service.publishPresence(mine)

        let selfRow = env.snapshot.room?.members.first { $0.isSelf }
        #expect(selfRow?.presence == mine)
        let stored = MockSocialStore.readAccount(storage: env.storage, appleUserId: socialSession)
        #expect(stored?.selfPresence == mine)
    }

    @Test("publishing outside a room stores the presence without a new snapshot")
    func publishesOutsideRoom() async throws {
        let env = try await makeReadyEnv()
        let before = env.snapshot

        try await env.service.publishPresence(socialPresence())
        #expect(env.snapshot == before)

        let room = try await env.service.joinRoom(.room(id: "mock-room-sabah"))
        #expect(room.members.first { $0.isSelf }?.presence == socialPresence())
    }

    @Test("hidden users publish nothing; hiding clears the published presence")
    func hidden() async throws {
        let env = try await makeReadyEnv()
        try await env.service.joinRoom(.room(id: "mock-room-sabah"))
        try await env.service.publishPresence(socialPresence())

        try await env.service.setDiscoverable(false)

        func selfRow() -> RoomMember? { env.snapshot.room?.members.first { $0.isSelf } }
        #expect(env.snapshot.profile?.isDiscoverable == false)
        #expect(selfRow()?.presence == nil)

        try await env.service.publishPresence(socialPresence())
        #expect(selfRow()?.presence == nil)

        try await env.service.setDiscoverable(true)
        try await env.service.publishPresence(socialPresence(state: .onBreak))
        #expect(selfRow()?.presence?.state == .onBreak)
    }

    @Test("requires a session and a profile", arguments: SessionBoundCall.allCases)
    fileprivate func requiresSessionAndProfile(_ call: SessionBoundCall) async {
        let env = makeSocialEnv()
        await expectSocialError(.notSignedIn) { try await call.perform(on: env.service) }
        env.signIn()
        await expectSocialError(.noProfile) { try await call.perform(on: env.service) }
    }
}

@MainActor
@Suite("MockSocialService — simülasyon")
struct MockSocialServiceSimulationTests {
    @Test("runs the simulation only while active and tickMs > 0")
    func runsWhileActive() async throws {
        let env = try await makeReadyEnv(tickMs: 4000)
        #expect(env.scheduler.pendingCount == 0)

        env.service.activate()
        #expect(env.scheduler.pendingCount == 1)
        env.service.deactivate()
        #expect(env.scheduler.pendingCount == 0)

        let noTicks = try await makeReadyEnv(tickMs: 0)
        noTicks.service.activate()
        #expect(noTicks.scheduler.pendingCount == 0)
    }

    @Test("a tick applies transitions and heartbeats, then emits a new snapshot")
    func tickAppliesTransitions() async throws {
        let env = try await makeReadyEnv(tickMs: 4000)
        let incoming = try #require(env.snapshot.requests.first)
        try await env.service.respondToRequest(id: incoming.id, accept: true)
        try await env.service.sendFriendRequest(.username("ece_dil"))
        env.service.activate()
        let before = env.snapshot
        // Sıra: elif, mert, zeynep, deniz, can, ece.
        env.queueRandom(0.01, 0.05, 0.021, 0.9, 0.9, 0.001)
        env.advanceClock(ms: 4000)

        env.scheduler.advance(milliseconds: 4000)

        let tickAt = socialNow.addingTimeInterval(4)
        let byId = Dictionary(uniqueKeysWithValues: env.snapshot.friends.map { ($0.userId, $0.presence) })
        #expect(env.snapshot != before)

        let elif = byId[elifId] ?? nil
        #expect(elif?.state == .onBreak)
        #expect(elif?.stateSince == tickAt)
        #expect(elif?.todayFocusMs == 130 * socialMinute + 4000)
        #expect(elif?.updatedAt == tickAt)

        let mert = byId[mertId] ?? nil
        #expect(mert?.state == .focusing)
        #expect(mert?.stateSince == tickAt)
        #expect(mert?.todayFocusMs == 65 * socialMinute)

        let zeynep = byId[zeynepId] ?? nil
        #expect(zeynep?.state == .offline)
        #expect(zeynep?.sessionStartedAt == nil)
        #expect(zeynep?.stateSince == nil)
        #expect(zeynep?.todayFocusMs == 40 * socialMinute + 4000)

        let ece = byId[eceId] ?? nil
        #expect(ece?.state == .focusing)
        #expect(ece?.sessionStartedAt == tickAt)
        #expect(ece?.stateSince == tickAt)
        #expect(ece?.todayFocusMs == 55 * socialMinute)
        #expect(ece?.updatedAt == tickAt)

        #expect(before.friends.first { $0.userId == elifId }?.presence?.state == .focusing)
    }

    @Test("catches up stale presences when the first subscriber arrives")
    func catchesUp() async throws {
        let env = try await makeReadyEnv(tickMs: 4000)
        env.advanceClock(ms: 20 * socialMinute)

        env.service.activate()

        let elif = env.snapshot.friends.first { $0.userId == elifId }?.presence
        #expect(elif?.state == .focusing)
        #expect(elif?.todayFocusMs == 150 * socialMinute)
        #expect(elif?.updatedAt == socialNow.addingTimeInterval(20 * 60))
    }

    @Test("does not emit ticks while signed out but keeps the world moving")
    func signedOutTicks() async {
        let env = makeSocialEnv(tickMs: 1000)
        await env.service.refresh()
        env.service.activate()

        env.scheduler.advance(milliseconds: 3000)

        #expect(env.snapshot == SocialSnapshot.empty(.signedOut))
    }

    @Test("ticks stop after the last deactivate")
    func ticksStop() async throws {
        let env = try await makeReadyEnv(tickMs: 4000)
        env.service.activate()
        env.service.deactivate()
        let before = env.snapshot
        env.queueRandom(0.01, 0.01, 0.01, 0.01, 0.01, 0.01)
        env.advanceClock(ms: 8000)

        env.scheduler.advance(milliseconds: 8000)

        #expect(env.snapshot == before)
    }
}
