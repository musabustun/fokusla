import CloudKit
import FokusDomain
import Foundation
import Testing

@testable import FokusData

@Suite("SocialRecordMapping")
struct SocialRecordMappingTests {
    private typealias Mapping = SocialRecordMapping

    private let zone = CKRecordZone.ID(zoneName: "friend-1", ownerName: "_sahip")
    private let roomZone = CKRecordZone.ID(zoneName: "room-1", ownerName: "_sahip")
    private let now = Date(timeIntervalSince1970: 1_795_510_800)
    private let shareURL = URL(string: "https://www.icloud.com/share/abc")!

    private var fullCard: SocialCard {
        SocialCard(
            personId: "p1", username: "elif",
            presence: SocialPresence(
                state: .focusing, sessionStartedAt: now, stateSince: now, todayFocusMs: 1234, updatedAt: now,
                expiresAt: now.addingTimeInterval(60)),
            joinedAt: now,
            room: SocialCardRoom(id: "room-1", name: "Oda", url: shareURL, memberCount: 3, focusingCount: 2))
    }

    @Test("kart gidiş-dönüş aynıdır")
    func cardRoundTrip() {
        #expect(Mapping.card(Mapping.record(fullCard, in: zone)) == fullCard)
        let left = SocialCard(personId: "p1", username: "elif", joinedAt: now, leftAt: now)
        #expect(Mapping.card(Mapping.record(left, in: zone)) == left)
    }

    @Test("gizlenen kart eski durumun üstüne açık boş değer yazar")
    func hiddenCardOverwrites() {
        let hidden = SocialCard(personId: "p1", username: "elif", joinedAt: now)
        let keys = Set(Mapping.record(fullCard, in: zone).allKeys())
        #expect(Set(Mapping.record(hidden, in: zone).allKeys()) == keys)
        #expect(Mapping.card(Mapping.record(hidden, in: zone))?.presence == nil)
        #expect(Mapping.card(Mapping.record(hidden, in: zone))?.room == nil)
    }

    @Test("kurcalanmış kart yok sayılır ya da sınırlanır")
    func untrustedCard() {
        let wrongName = CKRecord(recordType: "SocialCard", recordID: CKRecord.ID(recordName: "card-baska", zoneID: zone))
        wrongName["personId"] = "p1"
        wrongName["username"] = "elif"
        #expect(Mapping.card(wrongName) == nil)

        let badUsername = Mapping.record(fullCard, in: zone)
        badUsername["username"] = "Çok Uzun ve Geçersiz Bir Ad"
        #expect(Mapping.card(badUsername) == nil)

        let badValues = Mapping.record(fullCard, in: zone)
        badValues["todayFocusMs"] = Double.infinity
        badValues["roomURL"] = "https://evil.example/share/abc"
        #expect(Mapping.card(badValues)?.presence?.todayFocusMs == 0)
        #expect(Mapping.card(badValues)?.room == nil)

        let rude = Mapping.record(fullCard, in: zone)
        rude["roomName"] = "piç oda"
        #expect(Mapping.card(rude)?.room?.name == "Oda")
    }

    @Test("alan bilgisi gidiş-dönüş; tür bölge önekiyle uyuşmalı")
    func info() {
        let friend = SocialSpaceInfo(
            kind: .friend, hostPersonId: "p1", toUsername: "mert", mailId: "m1", createdAt: now)
        #expect(Mapping.info(Mapping.record(friend, in: zone)) == friend)
        let room = SocialSpaceInfo(kind: .room, name: "Sabah", hostPersonId: "p1", createdAt: now)
        #expect(Mapping.info(Mapping.record(room, in: roomZone)) == room)
        #expect(Mapping.info(Mapping.record(room, in: zone)) == nil)
    }

    @Test("alan: bilgi kaydı yoksa yok sayılır")
    func space() {
        let info = SocialSpaceInfo(kind: .friend, hostPersonId: "p1", createdAt: now)
        let records = [Mapping.record(info, in: zone), Mapping.record(fullCard, in: zone)]
        let space = Mapping.space(zoneID: zone, isMine: false, records: records)
        #expect(space?.id == SocialSpaceID(name: "friend-1", ownerName: "_sahip", isMine: false))
        #expect(space?.cards == [fullCard])
        #expect(space?.inviteURL == nil)
        #expect(Mapping.space(zoneID: zone, isMine: false, records: [Mapping.record(fullCard, in: zone)]) == nil)
        #expect(Mapping.isSocialZone(zone))
        #expect(!Mapping.isSocialZone(CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone")))
    }

    @Test("kendi kaydımın oluşturanı gerçek kimliğime çevrilir")
    func currentUser() {
        #expect(Mapping.userId(CKCurrentUserDefaultName, currentUserId: "_ben") == "_ben")
        #expect(Mapping.userId("_baska", currentUserId: "_ben") == "_baska")
    }

    @Test("CloudKit hataları çevrilir", arguments: [
        (CKError.Code.networkUnavailable, SocialCloudError.network), (.requestRateLimited, .network),
        (.notAuthenticated, .noAccount), (.unknownItem, .notFound), (.zoneNotFound, .notFound),
        (.permissionFailure, .permission), (.serverRecordChanged, .conflict), (.quotaExceeded, .other("CKError.25")),
    ])
    func errors(code: CKError.Code, expected: SocialCloudError) {
        #expect(Mapping.error(CKError(code)) == expected)
    }

    @Test("kısmi hatada asıl neden alınır")
    func partial() {
        let error = CKError(.partialFailure, userInfo: [
            CKPartialErrorsByItemIDKey: ["a": CKError(.batchRequestFailed), "b": CKError(.serverRecordChanged)],
        ])
        #expect(Mapping.error(error) == .conflict)
        #expect(Mapping.error(CKError(.partialFailure)) == .other("partialFailure"))
        #expect(Mapping.error(SocialCloudError.ownInvite) == .ownInvite)
        #expect(Mapping.error(CancellationError()) == .other("CancellationError"))
    }
}
