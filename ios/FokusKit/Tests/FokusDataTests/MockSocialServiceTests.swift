import FokusDomain
import Foundation
import Testing

@testable import FokusData

// MockSocialService — web `MockSocialService.test.ts` (durum ve profil, yerel veri, abonelik ve
// değişmezlik, arkadaşlık). Odalar / kendi durumum / simülasyon: MockSocialServiceRoomsTests.swift.

private let corruptStoredData = ["{bozuk", "42", #"{"version":2,"accounts":{}}"#, #"{"version":1}"#]

@MainActor
@Suite("MockSocialService — durum ve profil")
struct MockSocialServiceProfileTests {
    @Test("starts in loading and becomes signedOut without a session")
    func startsLoading() async {
        let env = makeSocialEnv()
        #expect(env.snapshot == SocialSnapshot.empty(.loading))
        #expect(env.snapshot == SocialSnapshot(status: .loading))

        await env.service.refresh()

        #expect(env.snapshot.status == .signedOut)
        #expect(env.snapshot.profile == nil)
    }

    @Test("needs a username when signed in without a stored profile")
    func needsUsername() async {
        let env = makeSocialEnv(session: socialSession)
        await env.service.refresh()
        #expect(env.snapshot.status == .needsUsername)
        #expect(env.snapshot.profile == nil)
    }

    @Test("waits for the fake latency before resolving")
    func waitsForLatency() async {
        let env = makeSocialEnv(delayMs: 60)
        let clock = ContinuousClock()
        let start = clock.now
        await env.service.refresh()
        #expect(start.duration(to: clock.now) >= .milliseconds(55))
        #expect(env.snapshot.status == .signedOut)
    }

    @Test("checkUsername validates format, simulated and reserved names")
    func checkUsername() async {
        let env = makeSocialEnv()
        #expect(await env.service.checkUsername("ab") == .invalid(.tooShort))
        #expect(await env.service.checkUsername("1abc") == .invalid(.mustStartWithLetter))
        #expect(await env.service.checkUsername("Elif.Say") == .taken)
        #expect(await env.service.checkUsername("destek") == .taken)
        #expect(await env.service.checkUsername(" @Ben.YKS ") == .ok("ben.yks"))
    }

    @Test("checkUsername does not report my own username as taken")
    func checkOwnUsername() async throws {
        let env = try await makeReadyEnv()
        #expect(await env.service.checkUsername("ben.yks") == .ok("ben.yks"))
    }

    @Test("claimUsername rejects missing session, invalid and taken names")
    func claimRejects() async {
        let env = makeSocialEnv()
        await expectSocialError(.notSignedIn) { try await env.service.claimUsername("ben.yks") }

        env.signIn()
        await expectSocialError(.invalidUsername) { try await env.service.claimUsername("a!") }
        await expectSocialError(.usernameTaken) { try await env.service.claimUsername("mert_ayt") }
        await expectSocialError(.usernameTaken) { try await env.service.claimUsername("admin") }
        #expect(env.snapshot.status == .needsUsername)
    }

    @Test("first claim creates the profile and seeds friends and an incoming request")
    func firstClaimSeeds() async throws {
        let env = try await makeReadyEnv()
        let snapshot = env.snapshot

        #expect(snapshot.status == .ready)
        let profile = try #require(snapshot.profile)
        #expect(profile.userId.hasPrefix("mock-self-"))
        #expect(profile.username == "ben.yks")
        #expect(isGeneratedInviteCode(profile.inviteCode))
        #expect(profile.isDiscoverable)

        #expect(snapshot.friends.map(\.username) == ["elif.say", "mert_ayt"])
        #expect(
            snapshot.friends.first
                == SocialFriend(
                    userId: elifId, username: "elif.say",
                    presence: SocialPresence(
                        state: .focusing, sessionStartedAt: socialNow.addingTimeInterval(-70 * 60),
                        stateSince: socialNow.addingTimeInterval(-25 * 60), todayFocusMs: 130 * socialMinute,
                        updatedAt: socialNow),
                    friendsSince: socialNow))
        #expect(snapshot.requests.count == 1)
        let request = try #require(snapshot.requests.first)
        #expect(!request.id.isEmpty)
        #expect(request.direction == .incoming)
        #expect(request.user == SocialUser(userId: zeynepId, username: "zeynep2027"))
        #expect(request.createdAt == socialNow)
    }

    @Test("later claims only rename and keep the social graph")
    func laterClaimsRename() async throws {
        let env = try await makeReadyEnv()
        let before = env.snapshot

        let profile = try await env.service.claimUsername("Yeni_Ad")

        var expected = try #require(before.profile)
        expected.username = "yeni_ad"
        #expect(profile == expected)
        #expect(env.snapshot.friends.count == 2)
        #expect(env.snapshot.requests.count == 1)
        #expect(try await env.service.claimUsername("yeni_ad") == profile)
    }

    @Test("invite code never collides with a simulated user's code")
    func inviteCodeAvoidsCollisions() async throws {
        let env = makeSocialEnv(session: socialSession)
        await env.service.refresh()
        // İlk deneme "MERT27" (simüle kullanıcının kodu) üretir; reddedilip yenisi seçilmeli.
        func value(_ index: Int) -> Double { (Double(index) + 0.5) / 32 }
        env.queueRandom(value(11), value(4), value(15), value(17), value(24), value(29))

        let profile = try await env.service.claimUsername("ben.yks")

        #expect(profile.inviteCode != "MERT27")
        #expect(isGeneratedInviteCode(profile.inviteCode))
    }

    @Test("persists the account per Apple user and reloads it")
    func persistsPerUser() async throws {
        let env = try await makeReadyEnv()
        let profile = env.snapshot.profile

        let reloaded = makeSocialEnv(storage: env.storage, session: socialSession)
        await reloaded.service.refresh()
        #expect(reloaded.snapshot.profile == profile)

        reloaded.signIn("mock-apple-2")
        await reloaded.service.refresh()
        #expect(reloaded.snapshot.status == .needsUsername)
    }

    @Test("treats corrupt stored data as empty without throwing", arguments: corruptStoredData)
    func corruptData(_ raw: String) async {
        let env = makeSocialEnv(
            storage: InMemorySocialStorage(data: Data(raw.utf8)), session: socialSession)
        await env.service.refresh()
        #expect(env.snapshot.status == .needsUsername)
    }

    @Test("reloads the account when the session changes between calls")
    func sessionChange() async throws {
        let env = try await makeReadyEnv()

        env.signIn(nil)
        await expectSocialError(.notSignedIn) { try await env.service.setDiscoverable(false) }
        #expect(env.snapshot.status == .signedOut)

        env.signIn("mock-apple-2")
        await expectSocialError(.noProfile) { try await env.service.setDiscoverable(false) }
        #expect(env.snapshot.status == .needsUsername)
    }
}

