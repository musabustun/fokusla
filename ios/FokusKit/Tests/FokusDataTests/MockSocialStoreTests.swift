import FokusDomain
import Foundation
import Testing

@testable import FokusData

// Saklanan mock verisinin savunmacı ayrıştırması — web `mockSocialStore.test.ts` vakalarıyla birebir.

private let at = Date(timeIntervalSince1970: 1_795_071_600)  // 2026-11-19T07:00:00Z
private let atISO = "2026-11-19T07:00:00.000Z"

private func account(_ username: String) -> StoredAccount {
    StoredAccount(
        profile: SocialProfile(
            userId: "self-\(username)", username: username, inviteCode: "ABC234", isDiscoverable: true),
        friends: [StoredFriend(userId: "u1", username: "elif.say", friendsSince: at)],
        requests: [
            FriendRequest(
                id: "r1", direction: .incoming, user: SocialUser(userId: "u2", username: "zeynep2027"),
                createdAt: at)
        ],
        room: .hosted(
            id: "room1", name: "Gece", inviteCode: "GECE23", createdAt: at,
            guests: [StoredRoomGuest(userId: "u1", joinedAt: at)]),
        selfPresence: SocialPresence(
            state: .focusing, sessionStartedAt: at, stateSince: at, todayFocusMs: 1000, updatedAt: at))
}

private func data(_ text: String) -> Data { Data(text.utf8) }

