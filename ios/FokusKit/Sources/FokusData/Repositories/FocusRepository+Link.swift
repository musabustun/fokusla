import FokusDomain
import Foundation
import SwiftData

/// iPhone ↔ saat kayıt eşlemesinin depo tarafı (odak modülü; `FocusRepository`'nin yanında, yalnızca
/// ekleme). Kurallar `FocusLink` içinde saftır; burası yalnızca okur/yazar.
@MainActor
public struct FocusLinkRepository {
    private let sessions: EntityStore<FocusSession>
    private let segments: EntityStore<FocusSegment>

    public init(context: ModelContext) {
        sessions = EntityStore(context: context)
        segments = EntityStore(context: context)
    }

    /// Karşı cihazdan gelen kayıtları `id` ile idempotent yazar (zaman damgaları KORUNUR — gönderenin
    /// `createdAt`/`updatedAt`'i aynen kalır, böylece aynı kayıt iki kez gelse de sonuç değişmez), sonra
    /// değişmezleri onarır ve kaydeder. Uygulanan kayıt sayısını döndürür (0 → hiçbir şey değişmedi).
    @discardableResult
    public func apply(_ batch: FocusLink.RecordBatch, now: Date = .now) throws -> Int {
        var applied = 0
        let localSessions = Dictionary(
            try sessions.all(includeDeleted: true).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for record in batch.sessions {
            let local = localSessions[record.id]
            switch FocusLink.mergeAction(localUpdatedAt: local?.updatedAt, incomingUpdatedAt: record.updatedAt) {
            case .skip: continue
            case .insert:
                let session = FocusSession(id: record.id, startedAt: record.startedAt)
                sessions.context.insert(session)
                Self.copy(record, into: session)
            case .update:
                if let local { Self.copy(record, into: local) }
            }
            applied += 1
        }
        let localSegments = Dictionary(
            try segments.all(includeDeleted: true).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for record in batch.segments {
            let local = localSegments[record.id]
            switch FocusLink.mergeAction(localUpdatedAt: local?.updatedAt, incomingUpdatedAt: record.updatedAt) {
            case .skip: continue
            case .insert:
                let segment = FocusSegment(id: record.id, sessionId: record.sessionId, kind: record.kind)
                segments.context.insert(segment)
                Self.copy(record, into: segment)
            case .update:
                if let local { Self.copy(record, into: local) }
            }
            applied += 1
        }
        if applied > 0 {
            try repairInvariants(now: now)
            try sessions.save()
        }
        return applied
    }

    /// "Tek açık oturum, oturumda tek açık segment" değişmezini geri kurar (`FocusLink.repairs`).
    /// Kapatılan kayıtların `updatedAt`'i `now` olur ki onarım karşı cihaza da gitsin. Kaydetmez.
    @discardableResult
    public func repairInvariants(now: Date = .now) throws -> Int {
        let liveSessions = try sessions.all()
        let liveSegments = try segments.all()
        let repairs = FocusLink.repairs(
            sessions: liveSessions.map { .init(id: $0.id, startedAt: $0.startedAt, endedAt: $0.endedAt) },
            segments: liveSegments.map {
                .init(id: $0.id, sessionId: $0.sessionId, startedAt: $0.startedAt, endedAt: $0.endedAt)
            })
        for session in liveSessions {
            guard let end = repairs.closeSessions[session.id] else { continue }
            session.endedAt = end
            sessions.touch(session, now: now)
        }
        for segment in liveSegments {
            guard let end = repairs.closeSegments[segment.id] else { continue }
            segment.endedAt = end
            segments.touch(segment, now: now)
        }
        return repairs.closeSessions.count + repairs.closeSegments.count
    }

    /// Karşıya gönderilecek kayıtlar (`FocusLink.shouldSend`; silinmişler — tombstone — de gider).
    /// `subjectNames`: oturumların ders adları (saatteki gösterim önbelleği için).
    public func outgoing(
        lastSent: Date?, echo: [UUID: Date], subjectNames: [UUID: String] = [:], now: Date = .now
    ) throws -> FocusLink.RecordBatch {
        let sessionsToSend = try sessions.all(includeDeleted: true).filter {
            FocusLink.shouldSend(
                id: $0.id, updatedAt: $0.updatedAt, startedAt: $0.startedAt, isOpen: $0.endedAt == nil,
                lastSent: lastSent, echo: echo, now: now)
        }
        let segmentsToSend = try segments.all(includeDeleted: true).filter {
            FocusLink.shouldSend(
                id: $0.id, updatedAt: $0.updatedAt, startedAt: $0.startedAt, isOpen: $0.endedAt == nil,
                lastSent: lastSent, echo: echo, now: now)
        }
        let usedSubjects = Set(sessionsToSend.compactMap(\.subjectId))
        return FocusLink.RecordBatch(
            sessions: sessionsToSend.map(\.linkRecord), segments: segmentsToSend.map(\.linkRecord),
            subjectNames: subjectNames.filter { usedSubjects.contains($0.key) })
    }

    private static func copy(_ record: FocusLink.SessionRecord, into session: FocusSession) {
        session.createdAt = record.createdAt
        session.updatedAt = record.updatedAt
        session.deletedAt = record.deletedAt
        session.subjectId = record.subjectId
        session.topicId = record.topicId
        session.startedAt = record.startedAt
        session.endedAt = record.endedAt
        session.note = record.note
    }

    private static func copy(_ record: FocusLink.SegmentRecord, into segment: FocusSegment) {
        segment.createdAt = record.createdAt
        segment.updatedAt = record.updatedAt
        segment.deletedAt = record.deletedAt
        segment.sessionId = record.sessionId
        segment.kind = record.kind
        segment.startedAt = record.startedAt
        segment.endedAt = record.endedAt
    }
}

extension FocusSession {
    /// Eşleme için tam değer kopyası.
    public var linkRecord: FocusLink.SessionRecord {
        FocusLink.SessionRecord(
            id: id, createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt, subjectId: subjectId,
            topicId: topicId, startedAt: startedAt, endedAt: endedAt, note: note)
    }
}

extension FocusSegment {
    /// Eşleme için tam değer kopyası.
    public var linkRecord: FocusLink.SegmentRecord {
        FocusLink.SegmentRecord(
            id: id, createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt, sessionId: sessionId,
            kind: kind, startedAt: startedAt, endedAt: endedAt)
    }
}