@MainActor
@Suite("MockSocialService — yerel veri (dışa aktarma / silme)")
struct MockSocialServiceLocalDataTests {
    @Test("exports the stored social data of this device")
    func exportsData() async throws {
        let env = try await makeReadyEnv()

        let exported = MockSocialStore.parseDocument(env.service.exportLocalData())

        #expect(exported.accounts[socialSession]?.profile.username == "ben.yks")
    }

    @Test("exports an empty document when nothing is stored")
    func exportsEmpty() {
        let env = makeSocialEnv()
        #expect(MockSocialStore.parseDocument(env.service.exportLocalData()) == StoredDocument.empty)
    }

    @Test("exports an empty document when stored data is corrupt")
    func exportsEmptyWhenCorrupt() {
        let env = makeSocialEnv(storage: InMemorySocialStorage(data: Data("{bozuk".utf8)))
        #expect(MockSocialStore.parseDocument(env.service.exportLocalData()) == StoredDocument.empty)
    }

    @Test("clears stored social data and drops the in-memory profile")
    func clearsData() async throws {
        let env = try await makeReadyEnv()

        await env.service.clearLocalData()

        #expect(env.storage.load() == nil)
        #expect(env.snapshot.status == .needsUsername)
        #expect(env.snapshot.profile == nil)
        #expect(env.snapshot.friends.isEmpty)
    }

    @Test("startPreviewSession gives a preview account when there is no real session")
    func previewSession() async throws {
        let env = makeSocialEnv()
        await env.service.refresh()
        #expect(env.snapshot.status == .signedOut)

        await env.service.startPreviewSession()
        #expect(env.snapshot.status == .needsUsername)
        try await env.service.claimUsername("onizleme")

        #expect(env.snapshot.status == .ready)
        let document = MockSocialStore.parseDocument(env.service.exportLocalData())
        #expect(document.previewAccountId == MockSocialService.previewAccountId)
        #expect(document.accounts[MockSocialService.previewAccountId]?.profile.username == "onizleme")

        // Yeniden açılışta önizleme oturumu kalıcıdır.
        let reloaded = makeSocialEnv(storage: env.storage)
        await reloaded.service.refresh()
        #expect(reloaded.snapshot.profile?.username == "onizleme")
    }

