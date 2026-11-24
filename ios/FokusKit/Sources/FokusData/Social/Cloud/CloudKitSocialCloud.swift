import CloudKit
import FokusDomain
import Foundation

/// `SocialCloud`'un CloudKit köprüsü: private bölgeler + `CKShare` (arkadaşlık/oda) ve public kullanıcı adı
/// dizini + şifreli posta kutusu. Kural içermez (docs/social-cloudkit.md).
public actor CloudKitSocialCloud: SocialCloud {
    private typealias Mapping = SocialRecordMapping

    private struct ZoneCache {
        var token: CKServerChangeToken?
        var records: [CKRecord.ID: CKRecord] = [:]
    }

    private static let mailQueryLimit = 200
    private static let acceptRetryCount = 4

    private let containerIdentifier: String
    private var storedContainer: CKContainer?
    private var currentUserId: String?
    private var caches: [CKDatabase.Scope: [CKRecordZone.ID: ZoneCache]] = [:]

    public init(containerIdentifier: String) { self.containerIdentifier = containerIdentifier }

    /// Tembel: yetkisiz (imzasız simülatör) derlemede `CKContainer` hiç kurulmaz.
    private var container: CKContainer {
        if let storedContainer { return storedContainer }
        let created = CKContainer(identifier: containerIdentifier)
        storedContainer = created
        return created
    }

    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    // MARK: - Hesap

    public func account() async throws -> SocialCloudAccount {
        #if targetEnvironment(simulator)
        guard FileManager.default.ubiquityIdentityToken != nil else { return .unavailable }
        #endif
        return try await mapped {
            switch try await container.accountStatus() {
            case .available:
                let userId = try await container.userRecordID().recordName
                if userId != currentUserId { caches = [:] }
                currentUserId = userId
                return .available(userId: userId)
            case .noAccount, .restricted:
                return .unavailable
            case .couldNotDetermine, .temporarilyUnavailable:
                throw SocialCloudError.network
            @unknown default:
                throw SocialCloudError.network
            }
        }
    }

    private func requireUserId() async throws -> String {
        if let currentUserId { return currentUserId }
        guard case let .available(userId) = try await account() else { throw SocialCloudError.noAccount }
        return userId
    }

    // MARK: - Kimlik

    private var identityID: CKRecord.ID {
        CKRecord.ID(recordName: "identity", zoneID: CKRecordZone.ID(zoneName: Mapping.identityZoneName))
    }

    public func loadIdentity() async throws -> SocialIdentity? {
        do {
            let record = try await privateDB.record(for: identityID)
            guard let payload = record["payload"] as? Data else { return nil }
            return try JSONDecoder().decode(SocialIdentity.self, from: payload)
        } catch {
            if Mapping.error(error) == .notFound { return nil }
            throw Mapping.error(error)
        }
    }

    public func saveIdentity(_ identity: SocialIdentity) async throws {
        try await mapped {
            let record = CKRecord(recordType: Mapping.RecordType.identity, recordID: identityID)
            record["payload"] = try JSONEncoder().encode(identity)
            do {
                try await save([record], in: privateDB)
            } catch SocialCloudError.notFound {
                _ = try await privateDB.save(CKRecordZone(zoneID: identityID.zoneID))
                try await save([record], in: privateDB)
            }
        }
    }

    public func deleteIdentity() async throws {
        try await ignoringMissing { _ = try await privateDB.deleteRecordZone(withID: identityID.zoneID) }
    }

    // MARK: - Kullanıcı adı

    public func claim(forKey key: String) async throws -> SocialClaim? {
        let userId = try await requireUserId()
        do {
            let record = try await publicDB.record(for: Mapping.recordID(claimKey: key))
            return Mapping.claim(record, currentUserId: userId)
        } catch {
            if Mapping.error(error) == .notFound { return nil }
            throw Mapping.error(error)
        }
    }

    public func createClaim(_ claim: SocialClaim) async throws {
        let record = CKRecord(recordType: Mapping.RecordType.claim, recordID: Mapping.recordID(claimKey: claim.key))
        Mapping.apply(claim, to: record)
        try await save([record], in: publicDB, policy: .ifServerRecordUnchanged)
    }

    public func updateClaim(_ claim: SocialClaim) async throws {
        try await mapped {
            let record = try await publicDB.record(for: Mapping.recordID(claimKey: claim.key))
            Mapping.apply(claim, to: record)
            try await save([record], in: publicDB, policy: .ifServerRecordUnchanged)
        }
    }

    public func deleteClaim(key: String) async throws {
        try await ignoringMissing { _ = try await publicDB.deleteRecord(withID: Mapping.recordID(claimKey: key)) }
    }

    // MARK: - Mektup

    public func sendMail(id: String, mailbox: String, sealed: Data) async throws {
        let record = CKRecord(recordType: Mapping.RecordType.mail, recordID: CKRecord.ID(recordName: id))
        record[Mapping.mailboxField] = mailbox
        record["sealed"] = sealed
        try await save([record], in: publicDB, policy: .ifServerRecordUnchanged)
    }

    public func mail(in mailbox: String) async throws -> [SocialMail] {
        let userId = try await requireUserId()
        return try await mapped {
            let query = CKQuery(
                recordType: Mapping.RecordType.mail,
                predicate: NSPredicate(format: "%K == %@", Mapping.mailboxField, mailbox))
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: Self.mailQueryLimit)
            return results.compactMap { _, result in
                (try? result.get()).flatMap { Mapping.mail($0, currentUserId: userId) }
            }
            .sorted { $0.createdAt > $1.createdAt }
        }
    }

    public func deleteMail(id: String) async throws {
        try await ignoringMissing { _ = try await publicDB.deleteRecord(withID: CKRecord.ID(recordName: id)) }
    }

    // MARK: - Alanlar

    public func createSpace(name: String, info: SocialSpaceInfo, card: SocialCard) async throws -> SocialSpace {
        let zoneID = CKRecordZone.ID(zoneName: name)
        let userId = try await requireUserId()
        return try await mapped {
            _ = try await privateDB.save(CKRecordZone(zoneID: zoneID))
            do {
                let share = makeShare(zoneID: zoneID, info: info)
                let records = [Mapping.record(info, in: zoneID), Mapping.record(card, in: zoneID)]
                let saved = try await save(records + [share], in: privateDB, atomically: true)
                guard let space = Mapping.space(zoneID: zoneID, isMine: true, records: saved, currentUserId: userId),
                      space.inviteURL != nil
                else {
                    throw SocialCloudError.other("share")
                }
                return space
            } catch {
                // Yarım kalan bölge kalmasın; silinemezse `spaces()` bilgisiz bölgeyi zaten yok sayar.
                _ = try? await privateDB.deleteRecordZone(withID: zoneID)
                throw error
            }
        }
    }

    private func makeShare(zoneID: CKRecordZone.ID, info: SocialSpaceInfo) -> CKShare {
        let share = CKShare(recordZoneID: zoneID)
        switch info.kind {
        case .friend:
            share[CKShare.SystemFieldKey.title] = "Fokus arkadaşlık daveti"
            share.publicPermission = .none
            let guest = CKShare.Participant.oneTimeURLParticipant()
            guest.permission = .readWrite
            share.addParticipant(guest)
        case .room:
            share[CKShare.SystemFieldKey.title] = "Fokus odası: \(info.name)"
            share.publicPermission = .readWrite
        }
        return share
    }

    public func spaces() async throws -> [SocialSpace] {
        try await mapped {
            let mine = try await spaces(in: privateDB, isMine: true)
            let shared = try await spaces(in: sharedDB, isMine: false)
            return (mine + shared).sorted { $0.id.name < $1.id.name }
        }
    }

    private func spaces(in database: CKDatabase, isMine: Bool) async throws -> [SocialSpace] {
        let userId = try await requireUserId()
        let zoneIDs = try await database.allRecordZones().map(\.zoneID).filter(Mapping.isSocialZone)
        let scope = database.databaseScope
        caches[scope] = (caches[scope] ?? [:]).filter { zoneIDs.contains($0.key) }
        try await fetchChanges(zoneIDs, in: database)
        return zoneIDs.compactMap { zoneID in
            guard let cache = caches[scope]?[zoneID] else { return nil }
            return Mapping.space(
                zoneID: zoneID, isMine: isMine, records: Array(cache.records.values), currentUserId: userId)
        }
    }

    /// Bölgelerin değişikliklerini tek işlemde, artımlı çeker.
    private func fetchChanges(_ zoneIDs: [CKRecordZone.ID], in database: CKDatabase) async throws {
        guard !zoneIDs.isEmpty else { return }
        let scope = database.databaseScope
        var pending = zoneIDs
        // İkinci tur yalnızca değişiklik belirteci eskimiş bölgeler içindir.
        for _ in 0..<2 where !pending.isEmpty {
            let tokens = pending.reduce(into: [CKRecordZone.ID: CKServerChangeToken]()) {
                $0[$1] = caches[scope]?[$1]?.token
            }
            let changes = try await ZoneChanges.fetch(pending, tokens: tokens, in: database)
            pending = changes.expired
            for zoneID in changes.expired { caches[scope]?[zoneID] = nil }
            for (zoneID, change) in changes.zones {
                var cache = caches[scope]?[zoneID] ?? ZoneCache()
                for record in change.changed { cache.records[record.recordID] = record }
                for recordID in change.deleted { cache.records[recordID] = nil }
                // Kaydı okunamayan bölge bir sonraki seferde aynı yerden yeniden çekilir.
                if !change.hasFailure { cache.token = change.token ?? cache.token }
                caches[scope, default: [:]][zoneID] = cache
            }
        }
    }

    public func updateInfo(_ info: SocialSpaceInfo, in space: SocialSpaceID) async throws {
        try await save([Mapping.record(info, in: zoneID(space))], in: database(space))
    }

    public func saveCards(_ cards: [SocialSpaceID: SocialCard]) async throws {
        for isMine in [true, false] {
            let records = cards.filter { $0.key.isMine == isMine }.map { Mapping.record($0.value, in: zoneID($0.key)) }
            guard !records.isEmpty else { continue }
            try await mapped {
                let results = try await (isMine ? privateDB : sharedDB)
                    .modifyRecords(saving: records, deleting: [], savePolicy: .allKeys, atomically: false)
                for case let .failure(error) in results.saveResults.values {
                    switch Mapping.error(error) {
                    case .notFound, .permission: continue  // Alan bu arada kapanmış ya da çıkarılmışım.
                    default: throw error
                    }
                }
            }
        }
    }

    public func acceptInvite(_ invite: SocialInvite) async throws -> SocialSpace {
        try await mapped {
            let metadata: CKShare.Metadata = switch invite.source {
            case let .url(url): try await container.shareMetadata(for: url)
            case let .metadata(metadata): metadata
            }
            guard metadata.containerIdentifier == containerIdentifier else { throw SocialCloudError.notFound }
            if metadata.participantRole == .owner { throw SocialCloudError.ownInvite }
            if metadata.participantStatus != .accepted { _ = try await container.accept(metadata) }
            return try await loadAccepted(metadata.share.recordID.zoneID)
        }
    }

    /// Kabulden hemen sonra bölge paylaşılan veritabanında birkaç saniye gecikebilir. Fokus alanı olmayan bir
    /// paylaşımdan hemen ayrılınır.
    private func loadAccepted(_ zoneID: CKRecordZone.ID) async throws -> SocialSpace {
        let userId = try await requireUserId()
        var records: [CKRecord] = []
        for attempt in 0..<Self.acceptRetryCount {
            if attempt > 0 { try await Task.sleep(for: .seconds(attempt)) }
            do {
                try await fetchChanges([zoneID], in: sharedDB)
            } catch where Mapping.error(error) == .notFound {
                continue
            }
            records = caches[.shared]?[zoneID].map { Array($0.records.values) } ?? []
            if let space = Mapping.space(zoneID: zoneID, isMine: false, records: records, currentUserId: userId) {
                return space
            }
        }
        guard !records.isEmpty else { throw SocialCloudError.network }
        try await leave(zoneID)
        throw SocialCloudError.notFound
    }

    public func removeSpace(_ id: SocialSpaceID) async throws {
        let zoneID = zoneID(id)
        if id.isMine { try await deleteOwnZone(zoneID) } else { try await leave(zoneID) }
    }

    public func removeAllSpaces() async throws {
        let (mine, shared) = try await mapped {
            (try await privateDB.allRecordZones(), try await sharedDB.allRecordZones())
        }
        for zoneID in mine.map(\.zoneID) where Mapping.isSocialZone(zoneID) { try await deleteOwnZone(zoneID) }
        for zoneID in shared.map(\.zoneID) where Mapping.isSocialZone(zoneID) { try await leave(zoneID) }
    }

    private func deleteOwnZone(_ zoneID: CKRecordZone.ID) async throws {
        try await ignoringMissing { _ = try await privateDB.deleteRecordZone(withID: zoneID) }
        caches[.private]?[zoneID] = nil
    }

    /// Katılımcı paylaşım kaydını silince yalnız kendisi ayrılır; sunucu izin vermezse paylaşılan bölge silinir
    /// (katılımcı için aynı anlama gelir).
    private func leave(_ zoneID: CKRecordZone.ID) async throws {
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        try await ignoringMissing {
            do {
                _ = try await sharedDB.deleteRecord(withID: shareID)
            } catch where Mapping.error(error) == .permission {
                _ = try await sharedDB.deleteRecordZone(withID: zoneID)
            }
        }
        caches[.shared]?[zoneID] = nil
    }

    private func zoneID(_ id: SocialSpaceID) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: id.name, ownerName: id.ownerName)
    }

    private func database(_ id: SocialSpaceID) -> CKDatabase { id.isMine ? privateDB : sharedDB }

    // MARK: - Yardımcılar

    @discardableResult
    private func save(
        _ records: [CKRecord], in database: CKDatabase, policy: CKModifyRecordsOperation.RecordSavePolicy = .allKeys,
        atomically: Bool = false
    ) async throws -> [CKRecord] {
        try await mapped {
            let results = try await database.modifyRecords(
                saving: records, deleting: [], savePolicy: policy, atomically: atomically)
            return try results.saveResults.values.map { try $0.get() }
        }
    }

    private func mapped<T>(_ body: () async throws -> T) async throws -> T {
        do { return try await body() } catch { throw Mapping.error(error) }
    }

    private func ignoringMissing(_ body: () async throws -> Void) async throws {
        do { try await body() } catch {
            let mappedError = Mapping.error(error)
            if mappedError != .notFound { throw mappedError }
        }
    }
}

