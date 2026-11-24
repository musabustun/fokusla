import FokusDomain
import Foundation
import Testing

@testable import FokusData

@MainActor
@Suite("CloudSocialService — oturum ve profil")
struct CloudSocialProfileTests {
    let world = SocialTestWorld()

    @Test("giriş yoksa CloudKit'e hiç dokunmaz")
    func signedOut() async {
        let service = world.service("ben", signedIn: false)
        await world.server.setOffline(true, user: "ben")
        await service.refresh()
        #expect(service.snapshot.status == .signedOut)
        await expectSocialError(.notSignedIn) { try await service.claimUsername("ben.yks") }
        await expectSocialError(.notSignedIn) { _ = try await service.createFriendInvite() }
    }

    @Test("iCloud hesabı yoksa durum ve hata iCloud'u söyler")
    func noICloud() async {
        let service = world.service("ben")
        await world.server.setAccountless(true, user: "ben")
        await service.refresh()
        #expect(service.snapshot.status == .iCloudUnavailable)
        await expectSocialError(.iCloudUnavailable) { try await service.claimUsername("ben.yks") }
    }

    @Test("kullanıcı adı alınca profil hazır olur ve diğer cihazda da görünür")
    func claim() async throws {
        let phone = world.service("ben")
        await phone.refresh()
        #expect(phone.snapshot.status == .needsUsername)
        try await phone.claimUsername("@Ben.YKS")
        #expect(phone.snapshot.status == .ready)
        #expect(phone.snapshot.profile?.username == "ben.yks")

        let pad = world.service("ben")
        await pad.refresh()
        #expect(pad.snapshot.profile == phone.snapshot.profile)
    }

    @Test("ad tekildir; biçim ve uygunsuz söz denetlenir")
    func uniqueness() async throws {
        _ = try await world.user("elif.say")
        let other = world.service("mert")
        await other.refresh()
        #expect(await other.checkUsername("elif.say") == .taken)
        #expect(await other.checkUsername("bos.ad") == .ok("bos.ad"))
        #expect(await other.checkUsername("1a") == .invalid(.tooShort))
        await expectSocialError(.usernameTaken) { try await other.claimUsername("elif.say") }
        await expectSocialError(.invalidUsername) { try await other.claimUsername("1ab") }
        await expectSocialError(.inappropriateText) { try await other.claimUsername("sik_123") }
        #expect(other.snapshot.status == .needsUsername)
    }

    @Test("ad değişince eskisi boşalır ve arkadaş yeni adı görür")
    func rename() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await world.befriend(elif, mert)
        try await elif.claimUsername("elif.yeni")
        await mert.refresh()
        #expect(mert.snapshot.friends.map(\.username) == ["elif.yeni"])
        #expect(await mert.checkUsername("elif") == .ok("elif"))
    }

    @Test("yarım kalan denemedeki kendi kaydım yeniden alınabilir")
    func reclaimOwn() async throws {
        let first = try await world.user("elif")
        try await InMemorySocialCloud(userId: "elif", server: world.server).deleteIdentity()
        await first.refresh()
        #expect(first.snapshot.status == .needsUsername)
        try await first.claimUsername("elif")
        #expect(first.snapshot.status == .ready)
    }

    @Test("ağ yokken: ilk yükleme ulaşılamaz, sonrasında son bilinen durum korunur")
    func offline() async throws {
        let elif = try await world.user("elif")
        await world.server.setOffline(true, user: "elif")
        await elif.refresh()
        #expect(elif.snapshot.status == .ready)
        #expect(elif.snapshot.isOffline)
        await expectSocialError(.network) { _ = try await elif.createFriendInvite() }

        let cold = world.service("elif")
        await cold.refresh()
        #expect(cold.snapshot.status == .unreachable)

        await world.server.setOffline(false, user: "elif")
        await elif.refresh()
        #expect(!elif.snapshot.isOffline)
    }

    @Test("sosyal profili silmek her izi kaldırır")
    func deleteAccount() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        let zeynep = try await world.user("zeynep")
        try await world.befriend(elif, mert)
        try await world.befriend(zeynep, elif)
        _ = try await world.user("deniz")
        try await elif.sendFriendRequest(.username("deniz"))
        try await elif.createRoom(name: "Oda")

        try await elif.deleteAccount()
        #expect(elif.snapshot == .empty(.needsUsername))
        await mert.refresh()
        await zeynep.refresh()
        #expect(mert.snapshot.friends.isEmpty)
        #expect(zeynep.snapshot.friends.isEmpty)
        #expect(await world.server.spaceCount == 0)
        #expect(await world.server.mailCount == 0)
        #expect(await world.server.claimCount == 3)
    }

    @Test("görünürken düzenli yenilenir, bırakılınca durur")
    func polling() async throws {
        let scheduler = ManualSocialScheduler()
        let service = world.service("ben", scheduler: scheduler)
        service.activate()
        service.activate()
        #expect(scheduler.pendingCount == 1)
        service.deactivate()
        #expect(scheduler.pendingCount == 1)
        service.deactivate()
        service.deactivate()
        #expect(scheduler.pendingCount == 0)
    }
}