    @Test("a real session wins over the preview session")
    func realSessionWins() async {
        let env = makeSocialEnv()
        await env.service.startPreviewSession()

        env.signIn()
        await env.service.refresh()

        #expect(env.snapshot.status == .needsUsername)
        #expect(env.snapshot.profile == nil)
    }

    @Test("clearLocalData also clears the preview session")
    func clearsPreview() async throws {
        let env = makeSocialEnv()
        await env.service.startPreviewSession()
        try await env.service.claimUsername("onizleme")

        await env.service.clearLocalData()

        #expect(env.storage.load() == nil)
        #expect(env.snapshot.status == .signedOut)
    }

    @Test("preview-only operations need a session: without preview they throw notSignedIn")
    func noPreviewNoSession() async {
        let env = makeSocialEnv()
        await expectSocialError(.notSignedIn) { try await env.service.claimUsername("onizleme") }
    }
}

@MainActor
@Suite("MockSocialService — abonelik ve değişmezlik")
struct MockSocialServiceSubscriptionTests {
    @Test("snapshots are values: an old copy never changes when something changes")
    func valueSemantics() async throws {
        let env = try await makeReadyEnv()
        let before = env.snapshot
        let friendsBefore = before.friends
        #expect(env.snapshot == before)

        try await env.service.removeFriend(userId: mertId)

        let after = env.snapshot
        #expect(after != before)
        #expect(before.friends == friendsBefore)
        #expect(before.friends.count == 2)
        #expect(after.friends.count == 1)
    }

    @Test("activate/deactivate are reference counted; the ticker runs only while active")
    func referenceCounted() async throws {
        let env = try await makeReadyEnv(tickMs: 4000)
        #expect(env.scheduler.pendingCount == 0)

        env.service.activate()
        env.service.activate()
        #expect(env.scheduler.pendingCount == 1)

        env.service.deactivate()
        #expect(env.scheduler.pendingCount == 1)
        env.service.deactivate()
        #expect(env.scheduler.pendingCount == 0)

        env.service.deactivate()  // Eşleşmeyen çağrı zararsızdır.
        env.service.activate()
        #expect(env.scheduler.pendingCount == 1)
    }

    @Test("tickMs <= 0 never schedules a ticker")
    func noTicker() async throws {
        let env = try await makeReadyEnv(tickMs: 0)
        env.service.activate()
        #expect(env.scheduler.pendingCount == 0)
    }

    @Test("dispose stops the ticker and pending responses")
    func dispose() async throws {
        let env = try await makeReadyEnv(tickMs: 4000, responseDelayMs: 1500)
        env.service.activate()
        try await env.service.sendFriendRequest(.username("ece_dil"))
        #expect(env.scheduler.pendingCount == 2)

        env.service.dispose()

        #expect(env.scheduler.pendingCount == 0)
    }
}

private struct LookupCase: Sendable, CustomTestStringConvertible {
    let lookup: FriendLookup
    let code: SocialErrorCode
    var testDescription: String { "sendFriendRequest(\(lookup)) → \(code)" }
}

private let lookupCases: [LookupCase] = [
    LookupCase(lookup: .username("x"), code: .invalidUsername),
    LookupCase(lookup: .inviteCode("ABC"), code: .invalidInviteCode),
    LookupCase(lookup: .username("kimse_yok"), code: .userNotFound),
    LookupCase(lookup: .inviteCode("ZZZZZZ"), code: .userNotFound),
    LookupCase(lookup: .username("Ben.YKS"), code: .cannotAddSelf),
    LookupCase(lookup: .username("elif.say"), code: .alreadyFriends),
    LookupCase(lookup: .inviteCode("MERT27"), code: .alreadyFriends),
    LookupCase(lookup: .username("zeynep2027"), code: .requestExists),
]

@MainActor
@Suite("MockSocialService — arkadaşlık")
struct MockSocialServiceFriendsTests {
    @Test("sends a request by username that the simulated user accepts after a delay")
    func acceptsAfterDelay() async throws {
        let env = try await makeReadyEnv(responseDelayMs: 1500)

        let request = try await env.service.sendFriendRequest(.username("@Deniz_EA"))

        #expect(
            request
                == FriendRequest(
                    id: request.id, direction: .outgoing,
                    user: SocialUser(userId: denizId, username: "deniz_ea"), createdAt: socialNow))
        #expect(!request.id.isEmpty)
        #expect(env.snapshot.requests.first == request)

