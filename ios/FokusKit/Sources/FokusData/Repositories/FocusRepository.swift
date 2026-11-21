import FokusDomain
import Foundation
import SwiftData

/// Odak oturumu yazma işlemleri (web `features/focus/focusActions.ts` karşılığı). Sahibi: focus modülü.
///
/// Durum yalnızca depoda yaşar (sayaç değeri saklanmaz); süreler her zaman segment zaman
/// damgalarından hesaplanır (`FocusCalc`). Uygulama kapanıp açılınca açık oturum kaldığı yerden sürer.
///
/// Değişmezler: aynı anda en fazla bir açık oturum; açık oturumda en fazla bir açık segment;
/// mola/devam geçişinde eski segment `now` anında kapanır, yenisi aynı `now` anında açılır.
@MainActor
public struct FocusRepository {
    private let sessions: EntityStore<FocusSession>
    private let segments: EntityStore<FocusSegment>

    public init(context: ModelContext) {
        sessions = EntityStore(context: context)
        segments = EntityStore(context: context)
    }

    // MARK: - Okuma

    /// Açık (`endedAt == nil`) oturum; birden fazlaysa (iki cihazda eşzamanlı başlatma) en son başlayanı.
    public func findActive() throws -> FocusSession? {
        try sessions.all()
            .filter { $0.endedAt == nil }
            .max { $0.startedAt < $1.startedAt }
    }

    /// Oturumun silinmemiş segmentleri (başlangıca göre artan).
    public func segments(forSession sessionId: UUID) throws -> [FocusSegment] {
        let descriptor = FetchDescriptor<FocusSegment>(
            predicate: #Predicate { $0.sessionId == sessionId },
            sortBy: [SortDescriptor(\.startedAt)])
        let fetched = try segments.context.fetch(descriptor).filter(\.isLive)
        return EntityStore<FocusSegment>.deduplicated(fetched)
    }

    // MARK: - Yazma

    /// Yeni oturum + açık odak segmenti. Zaten açık oturum varsa onu döndürür (iki açık oturum olmaz).
    /// Ders seçilmediyse konu da yok sayılır.
    @discardableResult
    public func start(subjectId: UUID? = nil, topicId: UUID? = nil, now: Date = .now) throws -> FocusSession {
        if let active = try findActive() { return active }
        let session = sessions.insert(
            FocusSession(subjectId: subjectId, topicId: subjectId == nil ? nil : topicId, startedAt: now),
            now: now)
        segments.insert(FocusSegment(sessionId: session.id, kind: .focus, startedAt: now), now: now)
        try sessions.save()
        return session
    }

    /// Odaktan molaya geçer. Zaten moladaysa ya da oturum kapalıysa bir şey yapmaz.
    public func pause(sessionId: UUID, now: Date = .now) throws {
        try switchSegment(sessionId: sessionId, to: .break, now: now)
    }

    /// Moladan odağa döner. Zaten odaktaysa ya da oturum kapalıysa bir şey yapmaz.
    public func resume(sessionId: UUID, now: Date = .now) throws {
        try switchSegment(sessionId: sessionId, to: .focus, now: now)
    }

    /// Açık segmenti kapatır, sonra oturumun `endedAt` alanını set eder ve oturumun istatistiğini
    /// döndürür. Oturum yoksa `nil`; zaten bitmişse olduğu gibi (yeniden yazmadan) istatistik döner.
    @discardableResult
    public func finish(sessionId: UUID, now: Date = .now) throws -> FocusCalc.FocusSessionStats? {
        guard let session = try sessions.find(id: sessionId) else { return nil }
        if session.endedAt == nil {
            try closeOpenSegments(sessionId: sessionId, at: now)
            session.endedAt = now
            sessions.touch(session, now: now)
            try sessions.save()
        }
        return FocusCalc.computeSessionStats(try segments(forSession: sessionId).map(\.snapshot), now: now)
    }

    // MARK: - İç

    private func switchSegment(sessionId: UUID, to kind: FocusSegmentKind, now: Date) throws {
        guard let session = try sessions.find(id: sessionId), session.endedAt == nil else { return }
        let current = try segments(forSession: sessionId)
        if FocusCalc.findOpenSegment(current.map(\.snapshot))?.kind == kind { return }
        try closeOpenSegments(sessionId: sessionId, at: now, existing: current)
        segments.insert(FocusSegment(sessionId: sessionId, kind: kind, startedAt: now), now: now)
        try segments.save()
    }

    /// Açık segmentlerin hepsini kapatır (tutarsız veride birden fazla olabilir).
    private func closeOpenSegments(sessionId: UUID, at now: Date, existing: [FocusSegment]? = nil) throws {
        let all = try existing ?? segments(forSession: sessionId)
        for segment in all where segment.endedAt == nil {
            segment.endedAt = now
            segments.touch(segment, now: now)
        }
    }
}