@MainActor
@Suite("CloudSocialService — arkadaşlık")
struct CloudSocialFriendTests {
    let world = SocialTestWorld()

    @Test("bağlantıyla davet: kabulden sonra iki taraf birbirini görür")
    func linkInvite() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await elif.publishPresence(world.presence(.focusing, today: 5000))

        let invite = try await elif.createFriendInvite()
        #expect(elif.snapshot.pendingInvites == [invite])
        #expect(elif.snapshot.friends.isEmpty)
        #expect(try await mert.acceptInvite(SocialInvite(url: invite.url)) == .friend(username: "elif"))
        #expect(mert.snapshot.friends.map(\.username) == ["elif"])
        #expect(mert.snapshot.friends.first?.presence?.state == .focusing)

        await elif.refresh()
        #expect(elif.snapshot.friends.map(\.username) == ["mert"])
        #expect(elif.snapshot.pendingInvites.isEmpty)
    }

    @Test("bağlantı tek kullanımlıktır")
    func singleUse() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        let zeynep = try await world.user("zeynep")
        let invite = try await elif.createFriendInvite()
        try await mert.acceptInvite(SocialInvite(url: invite.url))
        await expectSocialError(.inviteInvalid) { try await zeynep.acceptInvite(SocialInvite(url: invite.url)) }
        #expect(zeynep.snapshot.friends.isEmpty)
    }

    @Test("kendi davetim, geçersiz davet ve zaten arkadaş")
    func inviteErrors() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        let own = try await elif.createFriendInvite()
        await expectSocialError(.cannotAddSelf) { try await elif.acceptInvite(SocialInvite(url: own.url)) }
        let bogus = URL(string: "https://www.icloud.com/share/yok")!
        await expectSocialError(.inviteInvalid) { try await elif.acceptInvite(SocialInvite(url: bogus)) }
        try await mert.acceptInvite(SocialInvite(url: own.url))
        await elif.refresh()
        let second = try await elif.createFriendInvite()
        await expectSocialError(.alreadyFriends) { try await mert.acceptInvite(SocialInvite(url: second.url)) }
        #expect(mert.snapshot.friends.count == 1)
    }

    @Test("geri çekilen bağlantı çalışmaz")
    func cancelInvite() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        let invite = try await elif.createFriendInvite()
        try await elif.cancelInvite(id: invite.id)
        #expect(elif.snapshot.pendingInvites.isEmpty)
        await expectSocialError(.inviteInvalid) { try await mert.acceptInvite(SocialInvite(url: invite.url)) }
        await expectSocialError(.requestNotFound) { try await elif.cancelInvite(id: invite.id) }
    }

    @Test("kullanıcı adına istek: kabul edilene kadar kimse kimsenin durumunu görmez")
    func usernameRequest() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await elif.publishPresence(world.presence(.focusing))
        try await elif.sendFriendRequest(.username("@MERT"))
        #expect(elif.snapshot.requests.map(\.direction) == [.outgoing])
        #expect(elif.snapshot.requests.first?.user.username == "mert")
        #expect(elif.snapshot.friends.isEmpty)

        await mert.refresh()
        let request = try #require(mert.snapshot.requests.first)
        #expect(request.direction == .incoming)
        #expect(request.user.username == "elif")
        #expect(mert.snapshot.friends.isEmpty)

        try await mert.respondToRequest(id: request.id, accept: true)
        #expect(mert.snapshot.friends.map(\.username) == ["elif"])
        #expect(mert.snapshot.requests.isEmpty)

        await elif.refresh()
        #expect(elif.snapshot.friends.map(\.username) == ["mert"])
        #expect(elif.snapshot.requests.isEmpty)
        #expect(await world.server.mailCount == 0)
    }

    @Test("olmayan ada istek gitmez")
    func unknownUsername() async throws {
        let elif = try await world.user("elif")
        await expectSocialError(.userNotFound) { try await elif.sendFriendRequest(.username("kimse_yok")) }
        await expectSocialError(.invalidUsername) { try await elif.sendFriendRequest(.username("1")) }
        await expectSocialError(.cannotAddSelf) { try await elif.sendFriendRequest(.username("elif")) }
        await expectSocialError(.invalidInviteCode) { try await elif.sendFriendRequest(.inviteCode("ABC123")) }
        #expect(await world.server.spaceCount == 0)
        #expect(await world.server.mailCount == 0)
    }

    @Test("ret: gönderen arkadaş olmaz, istek alıcıda bir daha görünmez")
    func decline() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await elif.sendFriendRequest(.username("mert"))
        await mert.refresh()
        let request = try #require(mert.snapshot.requests.first)
        try await mert.respondToRequest(id: request.id, accept: false)
        await mert.refresh()
        #expect(mert.snapshot.requests.isEmpty)
        await expectSocialError(.requestNotFound) { try await mert.respondToRequest(id: request.id, accept: true) }
        await elif.refresh()
        #expect(elif.snapshot.friends.isEmpty)
        // Gönderen geri çekince iz kalmaz.
        try await elif.cancelRequest(id: #require(elif.snapshot.requests.first).id)
        #expect(await world.server.mailCount == 0)
        #expect(await world.server.spaceCount == 0)
    }

    @Test("gönderen geri çektiyse kabul hata verir ve istek kalkar")
    func withdrawnBeforeAccept() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await elif.sendFriendRequest(.username("mert"))
        await mert.refresh()
        let request = try #require(mert.snapshot.requests.first)
        try await elif.cancelRequest(id: #require(elif.snapshot.requests.first).id)
        await expectSocialError(.requestNotFound) { try await mert.respondToRequest(id: request.id, accept: true) }
        #expect(mert.snapshot.requests.isEmpty)
    }

    @Test("aynı kişiye ikinci istek, gelen isteği olan kişiye istek ve arkadaşa istek engellenir")
    func duplicates() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await elif.sendFriendRequest(.username("mert"))
        await expectSocialError(.requestExists) { try await elif.sendFriendRequest(.username("mert")) }
        await mert.refresh()
        await expectSocialError(.requestExists) { try await mert.sendFriendRequest(.username("elif")) }
        try await mert.respondToRequest(id: #require(mert.snapshot.requests.first).id, accept: true)
        await elif.refresh()
        await expectSocialError(.alreadyFriends) { try await elif.sendFriendRequest(.username("mert")) }
    }

    @Test("iki taraf aynı anda davet ettiyse tek arkadaşlık kalır")
    func crossedInvites() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        let fromElif = try await elif.createFriendInvite()
        let fromMert = try await mert.createFriendInvite()
        // İkisi de karşı tarafın kabulünü henüz görmeden kabul eder.
        try await InMemoryJoin.join(world, user: "mert", service: mert, url: fromElif.url)
        try await InMemoryJoin.join(world, user: "elif", service: elif, url: fromMert.url)
        for _ in 0..<3 {
            await elif.refresh()
            await mert.refresh()
        }
        #expect(elif.snapshot.friends.map(\.username) == ["mert"])
        #expect(mert.snapshot.friends.map(\.username) == ["elif"])
        #expect(await world.server.spaceCount == 1)
    }

    @Test("bekleyen davet sayısı sınırlıdır")
    func pendingLimit() async throws {
        let elif = try await world.user("elif")
        for _ in 0..<CloudSocialService.maxPendingInvites { _ = try await elif.createFriendInvite() }
        await expectSocialError(.tooManyRequests) { _ = try await elif.createFriendInvite() }
    }

    @Test("kullanılmayan davet 30 günde silinir")
    func expiry() async throws {
        let elif = try await world.user("elif")
        _ = try await world.user("mert")
        _ = try await elif.createFriendInvite()
        try await elif.sendFriendRequest(.username("mert"))
        world.clock.advance(31 * 24 * 3600)
        await elif.refresh()
        #expect(elif.snapshot.pendingInvites.isEmpty)
        #expect(elif.snapshot.requests.isEmpty)
        #expect(await world.server.spaceCount == 0)
        #expect(await world.server.mailCount == 0)
    }

    @Test("arkadaşlıktan çıkma iki yönde de çalışır", arguments: [true, false])
    func remove(byOwner: Bool) async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await world.befriend(elif, mert)
        let remover = byOwner ? elif : mert
        let other = byOwner ? mert : elif
        try await remover.removeFriend(userId: #require(remover.snapshot.friends.first).userId)
        #expect(remover.snapshot.friends.isEmpty)
        await other.refresh()
        #expect(other.snapshot.friends.isEmpty)
        #expect(other.snapshot.pendingInvites.isEmpty)
        await remover.refresh()
        #expect(await world.server.spaceCount == 0)
        await expectSocialError(.friendNotFound) { try await remover.removeFriend(userId: "yok") }
        // Yeniden arkadaş olunabilir.
        try await world.befriend(elif, mert)
        #expect(elif.snapshot.friends.count == 1)
    }

    @Test("engellenen arkadaşın yeni isteği görünmez; davetini kabul etmek engeli kaldırır")
    func blockFriend() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await world.befriend(elif, mert)
        try await elif.blockFriend(userId: #require(elif.snapshot.friends.first).userId)
        await mert.refresh()
        try await mert.sendFriendRequest(.username("elif"))
        await elif.refresh()
        #expect(elif.snapshot.requests.isEmpty)

        let invite = try await mert.createFriendInvite()
        try await elif.acceptInvite(SocialInvite(url: invite.url))
        #expect(elif.snapshot.friends.map(\.username) == ["mert"])
    }

    @Test("istek sahibini engelleme isteği kaldırır ve yenilerini gizler")
    func blockRequest() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await mert.sendFriendRequest(.username("elif"))
        await elif.refresh()
        try await elif.blockRequest(id: #require(elif.snapshot.requests.first).id)
        #expect(elif.snapshot.requests.isEmpty)
        try await mert.cancelRequest(id: #require(mert.snapshot.requests.first).id)
        try await mert.sendFriendRequest(.username("elif"))
        await elif.refresh()
        #expect(elif.snapshot.requests.isEmpty)
    }

    @Test("başkasının adıyla yazılmış ya da bozuk mektup yok sayılır")
    func forgedMail() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        _ = mert
        let attacker = InMemorySocialCloud(userId: "kotu", server: world.server)
        let claim = try #require(try await attacker.claim(forKey: SocialDirectory.claimKey(forUsername: "elif")))
        let payload = SocialMailPayload(
            v: 1, username: "mert", personId: "x", url: URL(string: "https://www.icloud.com/share/x")!)
        let sealed = try SocialMailCrypto.seal(
            JSONEncoder().encode(payload), publicKey: claim.publicKey, mailbox: claim.mailbox)
        try await attacker.sendMail(id: "sahte", mailbox: claim.mailbox, sealed: sealed)
        try await attacker.sendMail(id: "bozuk", mailbox: claim.mailbox, sealed: Data([1, 2, 3]))
        await elif.refresh()
        #expect(elif.snapshot.status == .ready)
        #expect(elif.snapshot.requests.isEmpty)
    }

    @Test("public'te kullanıcı adı ve davet adresi açık durmaz")
    func publicPrivacy() async throws {
        let elif = try await world.user("elif.gizli")
        _ = try await world.user("mert.gizli")
        try await elif.sendFriendRequest(.username("mert.gizli"))
        for bytes in await world.server.publicBytes {
            for secret in ["elif.gizli", "mert.gizli", "icloud.com"] {
                #expect(bytes.range(of: Data(secret.utf8)) == nil)
            }
        }
    }

    @Test("mektup gönderilemezse davet de kalmaz")
    func mailFailure() async throws {
        let cloud = FailingMailCloud(base: InMemorySocialCloud(userId: "elif", server: world.server))
        let clock = world.clock
        let elif = CloudSocialService(
            sessionProvider: { "apple" }, cloud: cloud, scheduler: ManualSocialScheduler(), now: { clock.now })
        await elif.refresh()
        try await elif.claimUsername("elif")
        _ = try await world.user("mert")
        await expectSocialError(.network) { try await elif.sendFriendRequest(.username("mert")) }
        #expect(elif.snapshot.requests.isEmpty)
        #expect(await world.server.spaceCount == 0)
    }
}

