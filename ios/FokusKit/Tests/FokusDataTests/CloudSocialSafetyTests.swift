import FokusDomain
import Foundation
import Testing

@testable import FokusData

@MainActor
@Suite("CloudSocialService — sahtecilik, gizlilik ve silme")
struct CloudSocialSafetyTests {
    let world = SocialTestWorld()

    private func cloud(_ user: String) -> InMemorySocialCloud { InMemorySocialCloud(userId: user, server: world.server) }

    private func forgedCard(personId: String = "kotu-kisi", username: String) -> SocialCard {
        SocialCard(personId: personId, username: username, presence: world.presence(.focusing), joinedAt: world.clock.now)
    }

    private func forgedInvite(from attacker: String, username: String) async throws -> SocialSpace {
        try await cloud(attacker).createSpace(
            name: "friend-sahte", info: SocialSpaceInfo(kind: .friend, createdAt: world.clock.now),
            card: forgedCard(username: username))
    }

    @Test("başkasının adıyla yazılmış kartlı davet kabul edilmez")
    func impersonationByLink() async throws {
        _ = try await world.user("ayse")
        let elif = try await world.user("elif")
        let space = try await forgedInvite(from: "kotu", username: "ayse")
        await expectSocialError(.inviteInvalid) { try await elif.acceptInvite(SocialInvite(url: #require(space.inviteURL))) }
        #expect(elif.snapshot.friends.isEmpty)
    }

    @Test("sonradan başkasının adına geçen kişi listede görünmez, arkadaşlık bozulmaz")
    func impersonationAfterAccept() async throws {
        _ = try await world.user("ayse")
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await world.befriend(elif, mert)
        let space = try #require(try await cloud("mert").spaces().first)
        let card = try #require(space.cards.first { $0.username == "mert" })
        var forged = card
        forged.username = "ayse"
        try await cloud("mert").saveCards([space.id: forged])
        await elif.refresh()
        #expect(elif.snapshot.friends.isEmpty)
        try await cloud("mert").saveCards([space.id: card])
        await elif.refresh()
        #expect(elif.snapshot.friends.map(\.username) == ["mert"])
    }

    @Test("istek gönderen, daveti başkası açmışsa kabul edilmez")
    func mailWithForeignInvite() async throws {
        let mert = try await world.user("mert")
        let elif = try await world.user("elif")
        let zeynep = try await world.user("zeynep")
        let foreign = try await zeynep.createFriendInvite()
        let claim = try #require(try await cloud("mert").claim(forKey: SocialDirectory.claimKey(forUsername: "elif")))
        let payload = SocialMailPayload(v: 1, username: "mert", url: foreign.url)
        try await cloud("mert").sendMail(
            id: "m", mailbox: claim.mailbox,
            sealed: SocialMailCrypto.seal(JSONEncoder().encode(payload), publicKey: claim.publicKey, mailbox: claim.mailbox))
        _ = mert
        await elif.refresh()
        let request = try #require(elif.snapshot.requests.first)
        await expectSocialError(.requestNotFound) { try await elif.respondToRequest(id: request.id, accept: true) }
        #expect(elif.snapshot.friends.isEmpty)
    }

    @Test("oda üyesi başkasının kartını ezerse o kişi odadan atılmaz")
    func tamperedRoomCard() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        let room = try await elif.createRoom(name: "Oda")
        try await mert.acceptInvite(SocialInvite(url: #require(room.inviteURL)))
        let space = try #require(try await cloud("mert").spaces().first)
        var victim = try #require(space.cards.first { $0.username == "elif" })
        victim.leftAt = world.clock.now
        try await cloud("mert").saveCards([space.id: victim])

        await mert.refresh()
        #expect(mert.snapshot.room?.members.map(\.username) == ["mert"])
        // Sahibi kartını bir sonraki yenilemede geri yazar.
        await elif.refresh()
        #expect(elif.snapshot.room?.members.map(\.username) == ["elif", "mert"])
        await mert.refresh()
        #expect(mert.snapshot.room?.members.map(\.username) == ["elif", "mert"])
    }

    @Test("odada başkasının adını kullanan üye gösterilmez")
    func impersonationInRoom() async throws {
        _ = try await world.user("ayse")
        let elif = try await world.user("elif")
        let room = try await elif.createRoom(name: "Oda")
        let space = try await cloud("kotu").acceptInvite(SocialInvite(url: #require(room.inviteURL)))
        try await cloud("kotu").saveCards([space.id: forgedCard(username: "ayse")])
        await elif.refresh()
        #expect(elif.snapshot.room?.members.map(\.username) == ["elif"])
    }

    @Test("engelleme yalnız gerçek göndereni etkiler")
    func blockIsPrecise() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        let zeynep = try await world.user("zeynep")
        try await world.befriend(elif, zeynep)
        try await mert.sendFriendRequest(.username("elif"))
        await elif.refresh()
        try await elif.blockRequest(id: #require(elif.snapshot.requests.first).id)
        await elif.refresh()
        #expect(elif.snapshot.friends.map(\.username) == ["zeynep"])
    }

    @Test("kişi başına yalnız en yeni istek sayılır")
    func mailFlood() async throws {
        let mert = try await world.user("mert")
        let elif = try await world.user("elif")
        let claim = try #require(try await cloud("mert").claim(forKey: SocialDirectory.claimKey(forUsername: "elif")))
        for index in 0..<30 {
            let payload = SocialMailPayload(v: 1, username: "mert", url: URL(string: "https://www.icloud.com/share/\(index)")!)
            world.clock.advance(1)
            try await cloud("mert").sendMail(
                id: "m\(index)", mailbox: claim.mailbox,
                sealed: SocialMailCrypto.seal(JSONEncoder().encode(payload), publicKey: claim.publicKey, mailbox: claim.mailbox))
        }
        _ = mert
        await elif.refresh()
        #expect(elif.snapshot.requests.map(\.id) == ["m29"])
    }

    @Test("gizlenme ağ hatasında yarım kalırsa sonraki yenileme ya da yayın tamamlar", arguments: [true, false])
    func hideRetries(byRefresh: Bool) async throws {
        let failing = FlakyCardCloud(base: cloud("elif"))
        let clock = world.clock
        let elif = CloudSocialService(
            sessionProvider: { "apple" }, cloud: failing, scheduler: ManualSocialScheduler(), now: { clock.now },
            calendar: world.calendar)
        await elif.refresh()
        try await elif.claimUsername("elif")
        let mert = try await world.user("mert")
        try await world.befriend(elif, mert)
        try await elif.publishPresence(world.presence(.focusing))
        await failing.gate.set(true)
        await expectSocialError(.network) { try await elif.setDiscoverable(false) }
        await mert.refresh()
        #expect(mert.snapshot.friends.first?.presence != nil)

        await failing.gate.set(false)
        if byRefresh { await elif.refresh() } else { try await elif.publishPresence(world.presence(.focusing)) }
        await mert.refresh()
        #expect(mert.snapshot.friends.first?.presence == nil)
    }

    @Test("Apple çıkışı yapılmışken de sosyal profil silinir")
    func deleteWhileSignedOut() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await world.befriend(elif, mert)
        let signedOut = world.service("elif", signedIn: false)
        await signedOut.refresh()
        try await signedOut.deleteAccount()
        #expect(signedOut.snapshot.status == .signedOut)
        #expect(await world.server.claimCount == 1)
        #expect(await world.server.spaceCount == 0)
    }

    @Test("hiç profil yoksa silme sessizce tamamlanır; iCloud yoksa hata verir")
    func deleteWithoutProfile() async throws {
        let service = world.service("bos")
        try await service.deleteAccount()
        #expect(service.snapshot.status == .needsUsername)
        await world.server.setAccountless(true, user: "bos")
        await expectSocialError(.iCloudUnavailable) { try await service.deleteAccount() }
    }

    @Test("profil izi bu cihazda hatırlanır ve silinince kalkar")
    func profileFlag() async throws {
        let suite = "social-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        func make() -> CloudSocialService {
            CloudSocialService(
                sessionProvider: { "apple" }, cloud: cloud("elif"), scheduler: ManualSocialScheduler(), defaults: defaults)
        }
        let service = make()
        await service.refresh()
        #expect(!service.mayHaveProfile)
        try await service.claimUsername("elif")
        #expect(make().mayHaveProfile)
        try await service.deleteAccount()
        #expect(!make().mayHaveProfile)
    }

    @Test("iCloud hesabı değişince önceki hesabın arkadaşları görünmez")
    func accountSwitch() async throws {
        let switching = SwitchingCloud(server: world.server)
        let clock = world.clock
        let service = CloudSocialService(
            sessionProvider: { "apple" }, cloud: switching, scheduler: ManualSocialScheduler(), now: { clock.now })
        await switching.current.set("a")
        await service.refresh()
        try await service.claimUsername("hesap.a")
        let mert = try await world.user("mert")
        try await world.befriend(service, mert)
        #expect(service.snapshot.friends.count == 1)

        await switching.current.set("b")
        try await service.publishPresence(world.presence(.focusing))
        #expect(service.snapshot.status == .needsUsername)
        #expect(service.snapshot.friends.isEmpty)
    }

    @Test("alınamayan ad kimlikte iz bırakmaz; önceki ad geçerli kalır")
    func failedRename() async throws {
        _ = try await world.user("ayse")
        let elif = try await world.user("elif")
        await expectSocialError(.usernameTaken) { try await elif.claimUsername("ayse") }
        let identity = try #require(try await cloud("elif").loadIdentity())
        #expect(identity.username == "elif")
        #expect(identity.reservedUsernames.isEmpty)
    }

    @Test("yarım kalan ad alma, yenilemede bırakılır")
    func abandonedClaim() async throws {
        let elif = try await world.user("elif")
        var identity = try #require(try await cloud("elif").loadIdentity())
        identity.reservedUsernames = ["yarim", "elif"]
        try await cloud("elif").saveIdentity(identity)
        try await cloud("elif").createClaim(SocialClaim(
            key: SocialDirectory.claimKey(forUsername: "yarim"), ownerId: "", publicKey: Data(), mailbox: "m", acceptsRequests: true))
        #expect(await world.server.claimCount == 2)
        await elif.refresh()
        #expect(await world.server.claimCount == 1)
        #expect(elif.snapshot.profile?.username == "elif")
    }
}

/// Açılınca kart yazmaları başarısız olan bulut.
actor Gate {
    private(set) var isClosed = false
    func set(_ value: Bool) { isClosed = value }
}

private struct FlakyCardCloud: ForwardingSocialCloud {
    let base: InMemorySocialCloud
    let gate = Gate()

    func target() async -> InMemorySocialCloud { base }
    func saveCards(_ cards: [SocialSpaceID: SocialCard]) async throws {
        if await gate.isClosed { throw SocialCloudError.network }
        try await base.saveCards(cards)
    }
}

actor CurrentAccount {
    private(set) var value = ""
    func set(_ next: String) { value = next }
}

/// Etkin iCloud hesabı değişebilen bulut.
private struct SwitchingCloud: ForwardingSocialCloud {
    let server: InMemorySocialServer
    let current = CurrentAccount()

    func target() async -> InMemorySocialCloud { InMemorySocialCloud(userId: await current.value, server: server) }
}

/// Her çağrıyı `target()`'a iletir; testler yalnız farklı davrananı yazar.
protocol ForwardingSocialCloud: SocialCloud {
    func target() async -> InMemorySocialCloud
}

extension ForwardingSocialCloud {
    func account() async throws -> SocialCloudAccount { try await target().account() }
    func loadIdentity() async throws -> SocialIdentity? { try await target().loadIdentity() }
    func saveIdentity(_ identity: SocialIdentity) async throws { try await target().saveIdentity(identity) }
    func deleteIdentity() async throws { try await target().deleteIdentity() }
    func claim(forKey key: String) async throws -> SocialClaim? { try await target().claim(forKey: key) }
    func createClaim(_ claim: SocialClaim) async throws { try await target().createClaim(claim) }
    func updateClaim(_ claim: SocialClaim) async throws { try await target().updateClaim(claim) }
    func deleteClaim(key: String) async throws { try await target().deleteClaim(key: key) }
    func sendMail(id: String, mailbox: String, sealed: Data) async throws {
        try await target().sendMail(id: id, mailbox: mailbox, sealed: sealed)
    }
    func mail(in mailbox: String) async throws -> [SocialMail] { try await target().mail(in: mailbox) }
    func deleteMail(id: String) async throws { try await target().deleteMail(id: id) }
    func createSpace(name: String, info: SocialSpaceInfo, card: SocialCard) async throws -> SocialSpace {
        try await target().createSpace(name: name, info: info, card: card)
    }
    func spaces() async throws -> [SocialSpace] { try await target().spaces() }
    func updateInfo(_ info: SocialSpaceInfo, in space: SocialSpaceID) async throws {
        try await target().updateInfo(info, in: space)
    }
    func saveCards(_ cards: [SocialSpaceID: SocialCard]) async throws { try await target().saveCards(cards) }
    func acceptInvite(_ invite: SocialInvite) async throws -> SocialSpace { try await target().acceptInvite(invite) }
    func removeSpace(_ id: SocialSpaceID) async throws { try await target().removeSpace(id) }
    func removeAllSpaces() async throws { try await target().removeAllSpaces() }
}
