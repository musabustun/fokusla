import Foundation
import Testing

@testable import FokusData

@MainActor
@Suite("SocialDemoWorld")
struct SocialDemoWorldTests {
    @Test("istek gelir, gönderdiğim istek kabul edilir, arkadaşın odasına katılınır")
    func story() async throws {
        let world = SocialDemoWorld(sessionProvider: { "ben" }, pollMs: 0)
        let me = world.service
        await world.prepare()
        await me.refresh()
        try await me.claimUsername("ben.yks")
        await world.tick()
        await me.refresh()
        #expect(me.snapshot.requests.map(\.user.username) == ["zeynep2027"])

        try await me.sendFriendRequest(.username("elif.say"))
        await world.tick()
        await me.refresh()
        #expect(me.snapshot.friends.map(\.username) == ["elif.say"])
        #expect(me.snapshot.friends.first?.presence?.state == .focusing)

        let room = try #require(me.snapshot.friendRooms.first)
        #expect(try await me.joinRoom(.room(id: room.id)).name == "Sabah kampı")
        await world.prepare()
        world.start()
        world.start()
        world.stop()
    }
}