        env.scheduler.advance(milliseconds: 1500)

        #expect(!env.snapshot.requests.map(\.id).contains(request.id))
        #expect(env.snapshot.friends.map(\.username) == ["deniz_ea", "elif.say", "mert_ayt"])
    }

    @Test("accepts immediately when responseDelayMs is 0 (lookup by invite code)")
    func acceptsImmediately() async throws {
        let env = try await makeReadyEnv()

        try await env.service.sendFriendRequest(.inviteCode("can-tyt"))

        #expect(env.snapshot.friends.map(\.userId).contains(canId))
        #expect(env.snapshot.requests.allSatisfy { $0.direction == .incoming })
    }

    @Test("sendFriendRequest errors", arguments: lookupCases)
    fileprivate func sendErrors(_ testCase: LookupCase) async throws {
        let env = try await makeReadyEnv()
        await expectSocialError(testCase.code) { try await env.service.sendFriendRequest(testCase.lookup) }
    }

    @Test("rejects my own invite code and a duplicate outgoing request")
    func ownCodeAndDuplicate() async throws {
        let env = try await makeReadyEnv(responseDelayMs: 1000)
        let own = env.snapshot.profile?.inviteCode ?? ""
        await expectSocialError(.cannotAddSelf) { try await env.service.sendFriendRequest(.inviteCode(own)) }

        try await env.service.sendFriendRequest(.username("ece_dil"))
        await expectSocialError(.requestExists) {
            try await env.service.sendFriendRequest(.inviteCode("ECEDIL"))
        }
    }

    @Test("accepts or declines incoming requests")
    func acceptsIncoming() async throws {
        let env = try await makeReadyEnv()
        let incoming = try #require(env.snapshot.requests.first)

        try await env.service.respondToRequest(id: incoming.id, accept: true)

        #expect(env.snapshot.requests.isEmpty)
        let friend = env.snapshot.friends.first { $0.userId == zeynepId }
        #expect(friend?.username == "zeynep2027")
        #expect(friend?.friendsSince == socialNow)
    }

    @Test("declining removes the request without adding a friend")
    func declines() async throws {
        let env = try await makeReadyEnv()
        let incoming = try #require(env.snapshot.requests.first)

        try await env.service.respondToRequest(id: incoming.id, accept: false)

        #expect(env.snapshot.requests.isEmpty)
        #expect(env.snapshot.friends.count == 2)
    }

    @Test("cancelRequest withdraws an outgoing request and its pending acceptance")
    func cancels() async throws {
        let env = try await makeReadyEnv(responseDelayMs: 1500)
        let request = try await env.service.sendFriendRequest(.username("ece_dil"))

        try await env.service.cancelRequest(id: request.id)
        env.scheduler.advance(milliseconds: 5000)

        #expect(!env.snapshot.requests.map(\.id).contains(request.id))
        #expect(!env.snapshot.friends.map(\.userId).contains(eceId))
        #expect(env.scheduler.pendingCount == 0)
    }

    @Test("respond/cancel only accept the matching direction")
    func matchingDirection() async throws {
        let env = try await makeReadyEnv(responseDelayMs: 1000)
        let incoming = env.snapshot.requests.first?.id ?? ""
        let outgoing = try await env.service.sendFriendRequest(.username("ece_dil")).id

        await expectSocialError(.requestNotFound) { try await env.service.respondToRequest(id: "yok", accept: true) }
        await expectSocialError(.requestNotFound) { try await env.service.respondToRequest(id: outgoing, accept: true) }
        await expectSocialError(.requestNotFound) { try await env.service.cancelRequest(id: incoming) }
    }

    @Test("removeFriend removes a friend and rejects unknown ids")
    func removesFriend() async throws {
        let env = try await makeReadyEnv()

        try await env.service.removeFriend(userId: elifId)

        #expect(env.snapshot.friends.map(\.userId) == [mertId])
        await expectSocialError(.friendNotFound) { try await env.service.removeFriend(userId: elifId) }
    }

    @Test("reschedules pending outgoing requests after a reload")
    func reschedulesAfterReload() async throws {
        let first = try await makeReadyEnv(responseDelayMs: 1000)
        try await first.service.sendFriendRequest(.username("ece_dil"))
        first.service.dispose()

        let reloaded = makeSocialEnv(storage: first.storage, session: socialSession)
        await reloaded.service.refresh()

        #expect(reloaded.snapshot.friends.map(\.userId).contains(eceId))
    }
}
