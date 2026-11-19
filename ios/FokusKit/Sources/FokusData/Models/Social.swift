import FokusDomain
import Foundation
import SwiftData

/// Arkadaş (web `Friend`) — kendi arkadaş listemin private DB önbelleği. TASLAK (docs 4.7).
@Model
public final class Friend: SyncedEntity {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var deletedAt: Date?

    public var remoteUserId: String = ""
    public var displayName: String = ""
    public var statusRaw: String = "pending"

    public init(id: UUID = UUID(), remoteUserId: String, displayName: String, status: FriendStatus) {
        self.id = id
        self.remoteUserId = remoteUserId
        self.displayName = displayName
        self.statusRaw = status.rawValue
    }

    public var status: FriendStatus {
        get { FriendStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}

/// Odak odası (web `Room`) — yerel önbellek. Gerçek oda CloudKit paylaşılan bölgesinde
/// tutulacak (docs 4.7); bu model yalnızca şema eşliği ve önbellek içindir. TASLAK.
@Model
public final class Room: SyncedEntity {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var deletedAt: Date?

    public var name: String = ""
    public var hostUserId: String = ""
    public var memberUserIds: [String] = []
    public var inviteCode: String = ""
    public var startedAt: Date?
    public var endedAt: Date?

    public init(
        id: UUID = UUID(), name: String, hostUserId: String, memberUserIds: [String] = [],
        inviteCode: String, startedAt: Date? = nil, endedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.hostUserId = hostUserId
        self.memberUserIds = memberUserIds
        self.inviteCode = inviteCode
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}