/// `CKFetchRecordZoneChangesOperation`'ın çok bölgeli, async sarmalayıcısı.
private final class ZoneChanges: @unchecked Sendable {
    struct Zone {
        var changed: [CKRecord] = []
        var deleted: [CKRecord.ID] = []
        var token: CKServerChangeToken?
        var hasFailure = false
    }

    struct Result: Sendable {
        var zones: [CKRecordZone.ID: Zone] = [:]
        var expired: [CKRecordZone.ID] = []
    }

    private let lock = NSLock()
    private var result = Result()
    private var failure: (any Error)?

    private func update(_ body: (ZoneChanges) -> Void) { lock.withLock { body(self) } }

    static func fetch(
        _ zoneIDs: [CKRecordZone.ID], tokens: [CKRecordZone.ID: CKServerChangeToken], in database: CKDatabase
    ) async throws -> Result {
        let box = ZoneChanges()
        let configurations = Dictionary(uniqueKeysWithValues: zoneIDs.map { zoneID in
            let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            configuration.previousServerChangeToken = tokens[zoneID]
            return (zoneID, configuration)
        })
        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: zoneIDs, configurationsByRecordZoneID: configurations)
        operation.qualityOfService = .userInitiated
        operation.recordWasChangedBlock = { recordID, result in
            box.update { box in
                switch result {
                case let .success(record): box.result.zones[recordID.zoneID, default: Zone()].changed.append(record)
                case .failure: box.result.zones[recordID.zoneID, default: Zone()].hasFailure = true
                }
            }
        }
        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            box.update { $0.result.zones[recordID.zoneID, default: Zone()].deleted.append(recordID) }
        }
        operation.recordZoneFetchResultBlock = { zoneID, result in
            box.update { box in
                switch result {
                case let .success(value): box.result.zones[zoneID, default: Zone()].token = value.serverChangeToken
                case let .failure(error): box.record(error, zoneID)
                }
            }
        }
        return try await withCheckedThrowingContinuation { continuation in
            operation.fetchRecordZoneChangesResultBlock = { result in
                box.update { box in
                    if let failure = box.failure {
                        continuation.resume(throwing: failure)
                    } else if case let .failure(error) = result, (error as? CKError)?.code != .partialFailure {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: box.result)
                    }
                }
            }
            database.add(operation)
        }
    }

    /// Kilit tutulurken çağrılır. Silinmiş bölge atlanır; tek bölgelik istekte hata yukarı verilir.
    private func record(_ error: any Error, _ zoneID: CKRecordZone.ID) {
        switch (error as? CKError)?.code {
        case .changeTokenExpired:
            result.zones[zoneID] = nil
            result.expired.append(zoneID)
        case .zoneNotFound, .userDeletedZone, .unknownItem:
            result.zones[zoneID] = nil
        default:
            failure = error
        }
    }
}
