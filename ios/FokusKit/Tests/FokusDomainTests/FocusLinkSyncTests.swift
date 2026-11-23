import Foundation
import Testing

@testable import FokusDomain

// iPhone ↔ saat kayıt eşlemesi kuralları (`FocusLinkSync.swift`). `now` sabit; `Date()` yok.

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private func at(_ minutes: Double) -> Date { now.addingTimeInterval(minutes * 60) }
private func uuid(_ digit: Character) -> UUID {
    UUID(uuidString: String(repeating: digit, count: 8) + "-1111-4111-8111-111111111111")!
}

@Suite("FocusLink.mergeAction")
struct FocusLinkMergeTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let local: Date?
        let incoming: Date
        let expected: FocusLink.MergeAction
        var testDescription: String { name }
    }

    @Test(arguments: [
        Case(name: "yerelde yok → ekle", local: nil, incoming: at(0), expected: .insert),
        Case(name: "gelen daha yeni → güncelle", local: at(0), incoming: at(1), expected: .update),
        Case(name: "eşit damga (yankı) → atla", local: at(1), incoming: at(1), expected: .skip),
        Case(name: "gelen daha eski (gecikmiş kuyruk) → atla", local: at(2), incoming: at(1), expected: .skip),
    ])
    func merge(_ testCase: Case) {
        #expect(
            FocusLink.mergeAction(localUpdatedAt: testCase.local, incomingUpdatedAt: testCase.incoming)
                == testCase.expected)
    }
}

@Suite("FocusLink.repairs")
struct FocusLinkRepairTests {
    private let watchSession = uuid("a")
    private let phoneSession = uuid("b")

    @Test("tutarlı veride onarım yok")
    func consistent() {
        let repairs = FocusLink.repairs(
            sessions: [.init(id: watchSession, startedAt: at(0), endedAt: nil)],
            segments: [
                .init(id: uuid("1"), sessionId: watchSession, startedAt: at(0), endedAt: at(10)),
                .init(id: uuid("2"), sessionId: watchSession, startedAt: at(10), endedAt: nil),
            ])
        #expect(repairs.isEmpty)
    }

    @Test("bağlantısızken iki cihazda başlatıldı: eski oturum yenisinin başladığı anda kapanır")
    func twoOpenSessions() {
        let repairs = FocusLink.repairs(
            sessions: [
                .init(id: watchSession, startedAt: at(0), endedAt: nil),
                .init(id: phoneSession, startedAt: at(20), endedAt: nil),
            ],
            segments: [
                .init(id: uuid("1"), sessionId: watchSession, startedAt: at(0), endedAt: nil),
                .init(id: uuid("2"), sessionId: phoneSession, startedAt: at(20), endedAt: nil),
            ])
        #expect(repairs.closeSessions == [watchSession: at(20)])
        #expect(repairs.closeSegments == [uuid("1"): at(20)])
    }

    @Test("iki cihazda aynı anda mola: ilk mola ikincinin başladığı anda kapanır, tek açık segment kalır")
    func duplicateBreaks() {
        let repairs = FocusLink.repairs(
            sessions: [.init(id: watchSession, startedAt: at(0), endedAt: nil)],
            segments: [
                .init(id: uuid("1"), sessionId: watchSession, startedAt: at(0), endedAt: at(30)),
                .init(id: uuid("2"), sessionId: watchSession, startedAt: at(30), endedAt: nil),
                .init(id: uuid("3"), sessionId: watchSession, startedAt: at(30.01), endedAt: nil),
            ])
        #expect(repairs.closeSessions.isEmpty)
        #expect(repairs.closeSegments == [uuid("2"): at(30.01)])
    }

    @Test("bitmiş oturumda açık kalan segment oturum bitişinde kapanır")
    func endedSessionOpenSegment() {
        let repairs = FocusLink.repairs(
            sessions: [.init(id: watchSession, startedAt: at(0), endedAt: at(45))],
            segments: [.init(id: uuid("1"), sessionId: watchSession, startedAt: at(0), endedAt: nil)])
        #expect(repairs.closeSegments == [uuid("1"): at(45)])
    }

    @Test("kapanış anı segmentin başlangıcından önce olamaz")
    func neverBeforeStart() {
        let repairs = FocusLink.repairs(
            sessions: [.init(id: watchSession, startedAt: at(0), endedAt: at(5))],
            segments: [.init(id: uuid("1"), sessionId: watchSession, startedAt: at(9), endedAt: nil)])
        #expect(repairs.closeSegments == [uuid("1"): at(9)])
    }

    @Test("eşit başlangıçta id sırası belirleyicidir (iki cihaz aynı sonuca varır)")
    func tieBreak() {
        let sessions: [FocusLink.SessionStub] = [
            .init(id: phoneSession, startedAt: at(0), endedAt: nil),
            .init(id: watchSession, startedAt: at(0), endedAt: nil),
        ]
        let forward = FocusLink.repairs(sessions: sessions, segments: [])
        let reversed = FocusLink.repairs(sessions: sessions.reversed(), segments: [])
        #expect(forward == reversed)
        #expect(forward.closeSessions == [watchSession: at(0)])
    }