@MainActor
@Suite("CloudSocialService — durum paylaşımı")
struct CloudSocialPresenceTests {
    let world = SocialTestWorld()

    @Test("durum ve günlük süre arkadaşa yansır; telefon kilitliyken 3 saat canlı kalır")
    func publish() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await world.befriend(elif, mert)
        try await elif.publishPresence(world.presence(.focusing, today: 60_000))
        world.clock.advance(3600)
        await mert.refresh()
        let presence = try #require(mert.snapshot.friends.first?.presence)
        #expect(SocialCalc.effectivePresenceState(presence, now: world.clock.now) == .focusing)
        #expect(SocialCalc.liveTodayFocusMs(presence, now: world.clock.now) == 60_000 + 3_600_000)
        world.clock.advance(3 * 3600)
        await mert.refresh()
        #expect(SocialCalc.effectivePresenceState(mert.snapshot.friends.first?.presence, now: world.clock.now) == .offline)
    }

    @Test("dünkü süre bugün sıfırlanır")
    func dayRollover() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await world.befriend(elif, mert)
        try await elif.publishPresence(world.presence(.offline, today: 7_200_000))
        await mert.refresh()
        #expect(mert.snapshot.friends.first?.presence?.todayFocusMs == 7_200_000)
        world.clock.advance(24 * 3600)
        await mert.refresh()
        #expect(mert.snapshot.friends.first?.presence?.todayFocusMs == 0)
    }

    @Test("gizlenince durum silinir, adıma istek gelmez; açınca geri gelir")
    func hide() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        let zeynep = try await world.user("zeynep")
        try await world.befriend(elif, mert)
        try await elif.publishPresence(world.presence(.focusing, today: 1000))
        try await elif.setDiscoverable(false)
        #expect(elif.snapshot.profile?.isDiscoverable == false)
        try await elif.publishPresence(world.presence(.focusing, today: 2000))
        await mert.refresh()
        #expect(mert.snapshot.friends.first?.presence == nil)
        await expectSocialError(.userNotFound) { try await zeynep.sendFriendRequest(.username("elif")) }

        try await elif.setDiscoverable(true)
        await mert.refresh()
        #expect(mert.snapshot.friends.first?.presence?.todayFocusMs == 2000)
        try await zeynep.sendFriendRequest(.username("elif"))
    }

    @Test("değişmeyen çevrimdışı durum yeniden yazılmaz")
    func quota() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await world.befriend(elif, mert)
        try await elif.publishPresence(world.presence(.offline, today: 1000))
        let before = await world.server.writeCount
        world.clock.advance(60)
        try await elif.publishPresence(world.presence(.offline, today: 1000))
        #expect(await world.server.writeCount == before)
        try await elif.publishPresence(world.presence(.offline, today: 2000))
        #expect(await world.server.writeCount == before + 1)
        try await elif.publishPresence(world.presence(.focusing, today: 2000))
        try await elif.publishPresence(world.presence(.focusing, today: 2000))
        #expect(await world.server.writeCount == before + 3)
    }

    @Test("arkadaşlarım birbirini görmez")
    func isolation() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        let zeynep = try await world.user("zeynep")
        try await world.befriend(elif, mert)
        try await world.befriend(elif, zeynep)
        await mert.refresh()
        await zeynep.refresh()
        #expect(elif.snapshot.friends.map(\.username) == ["mert", "zeynep"])
        #expect(mert.snapshot.friends.map(\.username) == ["elif"])
        #expect(zeynep.snapshot.friends.map(\.username) == ["elif"])
    }

    @Test("kabulden sonra kart yazılamadıysa bir sonraki yenileme tamamlar")
    func repairsMissingCard() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        let invite = try await elif.createFriendInvite()
        _ = try await InMemorySocialCloud(userId: "mert", server: world.server).acceptInvite(SocialInvite(url: invite.url))
        await elif.refresh()
        #expect(elif.snapshot.friends.isEmpty)
        await mert.refresh()
        #expect(mert.snapshot.friends.map(\.username) == ["elif"])
        await elif.refresh()
        #expect(elif.snapshot.friends.map(\.username) == ["mert"])
    }
}

