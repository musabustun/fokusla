import CloudKit
import FokusDomain
import Foundation

/// `SocialCard`/`SocialSpaceInfo`/… ↔ `CKRecord` eşlemesi (saf; ağ yok).
///
/// Boş alanlar `nil` yerine AÇIK boş değerle yazılır: kayıt sunucudan çekilmeden `.allKeys` ile yazıldığı için
/// `nil` alan sunucudaki eski değeri silmez (gizlenince eski durum kalırdı).
enum SocialRecordMapping {
    enum RecordType {
        static let identity = "SocialIdentity"
        static let info = "SocialSpaceInfo"
        static let card = "SocialCard"
        static let claim = "SocialClaim"
        static let mail = "SocialMail"
    }

    static let identityZoneName = "social-identity"
    static let infoRecordName = "info"
    static let cardPrefix = "card-"
    static let zonePrefixes = ["friend-", "room-"]
    static let mailboxField = "mailbox"

    private static let noDate = Date(timeIntervalSince1970: 0)

    static func isSocialZone(_ zoneID: CKRecordZone.ID) -> Bool {
        zonePrefixes.contains { zoneID.zoneName.hasPrefix($0) }
    }

    // MARK: Kart

    static func record(_ card: SocialCard, in zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(
            recordType: RecordType.card,
            recordID: CKRecord.ID(recordName: cardPrefix + card.personId, zoneID: zoneID))
        record["personId"] = card.personId
        record["username"] = card.username
        record["state"] = card.presence?.state.rawValue ?? ""
        record["sessionStartedAt"] = card.presence?.sessionStartedAt ?? noDate
        record["stateSince"] = card.presence?.stateSince ?? noDate
        record["todayFocusMs"] = card.presence?.todayFocusMs ?? 0
        record["presenceUpdatedAt"] = card.presence?.updatedAt ?? noDate
        record["expiresAt"] = card.presence?.expiresAt ?? noDate
        record["joinedAt"] = card.joinedAt
        record["leftAt"] = card.leftAt ?? noDate
        record["roomId"] = card.room?.id ?? ""
        record["roomName"] = card.room?.name ?? ""
        record["roomURL"] = card.room?.url.absoluteString ?? ""
        record["roomMemberCount"] = card.room?.memberCount ?? 0
        record["roomFocusingCount"] = card.room?.focusingCount ?? 0
        return record
    }

    /// Kayıt adı ile `personId` uyuşmazsa ya da ad geçersizse kart yok sayılır (içerik başkasından gelir).
    static func card(_ record: CKRecord, currentUserId: String = "") -> SocialCard? {
        guard record.recordType == RecordType.card, let personId = record["personId"] as? String,
              record.recordID.recordName == cardPrefix + personId,
              let rawName = record["username"] as? String,
              case let .valid(username) = SocialCalc.validateUsername(rawName)
        else { return nil }
        return SocialCard(
            personId: personId, username: username, presence: presence(record),
            joinedAt: date(record, "joinedAt") ?? record.creationDate ?? noDate, leftAt: date(record, "leftAt"),
            room: room(record),
            creatorId: record.creatorUserRecordID.map { userId($0.recordName, currentUserId: currentUserId) })
    }

    private static func presence(_ record: CKRecord) -> SocialPresence? {
        guard let state = (record["state"] as? String).flatMap(PresenceState.init(rawValue:)),
              let updatedAt = date(record, "presenceUpdatedAt")
        else { return nil }
        let today = record["todayFocusMs"] as? Double ?? 0
        return SocialPresence(
            state: state, sessionStartedAt: date(record, "sessionStartedAt"), stateSince: date(record, "stateSince"),
            todayFocusMs: today.isFinite ? min(max(0, today), 24 * 3600 * 1000) : 0, updatedAt: updatedAt,
            expiresAt: date(record, "expiresAt"))
    }

    private static func room(_ record: CKRecord) -> SocialCardRoom? {
        guard let id = record["roomId"] as? String, !id.isEmpty,
              let url = (record["roomURL"] as? String).flatMap(URL.init(string:)), SocialInvite.isShareURL(url)
        else { return nil }
        return SocialCardRoom(
            id: id, name: roomName(record["roomName"] as? String), url: url,
            memberCount: max(0, record["roomMemberCount"] as? Int ?? 0),
            focusingCount: max(0, record["roomFocusingCount"] as? Int ?? 0))
    }

    private static func roomName(_ raw: String?) -> String {
        let name = String((raw ?? "").prefix(socialRoomNameMaxLength))
        return name.isEmpty || !SocialContentFilter.isAcceptable(name) ? "Oda" : name
    }

    private static func date(_ record: CKRecord, _ key: String) -> Date? {
        guard let value = record[key] as? Date, value != noDate else { return nil }
        return value
    }

    // MARK: Alan bilgisi

    static func record(_ info: SocialSpaceInfo, in zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(
            recordType: RecordType.info, recordID: CKRecord.ID(recordName: infoRecordName, zoneID: zoneID))
        record["kind"] = info.kind.rawValue
        record["name"] = info.name
        record["toUsername"] = info.toUsername ?? ""
        record["mailId"] = info.mailId ?? ""
        record["createdAt"] = info.createdAt
        return record
    }

    static func info(_ record: CKRecord) -> SocialSpaceInfo? {
        guard record.recordType == RecordType.info,
              let kind = (record["kind"] as? String).flatMap(SocialSpaceKind.init(rawValue:)),
              // Bölge adının öneki ile tür aynı olmalı (bir oda arkadaşlık gibi gösterilemez).
              record.recordID.zoneID.zoneName.hasPrefix(kind.rawValue + "-")
        else { return nil }
        return SocialSpaceInfo(
            kind: kind, name: kind == .room ? roomName(record["name"] as? String) : "",
            toUsername: nonEmpty(record["toUsername"]), mailId: nonEmpty(record["mailId"]),
            createdAt: date(record, "createdAt") ?? record.creationDate ?? noDate)
    }