    @Test("oturumsuz (sessionId nil) açık segmentler yalnızca kendi aralarında düzelir")
    func orphanSegments() {
        let repairs = FocusLink.repairs(
            sessions: [],
            segments: [
                .init(id: uuid("1"), sessionId: nil, startedAt: at(0), endedAt: nil),
                .init(id: uuid("2"), sessionId: nil, startedAt: at(3), endedAt: nil),
            ])
        #expect(repairs.closeSegments == [uuid("1"): at(3)])
    }
}

@Suite("FocusLink.shouldSend")
struct FocusLinkShouldSendTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let updatedAt: Date
        let startedAt: Date
        let isOpen: Bool
        let lastSent: Date?
        let echo: Date?
        let expected: Bool
        var testDescription: String { name }
    }

    @Test(arguments: [
        Case(
            name: "son gönderimden sonra değişen gider", updatedAt: at(5), startedAt: at(0), isOpen: false,
            lastSent: at(4), echo: nil, expected: true),
        Case(
            name: "son gönderimden önce değişen gitmez", updatedAt: at(3), startedAt: at(0), isOpen: true,
            lastSent: at(4), echo: nil, expected: false),
        Case(
            name: "karşıdan aynen alınan sürüm geri gitmez", updatedAt: at(5), startedAt: at(0), isOpen: false,
            lastSent: at(4), echo: at(5), expected: false),
        Case(
            name: "karşıdan alındıktan sonra burada değişen gider", updatedAt: at(6), startedAt: at(0),
            isOpen: true, lastSent: at(4), echo: at(5), expected: true),
        Case(
            name: "ilk eşleme: pencere içindeki gider", updatedAt: at(-60), startedAt: at(-7 * 24 * 60),
            isOpen: false, lastSent: nil, echo: nil, expected: true),
        Case(
            name: "ilk eşleme: pencere dışındaki gitmez", updatedAt: at(-9 * 24 * 60),
            startedAt: at(-9 * 24 * 60), isOpen: false, lastSent: nil, echo: nil, expected: false),
        Case(
            name: "ilk eşleme: pencere dışında başlamış ama açık olan gider", updatedAt: at(-9 * 24 * 60),
            startedAt: at(-9 * 24 * 60), isOpen: true, lastSent: nil, echo: nil, expected: true),
    ])
    func select(_ testCase: Case) {
        let id = uuid("c")
        let echo = testCase.echo.map { [id: $0] } ?? [:]
        #expect(
            FocusLink.shouldSend(
                id: id, updatedAt: testCase.updatedAt, startedAt: testCase.startedAt, isOpen: testCase.isOpen,
                lastSent: testCase.lastSent, echo: echo, now: now) == testCase.expected)
    }
}

@Suite("FocusLink kayıt taşıma")
struct FocusLinkRecordTransportTests {
    private func session(_ index: Int, subject: UUID? = nil) -> FocusLink.SessionRecord {
        FocusLink.SessionRecord(
            id: UUID(), createdAt: at(Double(index)), updatedAt: at(Double(index)), subjectId: subject,
            startedAt: at(Double(index)))
    }

    private func segment(_ index: Int) -> FocusLink.SegmentRecord {
        FocusLink.SegmentRecord(
            id: UUID(), createdAt: at(Double(index)), updatedAt: at(Double(index)), sessionId: UUID(),
            kind: .break, startedAt: at(Double(index)), endedAt: at(Double(index) + 1))
    }

    @Test("boş küme parçalanmaz")
    func emptyChunks() {
        #expect(FocusLink.chunked(FocusLink.RecordBatch()).isEmpty)
    }

    @Test("sınır altındaki küme tek parça kalır")
    func smallBatch() {
        let batch = FocusLink.RecordBatch(sessions: [session(0)], segments: [segment(1)])
        #expect(FocusLink.chunked(batch, limit: 5) == [batch])
    }

    @Test("büyük küme sınırı aşmayan parçalara bölünür; oturumlar önce, ders adları kendi parçasında")
    func largeBatch() {
        let subject = UUID()
        let sessions = (0..<3).map { session($0, subject: $0 == 2 ? subject : nil) }
        let segments = (0..<4).map { segment($0) }
        let batch = FocusLink.RecordBatch(sessions: sessions, segments: segments, subjectNames: [subject: "TYT Fizik"])
        let parts = FocusLink.chunked(batch, limit: 3)
        #expect(parts.map(\.count) == [3, 3, 1])
        #expect(parts[0].sessions == sessions && parts[0].subjectNames == [subject: "TYT Fizik"])
        #expect(parts[1].subjectNames.isEmpty)
        #expect(parts.flatMap(\.segments) == segments)
    }

    @Test("son güncelleme damgası en yeni kayıttır")
    func latestUpdate() {
        #expect(FocusLink.RecordBatch().latestUpdate == nil)
        let batch = FocusLink.RecordBatch(sessions: [session(2)], segments: [segment(5), segment(1)])
        #expect(batch.latestUpdate == at(5))
    }

    @Test("kayıt kümesi JSON gidiş-dönüşte aynen korunur; yabancı sözlük çözülmez")
    func roundTrip() throws {
        let subject = UUID()
        let batch = FocusLink.RecordBatch(
            sessions: [session(0, subject: subject)], segments: [segment(1)], subjectNames: [subject: "AYT Kimya"])
        #expect(FocusLink.records(from: try #require(FocusLink.payload(batch))) == batch)
        #expect(FocusLink.records(from: [:]) == nil)
        #expect(FocusLink.records(from: [FocusLink.broadcastKey: Data([1])]) == nil)
    }
}