@MainActor
@Suite("CloudSocialService — odalar")
struct CloudSocialRoomTests {
    let world = SocialTestWorld()

    @Test("arkadaş listeden katılır; yabancı bağlantıyla katılır; herkes durumları görür")
    func joinBothWays() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        let yabanci = try await world.user("yabanci")
        try await world.befriend(elif, mert)
        try await elif.publishPresence(world.presence(.focusing))
        let room = try await elif.createRoom(name: "  Sabah kampı ")
        #expect(room.name == "Sabah kampı")
        #expect(room.members.map(\.isHost) == [true])

        await mert.refresh()
        let summary = try #require(mert.snapshot.friendRooms.first)
        #expect(summary.name == "Sabah kampı")
        #expect(summary.focusingCount == 1)
        world.clock.advance(1)
        try await mert.joinRoom(.room(id: summary.id))
        #expect(mert.snapshot.friendRooms.isEmpty)

        world.clock.advance(1)
        let url = try #require(room.inviteURL)
        #expect(try await yabanci.acceptInvite(SocialInvite(url: url)) == .room(name: "Sabah kampı"))
        #expect(yabanci.snapshot.room?.members.map(\.username) == ["elif", "mert", "yabanci"])
        #expect(yabanci.snapshot.friends.isEmpty)