    private static func nonEmpty(_ value: (any CKRecordValueProtocol)?) -> String? {
        guard let text = value as? String, !text.isEmpty else { return nil }
        return text
    }

    // MARK: Alan

    /// Bölgede herkes her kaydı yazabilir; bu yüzden yalnız oluşturanının son yazdığı kayıtlar geçerlidir ve alan
    /// bilgisi yalnız bölge sahibinden kabul edilir.
    static func isAuthentic(_ record: CKRecord, currentUserId: String) -> Bool {
        let creator = record.creatorUserRecordID.map { userId($0.recordName, currentUserId: currentUserId) }
        let editor = record.lastModifiedUserRecordID.map { userId($0.recordName, currentUserId: currentUserId) }
        guard record.recordType == RecordType.info else { return creator == editor }
        let owner = userId(record.recordID.zoneID.ownerName, currentUserId: currentUserId)
        return creator == editor && (creator == nil || creator == owner)
    }

    /// `records`: bölgenin tüm kayıtları (paylaşım kaydı dahil).
    static func space(
        zoneID: CKRecordZone.ID, isMine: Bool, records: [CKRecord], currentUserId: String
    ) -> SocialSpace? {
        let authentic = records.filter { isAuthentic($0, currentUserId: currentUserId) }
        guard let info = authentic.lazy.compactMap(info).first else { return nil }
        let share = records.lazy.compactMap { $0 as? CKShare }.first
        return SocialSpace(
            id: SocialSpaceID(name: zoneID.zoneName, ownerName: zoneID.ownerName, isMine: isMine), info: info,
            cards: authentic.compactMap { card($0, currentUserId: currentUserId) }.sorted { $0.personId < $1.personId },
            inviteURL: share.flatMap { inviteURL($0, kind: info.kind, isMine: isMine) })
    }

    /// Oda: genel bağlantı. Arkadaşlık: yalnız benimkinde, henüz kullanılmamış tek kullanımlık bağlantı.
    static func inviteURL(_ share: CKShare, kind: SocialSpaceKind, isMine: Bool) -> URL? {
        switch kind {
        case .room: return share.url
        case .friend:
            guard isMine, let pending = share.participants.first(where: {
                $0.role != .owner && $0.acceptanceStatus == .pending
            }) else { return nil }
            // Swift sarmalayıcısı (`oneTimeURL(for:)`) 26'da geldi; aynı genel Objective-C yöntemi iOS 18'den beri var.
            return share.__oneTimeURL(forParticipantID: pending.__participantID)
        }
    }

    // MARK: Kullanıcı adı kaydı

    static func recordID(claimKey: String) -> CKRecord.ID { CKRecord.ID(recordName: claimKey) }

    static func apply(_ claim: SocialClaim, to record: CKRecord) {
        record["publicKey"] = claim.publicKey
        record[mailboxField] = claim.mailbox
        record["acceptsRequests"] = claim.acceptsRequests ? 1 : 0
    }

    /// CloudKit, kendi kayıtlarımın oluşturanını `__defaultOwner__` olarak verir → `currentUserId`.
    static func claim(_ record: CKRecord, currentUserId: String) -> SocialClaim? {
        guard record.recordType == RecordType.claim, let publicKey = record["publicKey"] as? Data,
              let mailbox = record[mailboxField] as? String,
              let creator = record.creatorUserRecordID?.recordName
        else { return nil }
        return SocialClaim(
            key: record.recordID.recordName, ownerId: userId(creator, currentUserId: currentUserId),
            publicKey: publicKey, mailbox: mailbox, acceptsRequests: (record["acceptsRequests"] as? Int ?? 0) == 1)
    }

    static func userId(_ recordName: String, currentUserId: String) -> String {
        recordName == CKCurrentUserDefaultName ? currentUserId : recordName
    }

    // MARK: Mektup

    static func mail(_ record: CKRecord, currentUserId: String) -> SocialMail? {
        guard record.recordType == RecordType.mail, let sealed = record["sealed"] as? Data,
              let creator = record.creatorUserRecordID?.recordName
        else { return nil }
        return SocialMail(
            id: record.recordID.recordName, senderId: userId(creator, currentUserId: currentUserId), sealed: sealed,
            createdAt: record.creationDate ?? noDate)
    }

    // MARK: Hata

    static func error(_ error: any Error) -> SocialCloudError {
        if let known = error as? SocialCloudError { return known }
        guard let ck = error as? CKError else { return .other(String(describing: type(of: error))) }
        switch ck.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy,
             .serverResponseLost, .operationCancelled:
            return .network
        case .notAuthenticated, .accountTemporarilyUnavailable, .managedAccountRestricted:
            return .noAccount
        case .unknownItem, .zoneNotFound, .userDeletedZone:
            return .notFound
        case .permissionFailure, .participantMayNeedVerification:
            return .permission
        case .serverRecordChanged:
            return .conflict
        case .partialFailure:
            // `batchRequestFailed` yalnızca "yanındaki kayıt başarısız oldu" demektir; asıl hatayı al.
            let inner = ck.partialErrorsByItemID?.values.first { ($0 as? CKError)?.code != .batchRequestFailed }
            return inner.map(Self.error) ?? .other("partialFailure")
        default:
            return .other("CKError.\(ck.code.rawValue)")
        }
    }
}
