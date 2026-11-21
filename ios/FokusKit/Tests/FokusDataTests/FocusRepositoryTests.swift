import FokusDomain
import Foundation
import SwiftData
import Testing

@testable import FokusData

// Odak yazma akışı — web `focusActions.test.ts` vakaları.

@MainActor
struct FocusRepositoryTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let context: ModelContext
    private let repository: FocusRepository

    init() throws {
        context = ModelContext(try FokusStore.makeInMemoryContainer())
        repository = FocusRepository(context: context)
    }

    private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

    @Test func startCreatesSessionWithOpenFocusSegment() throws {
        let session = try repository.start(now: t0)
        #expect(session.startedAt == t0 && session.endedAt == nil)
        let segments = try repository.segments(forSession: session.id)
        #expect(segments.count == 1)
        #expect(segments[0].kind == .focus && segments[0].startedAt == t0 && segments[0].endedAt == nil)
        #expect(try repository.findActive()?.id == session.id)
    }

    @Test func startKeepsSubjectAndTopicButDropsTopicWithoutSubject() throws {
        let subjectId = UUID()
        let topicId = UUID()
        let withSubject = try repository.start(subjectId: subjectId, topicId: topicId, now: t0)
        #expect(withSubject.subjectId == subjectId && withSubject.topicId == topicId)
        try repository.finish(sessionId: withSubject.id, now: at(1))
        let noSubject = try repository.start(subjectId: nil, topicId: topicId, now: at(2))
        #expect(noSubject.subjectId == nil && noSubject.topicId == nil)
    }

    @Test func secondStartReturnsExistingActiveSession() throws {
        let first = try repository.start(now: t0)
        let second = try repository.start(now: at(5))
        #expect(second.id == first.id)
        #expect(try EntityStore<FocusSession>(context: context).all().count == 1)
        #expect(try repository.segments(forSession: first.id).count == 1)
    }

    @Test func pauseClosesFocusAndOpensBreakAtSameInstant() throws {
        let session = try repository.start(now: t0)
        try repository.pause(sessionId: session.id, now: at(25))
        let segments = try repository.segments(forSession: session.id)
        #expect(segments.map(\.kind) == [.focus, .break])
        #expect(segments[0].endedAt == at(25) && segments[1].startedAt == at(25) && segments[1].endedAt == nil)
    }

    @Test func pauseWhileOnBreakAndResumeWhileFocusingAreNoOps() throws {
        let session = try repository.start(now: t0)
        try repository.resume(sessionId: session.id, now: at(1))
        #expect(try repository.segments(forSession: session.id).count == 1)
        try repository.pause(sessionId: session.id, now: at(2))
        try repository.pause(sessionId: session.id, now: at(3))
        #expect(try repository.segments(forSession: session.id).count == 2)
    }

    @Test func resumeOpensNewFocusSegment() throws {
        let session = try repository.start(now: t0)
        try repository.pause(sessionId: session.id, now: at(25))
        try repository.resume(sessionId: session.id, now: at(30))
        let segments = try repository.segments(forSession: session.id)
        #expect(segments.map(\.kind) == [.focus, .break, .focus])
        #expect(segments[1].endedAt == at(30) && segments[2].startedAt == at(30))
        let phase = FocusCalc.focusPhase(session: session.snapshot, segments: segments.map(\.snapshot))
        #expect(phase == .focus)
    }

    @Test func finishClosesOpenSegmentAndReturnsStats() throws {
        let session = try repository.start(now: t0)
        try repository.pause(sessionId: session.id, now: at(25))
        try repository.resume(sessionId: session.id, now: at(30))
        let stats = try #require(try repository.finish(sessionId: session.id, now: at(50)))
        #expect(session.endedAt == at(50))
        #expect(try repository.findActive() == nil)
        #expect(stats.focusMs == 45 * 60 * 1000 && stats.breakMs == 5 * 60 * 1000)
        #expect(stats.breakCount == 1 && stats.focusCount == 2)
        #expect(try repository.segments(forSession: session.id).allSatisfy { $0.endedAt != nil })
    }

    @Test func finishIsIdempotentAndKeepsOriginalEnd() throws {
        let session = try repository.start(now: t0)
        try repository.finish(sessionId: session.id, now: at(10))
        let again = try repository.finish(sessionId: session.id, now: at(99))
        #expect(session.endedAt == at(10))
        #expect(again?.focusMs == Double(10 * 60 * 1000))
    }

    @Test func finishUnknownSessionReturnsNil() throws {
        #expect(try repository.finish(sessionId: UUID(), now: t0) == nil)
    }

    @Test func actionsOnFinishedSessionDoNothing() throws {
        let session = try repository.start(now: t0)
        try repository.finish(sessionId: session.id, now: at(10))
        try repository.pause(sessionId: session.id, now: at(11))
        try repository.resume(sessionId: session.id, now: at(12))
        #expect(try repository.segments(forSession: session.id).count == 1)
    }

    @Test func softDeletedSessionIsNotActive() throws {
        let session = try repository.start(now: t0)
        EntityStore<FocusSession>(context: context).softDelete(session, now: at(1))
        #expect(try repository.findActive() == nil)
        #expect(try repository.start(now: at(2)).id != session.id)
    }

    @Test func findActivePicksLatestWhenDuplicatesExist() throws {
        let store = EntityStore<FocusSession>(context: context)
        store.insert(FocusSession(startedAt: at(0)), now: at(0))
        let latest = store.insert(FocusSession(startedAt: at(10)), now: at(10))
        try store.save()
        #expect(try repository.findActive()?.id == latest.id)
    }

    @Test func segmentsAreScopedToSessionAndOrdered() throws {
        let first = try repository.start(now: t0)
        try repository.finish(sessionId: first.id, now: at(5))
        let second = try repository.start(now: at(10))
        try repository.pause(sessionId: second.id, now: at(20))
        #expect(try repository.segments(forSession: first.id).count == 1)
        let secondSegments = try repository.segments(forSession: second.id)
        #expect(secondSegments.map(\.startedAt) == [at(10), at(20)])
    }
}