        try await mert.publishPresence(world.presence(.onBreak))
        await elif.refresh()
        #expect(elif.snapshot.room?.members.map(\.username) == ["elif", "mert", "yabanci"])
        #expect(elif.snapshot.room?.members[1].presence?.state == .onBreak)
        await mert.refresh()
        #expect(mert.snapshot.friends.map(\.username) == ["elif"])
    }

    @Test("üye çıkınca listeden düşer ve yeniden katılabilir; ev sahibi kapatınca oda biter")
    func leave() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await world.befriend(elif, mert)
        let room = try await elif.createRoom(name: "Oda")
        let invite = SocialInvite(url: try #require(room.inviteURL))
        try await mert.acceptInvite(invite)
        await mert.leaveRoom()
        #expect(mert.snapshot.room == nil)
        await elif.refresh()
        #expect(elif.snapshot.room?.members.count == 1)

        try await mert.acceptInvite(invite)
        #expect(mert.snapshot.room?.members.count == 2)
        await elif.leaveRoom()
        #expect(elif.snapshot.room == nil)
        await mert.refresh()
        #expect(mert.snapshot.room == nil)
        #expect(mert.snapshot.friendRooms.isEmpty)
        await expectSocialError(.roomNotFound) { try await mert.joinRoom(.room(id: room.id)) }
        await expectSocialError(.inviteInvalid) { try await mert.acceptInvite(invite) }
        await elif.leaveRoom()
    }

    @Test("arkadaşın duyurduğu oda kapanmışsa katılma roomNotFound verir")
    func staleAnnouncement() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await world.befriend(elif, mert)
        try await elif.publishPresence(world.presence(.focusing))
        let room = try await elif.createRoom(name: "Oda")
        await mert.refresh()
        #expect(mert.snapshot.friendRooms.map(\.id) == [room.id])
        await elif.leaveRoom()
        await expectSocialError(.roomNotFound) { try await mert.joinRoom(.room(id: room.id)) }
    }

    @Test("odam açıkken yeni arkadaş olan kişi odayı hemen görür", arguments: [true, false])
    func announcedToNewFriend(invitedByHost: Bool) async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        try await elif.publishPresence(world.presence(.focusing))
        try await elif.createRoom(name: "Oda")
        try await world.befriend(invitedByHost ? elif : mert, invitedByHost ? mert : elif)
        await mert.refresh()
        #expect(mert.snapshot.friendRooms.map(\.name) == ["Oda"])
    }

    @Test("yeni odaya geçmek öncekinden çıkarır")
    func switchRooms() async throws {
        let elif = try await world.user("elif")
        let mert = try await world.user("mert")
        let first = try await elif.createRoom(name: "Bir")
        let second = try await mert.createRoom(name: "İki")
        try await mert.acceptInvite(SocialInvite(url: #require(first.inviteURL)))
        #expect(mert.snapshot.room?.name == "Bir")
        await expectSocialError(.inviteInvalid) { try await elif.acceptInvite(SocialInvite(url: #require(second.inviteURL))) }
        #expect(await world.server.spaceCount == 1)
    }

    @Test("oda adı denetlenir", arguments: [
        ("   ", SocialErrorCode.invalidRoomName), (String(repeating: "a", count: 41), .invalidRoomName),
        ("piç oda", .inappropriateText),
    ])
    func names(name: String, code: SocialErrorCode) async throws {
        let elif = try await world.user("elif")
        await expectSocialError(code) { try await elif.createRoom(name: name) }
    }

    @Test("kod desteklenmez; profil yoksa oda açılamaz")
    func unsupported() async throws {
        let elif = try await world.user("elif")
        await expectSocialError(.invalidInviteCode) { try await elif.joinRoom(.inviteCode("ABC123")) }
        let nobody = world.service("yok")
        await expectSocialError(.noProfile) { try await nobody.createRoom(name: "Oda") }
    }

    @Test("oda 20 kişiyle sınırlıdır")
    func capacity() async throws {
        let host = try await world.user("host")
        let room = try await host.createRoom(name: "Kalabalık")
        let invite = SocialInvite(url: try #require(room.inviteURL))
        for index in 1..<CloudSocialService.maxRoomMembers {
            try await world.user("uye\(index)").acceptInvite(invite)
        }
        let late = try await world.user("gec")
        await expectSocialError(.roomFull) { try await late.acceptInvite(invite) }
        #expect(late.snapshot.room == nil)
        await host.refresh()
        #expect(host.snapshot.room?.members.count == 20)
    }

    @Test("çıkış ağ hatasında odayı bırakmaz")
    func leaveOffline() async throws {
        let elif = try await world.user("elif")
        try await elif.createRoom(name: "Oda")
        await world.server.setOffline(true, user: "elif")
        await elif.leaveRoom()
        #expect(elif.snapshot.room != nil)
    }
}

@Suite("SocialInvite")
struct SocialInviteTests {
    @Test("yapıştırılan metinden yalnız iCloud paylaşım adresi alınır", arguments: [
        ("https://www.icloud.com/share/0abc#Fokus", true),
        ("Beni ekle: https://www.icloud.com/share/0abc#Fokus hadi", true),
        ("https://icloud.com.cn/share/0abc", true),
        ("http://www.icloud.com/share/0abc", false),
        ("https://www.icloud.com/photos/0abc", false),
        ("https://icloud.com.evil.example/share/0abc", false),
        ("https://evilicloud.com/share/0abc", false),
        ("fokus://room?x=1", false),
        ("", false),
    ])
    func parsing(text: String, ok: Bool) {
        #expect((SocialInvite(text: text) != nil) == ok)
    }
}

// MARK: - Yardımcılar

/// Kabul edip kartı yazar ama servisi yenilemez (çapraz davet yarışı).
enum InMemoryJoin {
    @MainActor
    static func join(_ world: SocialTestWorld, user: String, service: CloudSocialService, url: URL) async throws {
        let cloud = InMemorySocialCloud(userId: user, server: world.server)
        let space = try await cloud.acceptInvite(SocialInvite(url: url))
        let card = try #require(service.makeCard(joinedAt: world.clock.now, kind: .friend))
        try await cloud.saveCards([space.id: card])
    }
}

/// Yalnız mektup göndermesi başarısız olan bulut.
private struct FailingMailCloud: SocialCloud {
    let base: InMemorySocialCloud

    func account() async throws -> SocialCloudAccount { try await base.account() }
    func loadIdentity() async throws -> SocialIdentity? { try await base.loadIdentity() }
    func saveIdentity(_ identity: SocialIdentity) async throws { try await base.saveIdentity(identity) }
    func deleteIdentity() async throws { try await base.deleteIdentity() }
    func claim(forKey key: String) async throws -> SocialClaim? { try await base.claim(forKey: key) }
    func createClaim(_ claim: SocialClaim) async throws { try await base.createClaim(claim) }
    func updateClaim(_ claim: SocialClaim) async throws { try await base.updateClaim(claim) }
    func deleteClaim(key: String) async throws { try await base.deleteClaim(key: key) }
    func sendMail(id: String, mailbox: String, sealed: Data) async throws { throw SocialCloudError.network }
    func mail(in mailbox: String) async throws -> [SocialMail] { try await base.mail(in: mailbox) }
    func deleteMail(id: String) async throws { try await base.deleteMail(id: id) }
    func createSpace(name: String, info: SocialSpaceInfo, card: SocialCard) async throws -> SocialSpace {
        try await base.createSpace(name: name, info: info, card: card)
    }
    func spaces() async throws -> [SocialSpace] { try await base.spaces() }
    func updateInfo(_ info: SocialSpaceInfo, in space: SocialSpaceID) async throws { try await base.updateInfo(info, in: space) }
    func saveCards(_ cards: [SocialSpaceID: SocialCard]) async throws { try await base.saveCards(cards) }
    func acceptInvite(_ invite: SocialInvite) async throws -> SocialSpace { try await base.acceptInvite(invite) }
    func removeSpace(_ id: SocialSpaceID) async throws { try await base.removeSpace(id) }
}