/// `{ "version": 1, "accounts": { ... } }` — `accounts` ham JSON metni.
private func document(_ accounts: String) -> Data { data(#"{"version":1,"accounts":\#(accounts)}"#) }

private let validProfile = #"{"userId":"x","username":"ali","inviteCode":"ABC234","isDiscoverable":true}"#

private func accountJSON(
    friends: String = "[]", requests: String = "[]", room: String = "null", selfPresence: String = "null"
) -> String {
    #"{"profile":\#(validProfile),"friends":\#(friends),"requests":\#(requests),"room":\#(room),"selfPresence":\#(selfPresence)}"#
}

private func parseAccount(
    friends: String = "[]", requests: String = "[]", room: String = "null", selfPresence: String = "null"
) -> StoredAccount? {
    let json = accountJSON(friends: friends, requests: requests, room: room, selfPresence: selfPresence)
    return MockSocialStore.parseDocument(document(#"{"a":\#(json)}"#)).accounts["a"]
}

private let emptyDocumentInputs: [String?] = [
    nil, "{bozuk", "[]", "\"x\"", #"{"version":2,"accounts":{}}"#, #"{"version":1,"accounts":[]}"#,
    #"{"version":1}"#, "42", "",
]

private let invalidPresences: [String] = [
    #"{"state":"focusing","sessionStartedAt":1,"stateSince":null,"todayFocusMs":0,"updatedAt":"\#(atISO)"}"#,
    #"{"state":"focusing","sessionStartedAt":null,"stateSince":null,"todayFocusMs":-1,"updatedAt":"\#(atISO)"}"#,
    #"{"state":"focusing","sessionStartedAt":null,"stateSince":null,"todayFocusMs":"x","updatedAt":"\#(atISO)"}"#,
    #"{"state":"focusing","sessionStartedAt":null,"stateSince":null,"todayFocusMs":0,"updatedAt":""}"#,
    #"{"state":"sleeping","sessionStartedAt":null,"stateSince":null,"todayFocusMs":0,"updatedAt":"\#(atISO)"}"#,
    "[]", "{}", "null",
]

@Suite("mockSocialStore")
struct MockSocialStoreTests {
    @Test("round-trips accounts and keeps other users intact")
    func roundTrip() {
        let storage = InMemorySocialStorage()
        MockSocialStore.writeAccount(storage: storage, appleUserId: "apple-a", account: account("ali"))
        MockSocialStore.writeAccount(storage: storage, appleUserId: "apple-b", account: account("veli"))

        #expect(MockSocialStore.readAccount(storage: storage, appleUserId: "apple-a") == account("ali"))
        #expect(MockSocialStore.readAccount(storage: storage, appleUserId: "apple-b") == account("veli"))
        #expect(MockSocialStore.readAccount(storage: storage, appleUserId: "apple-c") == nil)
        #expect(MockSocialStore.readAccount(storage: storage, appleUserId: "toString") == nil)
    }

    @Test("parses as an empty document", arguments: emptyDocumentInputs)
    func emptyDocument(_ raw: String?) {
        #expect(MockSocialStore.parseDocument(raw.map(data)) == StoredDocument.empty)
    }

    @Test("parseDocument(nil) boş belge döner ve anahtar sabittir")
    func nilAndKey() {
        #expect(MockSocialStore.parseDocument(nil).version == 1)
        #expect(MockSocialStore.parseDocument(nil).accounts.isEmpty)
        #expect(MockSocialStore.storageKey == "fokus.social.mock.v1")
    }

    @Test("drops accounts with an invalid profile")
    func invalidProfiles() {
        let good = accountJSON()
        let parsed = MockSocialStore.parseDocument(
            document(
                #"""
                {"good":\#(good),"noProfile":{"friends":[]},
                 "badProfile":{"profile":{"userId":"x","username":"y","inviteCode":"","isDiscoverable":true}},
                 "notObject":42}
                """#))
        #expect(Array(parsed.accounts.keys) == ["good"])
    }

    @Test("filters invalid list entries and resets invalid room/presence")
    func filtersInvalidEntries() {
        let friends =
            #"[{"userId":"u1","username":"a","friendsSince":"\#(atISO)"},{"userId":"u2"},"x"]"#
        let requests = #"""
            [{"id":"r1","direction":"sideways","user":{"userId":"u","username":"n"},"createdAt":"\#(atISO)"},
             {"id":"r2","direction":"outgoing","user":null,"createdAt":"\#(atISO)"},
             {"id":"r3","direction":"outgoing","user":{"userId":"u","username":"n"},"createdAt":"\#(atISO)"},
             null]
            """#
        let parsed = parseAccount(
            friends: friends, requests: requests, room: #"{"kind":"other"}"#,
            selfPresence: #"{"state":"sleeping"}"#)

        #expect(parsed?.friends == [StoredFriend(userId: "u1", username: "a", friendsSince: at)])
        #expect(parsed?.requests.map(\.id) == ["r3"])
        #expect(parsed?.room == nil)
        #expect(parsed?.selfPresence == nil)
    }

    @Test("parses joined rooms and validates their fields")
    func roomsValidation() {
        let joined = #"{"kind":"joined","roomId":"mock-room-sabah","joinedAt":"\#(atISO)"}"#
        #expect(parseAccount(room: joined)?.room == .joined(roomId: "mock-room-sabah", joinedAt: at))
        #expect(parseAccount(room: #"{"kind":"joined","roomId":"","joinedAt":"\#(atISO)"}"#)?.room == nil)
        #expect(
            parseAccount(room: #"{"kind":"hosted","id":"r","name":"","inviteCode":"X","createdAt":"\#(atISO)"}"#)?
                .room == nil)
        #expect(
            parseAccount(room: #"{"kind":"hosted","id":"r","name":"n","inviteCode":"","createdAt":"\#(atISO)"}"#)?
                .room == nil)
        let noGuests = #"{"kind":"hosted","id":"r","name":"n","inviteCode":"X","createdAt":"\#(atISO)","guests":"x"}"#
        #expect(
            parseAccount(room: noGuests)?.room
                == .hosted(id: "r", name: "n", inviteCode: "X", createdAt: at, guests: []))
        let mixedGuests = #"""
            {"kind":"hosted","id":"r","name":"n","inviteCode":"X","createdAt":"\#(atISO)",
             "guests":[{"userId":"u"},null,{"userId":"u","joinedAt":"\#(atISO)"}]}
            """#
        #expect(
            parseAccount(room: mixedGuests)?.room
                == .hosted(
                    id: "r", name: "n", inviteCode: "X", createdAt: at,
                    guests: [StoredRoomGuest(userId: "u", joinedAt: at)]))
        #expect(parseAccount(room: #""room""#)?.room == nil)
    }

    @Test("rejects invalid presence", arguments: invalidPresences)
    func invalidPresence(_ json: String) {
        #expect(MockSocialStore.parsePresence(data(json)) == nil)
    }

    @Test("parsePresence geçerli kaydı okur; tarihler ms hassasiyetinde, tarih null olabilir")
    func validPresence() {
        let json = #"{"state":"onBreak","sessionStartedAt":null,"stateSince":"2026-11-19T07:00:00.250Z","todayFocusMs":5,"updatedAt":"2026-11-19T07:00:00Z"}"#
        let parsed = MockSocialStore.parsePresence(data(json))
        #expect(parsed?.state == .onBreak)
        #expect(parsed?.sessionStartedAt == nil)
        #expect(parsed?.stateSince == at.addingTimeInterval(0.25))
        #expect(parsed?.updatedAt == at)
    }

    @Test("round-trips presence with nil dates and fractional seconds")
    func presenceRoundTrip() {
        let stamped = at.addingTimeInterval(0.5)
        let stored = StoredAccount(
            profile: account("ali").profile,
            selfPresence: SocialPresence(
                state: .offline, sessionStartedAt: nil, stateSince: nil, todayFocusMs: 12.5, updatedAt: stamped))
        let storage = InMemorySocialStorage()
        MockSocialStore.writeAccount(storage: storage, appleUserId: "a", account: stored)
        #expect(MockSocialStore.readAccount(storage: storage, appleUserId: "a") == stored)
    }

    @Test("preview account id is stored at the top level and survives account writes")
    func previewId() {
        let storage = InMemorySocialStorage()
        #expect(MockSocialStore.readPreviewAccountId(storage: storage) == nil)
        MockSocialStore.writePreviewAccountId(storage: storage, "preview-device")
        MockSocialStore.writeAccount(storage: storage, appleUserId: "preview-device", account: account("ali"))
        #expect(MockSocialStore.readPreviewAccountId(storage: storage) == "preview-device")
        MockSocialStore.writePreviewAccountId(storage: storage, nil)
        #expect(MockSocialStore.readPreviewAccountId(storage: storage) == nil)
        #expect(MockSocialStore.readAccount(storage: storage, appleUserId: "preview-device") != nil)
    }

    @Test("never throws or crashes when stored data is corrupt or cannot be encoded")
    func neverThrows() {
        let corrupt = InMemorySocialStorage(data: data("{bozuk"))
        MockSocialStore.writeAccount(storage: corrupt, appleUserId: "a", account: account("ali"))
        #expect(MockSocialStore.readAccount(storage: corrupt, appleUserId: "a") == account("ali"))

        // JSON kodlayıcı NaN'ı reddeder: yazma sessizce atlanır, eski veri korunur.
        var broken = account("veli")
        broken.selfPresence?.todayFocusMs = .nan
        MockSocialStore.writeAccount(storage: corrupt, appleUserId: "b", account: broken)
        #expect(MockSocialStore.readAccount(storage: corrupt, appleUserId: "b") == nil)
        #expect(MockSocialStore.readAccount(storage: corrupt, appleUserId: "a") == account("ali"))
    }

    @Test("encode: sıralı anahtarlar ve ISO 8601 tarihleri yazar")
    func encodedShape() throws {
        let storage = InMemorySocialStorage()
        MockSocialStore.writeAccount(storage: storage, appleUserId: "a", account: account("ali"))
        let text = String(decoding: try #require(storage.load()), as: UTF8.self)
        #expect(text.contains(#""version":1"#))
        #expect(text.contains(#""friendsSince":"2026-11-19T07:00:00.000Z""#))
        #expect(text.contains(#""kind":"hosted""#))
    }
}
