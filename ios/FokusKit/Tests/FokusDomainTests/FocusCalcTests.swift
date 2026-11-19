import Foundation
import Testing

@testable import FokusDomain

// Odak hesapları testleri — web `web/src/domain/calc/focus.test.ts` ile birebir aynı vakalar
// (aynı adlar, aynı girdi/çıktı değerleri). Web'de `process.env.TZ` ile sabitlenen saat dilimi
// burada `Calendar(identifier: .gregorian)` + `TimeZone(identifier:)` ile verilir.
// Web dize id'leri (`session-1`) deterministik UUID v5'e çevrilir.

// MARK: - Yardımcılar

private let min = 60.0 * 1000
private let hour = 60 * min
private let deletedAt = "2026-11-19T12:00:00.000Z"
private let sessionName = "session-1"

private let testNamespace = UUID(uuidString: "6f1c1e0a-7a53-4b6e-9a53-1d2c3b4a5f60")!

private func uuid(_ name: String) -> UUID {
    Identifiers.uuidV5(name: name, namespace: testNamespace)
}

/// ISO dizgesini `Date`'e çevirir; geçersiz dizge (web `Date.parse` → NaN) NaN'lı `Date` olur.
private func at(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: iso) ?? Date(timeIntervalSince1970: .nan)
}

/// web `Date.toISOString()` biçimi (UTC, milisaniyeli).
private func isoString(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

private func calendar(_ identifier: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: identifier)!
    return calendar
}

private let utc = calendar("UTC")
private let istanbul = calendar("Europe/Istanbul")
private let newYork = calendar("America/New_York")

private struct SegmentSpec: Sendable {
    var id: String?
    var kind: FocusSegmentKind
    let startedAt: String
    let endedAt: String?
    var sessionId: String
    var deletedAt: String?

    init(
        id: String? = nil, kind: FocusSegmentKind = .focus, startedAt: String, endedAt: String?,
        sessionId: String = sessionName, deletedAt: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.sessionId = sessionId
        self.deletedAt = deletedAt
    }
}

private struct SessionSpec: Sendable {
    var id: String = sessionName
    var startedAt = "2026-11-19T07:00:00.000Z"
    var endedAt: String?
    var deletedAt: String?
}

private func segment(_ spec: SegmentSpec, index: Int = 0) -> FocusSegmentSnapshot {
    FocusSegmentSnapshot(
        id: uuid(spec.id ?? "segment-\(index)"),
        sessionId: uuid(spec.sessionId),
        kind: spec.kind,
        startedAt: at(spec.startedAt),
        endedAt: spec.endedAt.map(at),
        deletedAt: spec.deletedAt.map(at)
    )
}

private func segments(_ specs: [SegmentSpec]) -> [FocusSegmentSnapshot] {
    specs.enumerated().map { segment($1, index: $0) }
}

private func session(_ spec: SessionSpec = SessionSpec()) -> FocusSessionSnapshot {
    FocusSessionSnapshot(
        id: uuid(spec.id), startedAt: at(spec.startedAt),
        endedAt: spec.endedAt.map(at), deletedAt: spec.deletedAt.map(at))
}

private func sessions(_ specs: [SessionSpec]) -> [FocusSessionSnapshot] { specs.map(session) }

/// Test görünen adı olarak vaka adını kullanan vaka protokolü.
private protocol NamedCase: CustomTestStringConvertible, Sendable {
    var name: String { get }
}
extension NamedCase { var testDescription: String { name } }

// MARK: - UTC

@Suite("UTC")
struct UTCTests {
    // MARK: segmentDurationMs

    fileprivate struct DurationCase: NamedCase {
        let name: String
        let segment: SegmentSpec
        let now: String
        let expected: Double
    }

    private static let durationCases: [DurationCase] = [
        DurationCase(
            name: "kapanmış segment: endedAt − startedAt",
            segment: SegmentSpec(
                startedAt: "2026-11-19T10:00:00.000Z", endedAt: "2026-11-19T10:25:00.000Z"),
            now: "2026-11-19T12:00:00.000Z", expected: 25 * min),
        DurationCase(
            name: "açık segment now anında kapanmış sayılır",
            segment: SegmentSpec(startedAt: "2026-11-19T10:00:00.000Z", endedAt: nil),
            now: "2026-11-19T10:12:30.000Z", expected: 12 * min + 30_000),
        DurationCase(
            name: "açık segment, now < startedAt → 0",
            segment: SegmentSpec(startedAt: "2026-11-19T10:00:00.000Z", endedAt: nil),
            now: "2026-11-19T09:59:00.000Z", expected: 0),
        DurationCase(
            name: "endedAt < startedAt (saat kayması) → 0",
            segment: SegmentSpec(
                startedAt: "2026-11-19T10:00:00.000Z", endedAt: "2026-11-19T09:00:00.000Z"),
            now: "2026-11-19T12:00:00.000Z", expected: 0),
        DurationCase(
            name: "sıfır uzunlukta segment → 0",
            segment: SegmentSpec(
                startedAt: "2026-11-19T10:00:00.000Z", endedAt: "2026-11-19T10:00:00.000Z"),
            now: "2026-11-19T12:00:00.000Z", expected: 0),
        DurationCase(
            name: "geçersiz zaman damgası → 0",
            segment: SegmentSpec(startedAt: "bozuk", endedAt: "2026-11-19T10:00:00.000Z"),
            now: "2026-11-19T12:00:00.000Z", expected: 0),
        DurationCase(
            name: "silinmiş segment yok sayılır → 0",
            segment: SegmentSpec(
                startedAt: "2026-11-19T10:00:00.000Z", endedAt: "2026-11-19T10:25:00.000Z",
                deletedAt: deletedAt),
            now: "2026-11-19T12:00:00.000Z", expected: 0),
    ]

    @Test("segmentDurationMs", arguments: durationCases)
    fileprivate func segmentDurationMs(_ testCase: DurationCase) {
        #expect(
            FocusCalc.segmentDurationMs(segment(testCase.segment), now: at(testCase.now))
                == testCase.expected)
    }

    @Test("segmentDurationMs: girdiyi mutasyona uğratmaz")
    func segmentDurationDoesNotMutate() {
        // Swift girdileri değer tipidir; çağrı sonrası aynı kalır (web: Object.freeze vakası).
        let input = segment(SegmentSpec(startedAt: "2026-11-19T10:00:00.000Z", endedAt: nil))
        let before = input
        _ = FocusCalc.segmentDurationMs(input, now: at("2026-11-19T10:05:00.000Z"))
        #expect(input == before)
    }

    // MARK: computeSessionStats

    fileprivate struct StatsCase: NamedCase {
        let name: String
        let segments: [SegmentSpec]
        let expected: FocusCalc.FocusSessionStats
    }

    private static let statsCases: [StatsCase] = {
        func closed(_ kind: FocusSegmentKind, _ start: String, _ end: String) -> SegmentSpec {
            SegmentSpec(kind: kind, startedAt: start, endedAt: end)
        }
        let focusOne = closed(.focus, "2026-11-19T09:00:00.000Z", "2026-11-19T09:25:00.000Z")
        let breakOne = closed(.break, "2026-11-19T09:25:00.000Z", "2026-11-19T09:30:00.000Z")
        let focusTwo = closed(.focus, "2026-11-19T09:30:00.000Z", "2026-11-19T10:05:00.000Z")
        let mixedExpected = FocusCalc.FocusSessionStats(
            focusMs: 60 * min, breakMs: 5 * min, focusCount: 2, breakCount: 1,
            averageFocusMs: 30 * min, averageBreakMs: 5 * min)
        return [
            StatsCase(name: "boş liste → tüm değerler 0", segments: [], expected: .init()),
            StatsCase(
                name: "kapanmış odak + mola: toplamlar, sayılar ve ortalamalar",
                segments: [focusOne, breakOne, focusTwo], expected: mixedExpected),
            StatsCase(
                name: "sıra önemsiz (ters sıralı girdi aynı sonucu verir)",
                segments: [focusTwo, breakOne, focusOne], expected: mixedExpected),
            StatsCase(
                name: "açık odak segmenti toplama now’a kadar girer, ortalamaya girmez",
                segments: [
                    closed(.focus, "2026-11-19T11:00:00.000Z", "2026-11-19T11:20:00.000Z"),
                    closed(.break, "2026-11-19T11:20:00.000Z", "2026-11-19T11:30:00.000Z"),
                    SegmentSpec(kind: .focus, startedAt: "2026-11-19T11:30:00.000Z", endedAt: nil),
                ],
                expected: .init(
                    focusMs: 50 * min, breakMs: 10 * min, focusCount: 2, breakCount: 1,
                    averageFocusMs: 20 * min, averageBreakMs: 10 * min)),
            StatsCase(
                name: "yalnızca açık odak segmenti → ortalama 0, sayı 1",
                segments: [
                    SegmentSpec(kind: .focus, startedAt: "2026-11-19T11:45:00.000Z", endedAt: nil)
                ],
                expected: .init(focusMs: 15 * min, focusCount: 1)),
            StatsCase(
                name: "açık mola segmenti toplama girer, mola ortalamasına girmez",
                segments: [
                    closed(.focus, "2026-11-19T11:00:00.000Z", "2026-11-19T11:40:00.000Z"),
                    SegmentSpec(kind: .break, startedAt: "2026-11-19T11:40:00.000Z", endedAt: nil),
                ],
                expected: .init(
                    focusMs: 40 * min, breakMs: 20 * min, focusCount: 1, breakCount: 1,
                    averageFocusMs: 40 * min, averageBreakMs: 0)),
            StatsCase(
                name: "silinmiş segmentler yok sayılır",
                segments: [
                    closed(.focus, "2026-11-19T09:00:00.000Z", "2026-11-19T09:30:00.000Z"),
                    SegmentSpec(
                        kind: .focus, startedAt: "2026-11-19T10:00:00.000Z",
                        endedAt: "2026-11-19T11:00:00.000Z", deletedAt: deletedAt),
                    SegmentSpec(
                        kind: .break, startedAt: "2026-11-19T09:30:00.000Z", endedAt: nil,
                        deletedAt: deletedAt),
                ],
                expected: .init(focusMs: 30 * min, focusCount: 1, averageFocusMs: 30 * min)),
            StatsCase(
                name: "endedAt < startedAt olan kapanmış segment 0 sayılır",
                segments: [
                    closed(.focus, "2026-11-19T09:00:00.000Z", "2026-11-19T09:40:00.000Z"),
                    closed(.focus, "2026-11-19T10:00:00.000Z", "2026-11-19T09:00:00.000Z"),
                ],
                expected: .init(focusMs: 40 * min, focusCount: 2, averageFocusMs: 20 * min)),
        ]
    }()

    @Test("computeSessionStats", arguments: statsCases)
    fileprivate func computeSessionStats(_ testCase: StatsCase) {
        let stats = FocusCalc.computeSessionStats(
            segments(testCase.segments), now: at("2026-11-19T12:00:00.000Z"))
        #expect(stats == testCase.expected)
    }

    // MARK: findOpenSegment

    fileprivate struct OpenSegmentCase: NamedCase {
        let name: String
        let segments: [SegmentSpec]
        let expectedId: String?
    }

    private static let openSegmentCases: [OpenSegmentCase] = [
        OpenSegmentCase(name: "boş liste → undefined", segments: [], expectedId: nil),
        OpenSegmentCase(
            name: "tümü kapalı → undefined",
            segments: [
                SegmentSpec(
                    id: "a", startedAt: "2026-11-19T09:00:00.000Z", endedAt: "2026-11-19T09:25:00.000Z")
            ], expectedId: nil),
        OpenSegmentCase(
            name: "tek açık segment",
            segments: [
                SegmentSpec(
                    id: "a", startedAt: "2026-11-19T09:00:00.000Z", endedAt: "2026-11-19T09:25:00.000Z"),
                SegmentSpec(
                    id: "b", kind: .break, startedAt: "2026-11-19T09:25:00.000Z", endedAt: nil),
            ], expectedId: "b"),
        OpenSegmentCase(
            name: "birden fazla açık → en son başlayan (sonda)",
            segments: [
                SegmentSpec(id: "a", startedAt: "2026-11-19T09:00:00.000Z", endedAt: nil),
                SegmentSpec(id: "b", startedAt: "2026-11-19T10:00:00.000Z", endedAt: nil),
            ], expectedId: "b"),
        OpenSegmentCase(
            name: "birden fazla açık → en son başlayan (başta)",
            segments: [
                SegmentSpec(id: "b", startedAt: "2026-11-19T10:00:00.000Z", endedAt: nil),
                SegmentSpec(id: "a", startedAt: "2026-11-19T09:00:00.000Z", endedAt: nil),
            ], expectedId: "b"),
        OpenSegmentCase(
            name: "silinmiş açık segment yok sayılır",
            segments: [
                SegmentSpec(id: "a", startedAt: "2026-11-19T09:00:00.000Z", endedAt: nil),
                SegmentSpec(
                    id: "b", startedAt: "2026-11-19T10:00:00.000Z", endedAt: nil, deletedAt: deletedAt),
            ], expectedId: "a"),
        OpenSegmentCase(
            name: "yalnızca silinmiş açık segment → undefined",
            segments: [
                SegmentSpec(
                    id: "a", startedAt: "2026-11-19T09:00:00.000Z", endedAt: nil, deletedAt: deletedAt)
            ], expectedId: nil),
    ]

    @Test("findOpenSegment", arguments: openSegmentCases)
    fileprivate func findOpenSegment(_ testCase: OpenSegmentCase) {
        let found = FocusCalc.findOpenSegment(segments(testCase.segments))
        #expect(found?.id == testCase.expectedId.map(uuid))
    }

    @Test("findOpenSegment: başlangıcı eşit açık segmentlerde ilk gelen kalır")
    func findOpenSegmentTieKeepsFirst() {
        let list = segments([
            SegmentSpec(id: "a", startedAt: "2026-11-19T09:00:00.000Z", endedAt: nil),
            SegmentSpec(id: "b", startedAt: "2026-11-19T09:00:00.000Z", endedAt: nil),
        ])
        #expect(FocusCalc.findOpenSegment(list)?.id == uuid("a"))
    }

    // MARK: focusPhase

    fileprivate struct PhaseCase: NamedCase {
        let name: String
        let session: SessionSpec
        let segments: [SegmentSpec]
        let expected: FocusCalc.FocusPhase
    }

    private static let phaseCases: [PhaseCase] = [
        PhaseCase(
            name: "bitmiş oturum → ended (açık segment kalmış olsa bile)",
            session: SessionSpec(endedAt: "2026-11-19T10:00:00.000Z"),
            segments: [SegmentSpec(startedAt: "2026-11-19T09:00:00.000Z", endedAt: nil)],
            expected: .ended),
        PhaseCase(
            name: "açık odak segmenti → focus", session: SessionSpec(),
            segments: [
                SegmentSpec(
                    kind: .break, startedAt: "2026-11-19T09:00:00.000Z",
                    endedAt: "2026-11-19T09:05:00.000Z"),
                SegmentSpec(kind: .focus, startedAt: "2026-11-19T09:05:00.000Z", endedAt: nil),
            ], expected: .focus),
        PhaseCase(
            name: "açık mola segmenti → break", session: SessionSpec(),
            segments: [
                SegmentSpec(
                    kind: .focus, startedAt: "2026-11-19T09:00:00.000Z",
                    endedAt: "2026-11-19T09:25:00.000Z"),
                SegmentSpec(kind: .break, startedAt: "2026-11-19T09:25:00.000Z", endedAt: nil),
            ], expected: .break),
        PhaseCase(
            name: "aktif oturumda açık segment yok (tutarsız veri) → break", session: SessionSpec(),
            segments: [
                SegmentSpec(
                    kind: .focus, startedAt: "2026-11-19T09:00:00.000Z",
                    endedAt: "2026-11-19T09:25:00.000Z")
            ], expected: .break),
        PhaseCase(
            name: "aktif oturum, hiç segment yok → break", session: SessionSpec(), segments: [],
            expected: .break),
        PhaseCase(
            name: "başka oturumun açık segmenti yok sayılır → break", session: SessionSpec(),
            segments: [
                SegmentSpec(
                    kind: .focus, startedAt: "2026-11-19T09:00:00.000Z", endedAt: nil,
                    sessionId: "other")
            ], expected: .break),
        PhaseCase(
            name: "silinmiş oturum → ended", session: SessionSpec(deletedAt: deletedAt),
            segments: [
                SegmentSpec(kind: .focus, startedAt: "2026-11-19T09:00:00.000Z", endedAt: nil)
            ], expected: .ended),
    ]

    @Test("getFocusPhase", arguments: phaseCases)
    fileprivate func focusPhase(_ testCase: PhaseCase) {
        let phase = FocusCalc.focusPhase(
            session: session(testCase.session), segments: segments(testCase.segments))
        #expect(phase == testCase.expected)
    }

    @Test("focusPhase: sessionId'si nil olan segment hiçbir oturuma ait sayılmaz → break")
    func focusPhaseIgnoresOrphanSegment() {
        let orphan = FocusSegmentSnapshot(
            id: uuid("orphan"), sessionId: nil, kind: .focus,
            startedAt: at("2026-11-19T09:00:00.000Z"))
        #expect(FocusCalc.focusPhase(session: session(), segments: [orphan]) == .break)
    }

    // MARK: openSegmentDurationMs

    fileprivate struct OpenDurationCase: NamedCase {
        let name: String
        let segments: [SegmentSpec]
        let kind: FocusSegmentKind
        let expected: Double
    }

    private static let openDurationCases: [OpenDurationCase] = [
        OpenDurationCase(name: "boş liste → 0", segments: [], kind: .focus, expected: 0),
        OpenDurationCase(
            name: "açık odak, tür focus → now’a kadarki süre",
            segments: [SegmentSpec(kind: .focus, startedAt: "2026-11-19T09:20:00.000Z", endedAt: nil)],
            kind: .focus, expected: 40 * min),
        OpenDurationCase(
            name: "açık odak, tür break → 0",
            segments: [SegmentSpec(kind: .focus, startedAt: "2026-11-19T09:20:00.000Z", endedAt: nil)],
            kind: .break, expected: 0),
        OpenDurationCase(
            name: "açık mola, tür break → now’a kadarki süre",
            segments: [SegmentSpec(kind: .break, startedAt: "2026-11-19T09:50:00.000Z", endedAt: nil)],
            kind: .break, expected: 10 * min),
        OpenDurationCase(
            name: "yalnızca kapalı segmentler → 0",
            segments: [
                SegmentSpec(
                    kind: .focus, startedAt: "2026-11-19T09:00:00.000Z",
                    endedAt: "2026-11-19T09:30:00.000Z")
            ], kind: .focus, expected: 0),
    ]

    @Test("openSegmentDurationMs", arguments: openDurationCases)
    fileprivate func openSegmentDurationMs(_ testCase: OpenDurationCase) {
        let duration = FocusCalc.openSegmentDurationMs(
            segments(testCase.segments), kind: testCase.kind, now: at("2026-11-19T10:00:00.000Z"))
        #expect(duration == testCase.expected)
    }

    // MARK: isLongBreak

    fileprivate struct LongBreakCase: NamedCase {
        let name: String
        let segments: [SegmentSpec]
        let now: String
        var threshold: Double?
        let expected: Bool
    }

    private static let longBreakCases: [LongBreakCase] = {
        let start = "2026-11-19T10:00:00.000Z"
        let openBreak = [SegmentSpec(kind: .break, startedAt: start, endedAt: nil)]
        let openFocus = [SegmentSpec(kind: .focus, startedAt: start, endedAt: nil)]
        return [
            LongBreakCase(
                name: "segment yok → false", segments: [], now: "2026-11-19T11:00:00.000Z",
                expected: false),
            LongBreakCase(
                name: "açık mola eşiğin hemen altında (29:59.999) → false", segments: openBreak,
                now: "2026-11-19T10:29:59.999Z", expected: false),
            LongBreakCase(
                name: "açık mola tam eşikte (30:00) → true", segments: openBreak,
                now: "2026-11-19T10:30:00.000Z", expected: true),
            LongBreakCase(
                name: "açık mola eşiğin üstünde → true", segments: openBreak,
                now: "2026-11-19T11:15:00.000Z", expected: true),
            LongBreakCase(
                name: "özel eşik 5 dk, 6 dk mola → true", segments: openBreak,
                now: "2026-11-19T10:06:00.000Z", threshold: 5 * min, expected: true),
            LongBreakCase(
                name: "özel eşik 5 dk, 4 dk mola → false", segments: openBreak,
                now: "2026-11-19T10:04:00.000Z", threshold: 5 * min, expected: false),
            LongBreakCase(
                name: "özel eşik 0, yeni açılmış mola → true", segments: openBreak, now: start,
                threshold: 0, expected: true),
            LongBreakCase(
                name: "açık odak segmenti (2 saat) → false", segments: openFocus,
                now: "2026-11-19T12:00:00.000Z", expected: false),
            LongBreakCase(
                name: "özel eşik 0, açık mola yok → false", segments: openFocus,
                now: "2026-11-19T12:00:00.000Z", threshold: 0, expected: false),
            LongBreakCase(
                name: "kapanmış uzun mola → false",
                segments: [
                    SegmentSpec(kind: .break, startedAt: start, endedAt: "2026-11-19T11:30:00.000Z")
                ], now: "2026-11-19T12:00:00.000Z", expected: false),
        ]
    }()

    @Test("isLongBreak", arguments: longBreakCases)
    fileprivate func isLongBreak(_ testCase: LongBreakCase) {
        let list = segments(testCase.segments)
        let result =
            testCase.threshold.map {
                FocusCalc.isLongBreak(list, now: at(testCase.now), thresholdMs: $0)
            } ?? FocusCalc.isLongBreak(list, now: at(testCase.now))
        #expect(result == testCase.expected)
    }

    @Test("varsayılan eşik 30 dakikadır")
    func defaultThresholdIsThirtyMinutes() {
        #expect(FocusCalc.longBreakThresholdMs == 30 * min)
    }
}

// MARK: - Europe/Istanbul (UTC+3, DST yok)

@Suite("Europe/Istanbul (UTC+3)")
struct IstanbulTests {
    // MARK: localDayBounds

    fileprivate struct BoundsCase: NamedCase {
        let day: ISODate
        let start: String
        let end: String
        var name: String { "\(day) → [\(start), \(end))" }
    }

    private static let boundsCases: [BoundsCase] = [
        BoundsCase(day: "2026-11-19", start: "2026-11-18T21:00:00.000Z", end: "2026-11-19T21:00:00.000Z"),
        BoundsCase(day: "2026-12-31", start: "2026-12-30T21:00:00.000Z", end: "2026-12-31T21:00:00.000Z"),
        BoundsCase(day: "2028-02-29", start: "2028-02-28T21:00:00.000Z", end: "2028-02-29T21:00:00.000Z"),
    ]

    @Test("localDayBounds", arguments: boundsCases)
    fileprivate func localDayBounds(_ testCase: BoundsCase) throws {
        let bounds = try FocusCalc.localDayBounds(testCase.day, calendar: istanbul)
        #expect(isoString(bounds.start) == testCase.start)
        #expect(isoString(bounds.end) == testCase.end)
    }

    fileprivate struct InvalidDayCase: NamedCase {
        let label: String
        let day: String
        var name: String { "geçersiz: \(label) (\(day)) → RangeError" }
    }

    private static let invalidDayCases: [InvalidDayCase] = [
        InvalidDayCase(label: "ay 13", day: "2026-13-01"),
        InvalidDayCase(label: "ay 00", day: "2026-00-10"),
        InvalidDayCase(label: "gün 00", day: "2026-01-00"),
        InvalidDayCase(label: "olmayan gün (30 Şubat)", day: "2026-02-30"),
        InvalidDayCase(label: "artık olmayan yılda 29 Şubat", day: "2026-02-29"),
        InvalidDayCase(label: "rastgele metin", day: "abc"),
        InvalidDayCase(label: "boş dizge", day: ""),
        InvalidDayCase(label: "sıfırsız biçim", day: "2026-2-3"),
        InvalidDayCase(label: "saat içeren dizge", day: "2026-11-19T00:00"),
    ]

    @Test("localDayBounds geçersiz gün", arguments: invalidDayCases)
    fileprivate func localDayBoundsInvalid(_ testCase: InvalidDayCase) {
        #expect(throws: FocusCalc.CalcError.invalidDay(testCase.day)) {
            try FocusCalc.localDayBounds(testCase.day, calendar: istanbul)
        }
    }

    @Test("localDayBounds: rakam olmayan karakterli, doğru uzunlukta dizge reddedilir")
    func localDayBoundsRejectsNonDigits() {
        #expect(throws: FocusCalc.CalcError.invalidDay("2026-1x-01")) {
            try FocusCalc.localDayBounds("2026-1x-01", calendar: istanbul)
        }
        #expect(throws: FocusCalc.CalcError.invalidDay("2026/11/19")) {
            try FocusCalc.localDayBounds("2026/11/19", calendar: istanbul)
        }
    }

    // MARK: recentDays

    fileprivate struct RecentCase: NamedCase {
        let name: String
        let now: String
        let count: Int
        let expected: [ISODate]
    }

    private static let recentCases: [RecentCase] = [
        RecentCase(
            name: "UTC akşamı yerelde ertesi gündür", now: "2026-11-18T22:00:00.000Z", count: 2,
            expected: ["2026-11-18", "2026-11-19"]),
        RecentCase(
            name: "ay sınırını geçer", now: "2026-03-01T09:00:00.000Z", count: 3,
            expected: ["2026-02-27", "2026-02-28", "2026-03-01"]),
        RecentCase(
            name: "yıl sınırını geçer", now: "2027-01-02T07:00:00.000Z", count: 4,
            expected: ["2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02"]),
        RecentCase(
            name: "count 1 → yalnızca bugün", now: "2026-11-19T09:00:00.000Z", count: 1,
            expected: ["2026-11-19"]),
        RecentCase(name: "count 0 → boş", now: "2026-11-19T09:00:00.000Z", count: 0, expected: []),
        RecentCase(
            name: "negatif count → boş", now: "2026-11-19T09:00:00.000Z", count: -3, expected: []),
    ]

    @Test("recentDays", arguments: recentCases)
    fileprivate func recentDays(_ testCase: RecentCase) {
        #expect(
            FocusCalc.recentDays(now: at(testCase.now), count: testCase.count, calendar: istanbul)
                == testCase.expected)
    }

    @Test("varsayılan 7 gün, eskiden yeniye, son eleman bugün")
    func recentDaysDefaultCount() {
        #expect(FocusCalc.recentDaysCount == 7)
        #expect(
            FocusCalc.recentDays(now: at("2026-11-19T09:00:00.000Z"), calendar: istanbul)
                == [
                    "2026-11-13", "2026-11-14", "2026-11-15", "2026-11-16", "2026-11-17",
                    "2026-11-18", "2026-11-19",
                ])
    }

    // MARK: dailyFocusTotalMs

    fileprivate struct DailyCase: NamedCase {
        let name: String
        let sessions: [SessionSpec]
        let segments: [SegmentSpec]
        let day: ISODate
        var now: String = "2026-11-20T09:00:00.000Z"
        let expected: Double
    }

    private static let dailyCases: [DailyCase] = {
        func focus(_ start: String, _ end: String?) -> SegmentSpec {
            SegmentSpec(startedAt: start, endedAt: end)
        }
        let eveningUTC = focus("2026-11-18T22:00:00.000Z", "2026-11-18T23:00:00.000Z")
        let midnightCrossing = focus("2026-11-18T20:30:00.000Z", "2026-11-18T21:30:00.000Z")
        let threeDays = focus("2026-11-17T20:00:00.000Z", "2026-11-18T22:00:00.000Z")
        let openFromEvening = focus("2026-11-18T20:00:00.000Z", nil)
        let single = [SessionSpec()]
        let beforeClose = "2026-11-19T07:00:00.000Z"
        return [
            DailyCase(name: "boş listeler → 0", sessions: [], segments: [], day: "2026-11-19", expected: 0),
            DailyCase(
                name: "oturum yok → segmentler sayılmaz", sessions: [],
                segments: [focus("2026-11-19T07:00:00.000Z", "2026-11-19T08:00:00.000Z")],
                day: "2026-11-19", expected: 0),
            DailyCase(
                name: "gün içindeki odak segmentleri toplanır", sessions: single,
                segments: [
                    focus("2026-11-19T07:00:00.000Z", "2026-11-19T07:25:00.000Z"),
                    focus("2026-11-19T08:00:00.000Z", "2026-11-19T08:35:00.000Z"),
                ], day: "2026-11-19", expected: 60 * min),
            DailyCase(
                name: "mola segmentleri sayılmaz", sessions: single,
                segments: [
                    focus("2026-11-19T07:00:00.000Z", "2026-11-19T07:25:00.000Z"),
                    SegmentSpec(
                        kind: .break, startedAt: "2026-11-19T07:25:00.000Z",
                        endedAt: "2026-11-19T08:25:00.000Z"),
                ], day: "2026-11-19", expected: 25 * min),
            DailyCase(
                name: "UTC akşamındaki segment (yerel 01:00–02:00) ertesi yerel güne aittir",
                sessions: single, segments: [eveningUTC], day: "2026-11-19", expected: hour),
            DailyCase(
                name: "UTC akşamındaki segment önceki yerel güne sayılmaz", sessions: single,
                segments: [eveningUTC], day: "2026-11-18", expected: 0),
            DailyCase(
                name: "gece yarısını aşan segment: önceki gün payı (23:30–00:00)", sessions: single,
                segments: [midnightCrossing], day: "2026-11-18", expected: 30 * min),
            DailyCase(
                name: "gece yarısını aşan segment: sonraki gün payı (00:00–00:30)", sessions: single,
                segments: [midnightCrossing], day: "2026-11-19", expected: 30 * min),
            DailyCase(
                name: "gece yarısını aşan oturum: her segment kendi gününe",
                sessions: [
                    SessionSpec(
                        startedAt: "2026-11-18T19:00:00.000Z", endedAt: "2026-11-18T22:30:00.000Z")
                ],
                segments: [
                    focus("2026-11-18T19:00:00.000Z", "2026-11-18T20:00:00.000Z"),
                    SegmentSpec(
                        kind: .break, startedAt: "2026-11-18T20:00:00.000Z",
                        endedAt: "2026-11-18T21:30:00.000Z"),
                    focus("2026-11-18T21:30:00.000Z", "2026-11-18T22:30:00.000Z"),
                ], day: "2026-11-19", expected: hour),
            DailyCase(
                name: "3 güne yayılan segment: ilk gün (23:00–24:00)", sessions: single,
                segments: [threeDays], day: "2026-11-17", expected: hour),
            DailyCase(
                name: "3 güne yayılan segment: orta gün tam 24 saat", sessions: single,
                segments: [threeDays], day: "2026-11-18", expected: 24 * hour),
            DailyCase(
                name: "3 güne yayılan segment: son gün (00:00–01:00)", sessions: single,
                segments: [threeDays], day: "2026-11-19", expected: hour),
            DailyCase(
                name: "açık segment now’a kadar sayılır ve güne kırpılır (önceki gün)",
                sessions: single, segments: [openFromEvening], day: "2026-11-18", now: beforeClose,
                expected: hour),
            DailyCase(
                name: "açık segment now’a kadar sayılır ve güne kırpılır (bugün, 00:00–10:00)",
                sessions: single, segments: [openFromEvening], day: "2026-11-19", now: beforeClose,
                expected: 10 * hour),
            DailyCase(
                name: "açık segment gelecek güne taşmaz", sessions: single,
                segments: [openFromEvening], day: "2026-11-20", now: beforeClose, expected: 0),
            DailyCase(
                name: "açık segment, now < startedAt → 0", sessions: single,
                segments: [focus("2026-11-19T08:00:00.000Z", nil)], day: "2026-11-19",
                now: beforeClose, expected: 0),
            DailyCase(
                name: "endedAt < startedAt → 0", sessions: single,
                segments: [focus("2026-11-19T08:00:00.000Z", "2026-11-19T07:00:00.000Z")],
                day: "2026-11-19", expected: 0),
            DailyCase(
                name: "silinmiş segment sayılmaz", sessions: single,
                segments: [
                    focus("2026-11-19T07:00:00.000Z", "2026-11-19T08:00:00.000Z"),
                    SegmentSpec(
                        startedAt: "2026-11-19T09:00:00.000Z", endedAt: "2026-11-19T10:00:00.000Z",
                        deletedAt: deletedAt),
                ], day: "2026-11-19", expected: hour),
            DailyCase(
                name: "silinmiş oturumun segmentleri sayılmaz",
                sessions: [SessionSpec(deletedAt: deletedAt)],
                segments: [focus("2026-11-19T07:00:00.000Z", "2026-11-19T08:00:00.000Z")],
                day: "2026-11-19", expected: 0),
            DailyCase(
                name: "listede olmayan oturumun segmentleri sayılmaz",
                sessions: [SessionSpec(id: "a")],
                segments: [
                    SegmentSpec(
                        startedAt: "2026-11-19T07:00:00.000Z", endedAt: "2026-11-19T07:30:00.000Z",
                        sessionId: "a"),
                    SegmentSpec(
                        startedAt: "2026-11-19T08:00:00.000Z", endedAt: "2026-11-19T09:00:00.000Z",
                        sessionId: "b"),
                ], day: "2026-11-19", expected: 30 * min),
            DailyCase(
                name: "birden fazla oturumun segmentleri toplanır",
                sessions: [SessionSpec(id: "a"), SessionSpec(id: "b")],
                segments: [
                    SegmentSpec(
                        startedAt: "2026-11-19T07:00:00.000Z", endedAt: "2026-11-19T07:30:00.000Z",
                        sessionId: "a"),
                    SegmentSpec(
                        startedAt: "2026-11-19T08:00:00.000Z", endedAt: "2026-11-19T09:00:00.000Z",
                        sessionId: "b"),
                ], day: "2026-11-19", expected: 90 * min),
        ]
    }()

    @Test("dailyFocusTotalMs", arguments: dailyCases)
    fileprivate func dailyFocusTotalMs(_ testCase: DailyCase) throws {
        let result = try FocusCalc.dailyFocusTotalMs(
            sessions: sessions(testCase.sessions), segments: segments(testCase.segments),
            day: testCase.day, now: at(testCase.now), calendar: istanbul)
        #expect(result == testCase.expected)
    }

    @Test("dailyFocusTotalMs: sessionId'si nil olan odak segmenti sayılmaz")
    func dailyFocusTotalIgnoresOrphanSegment() throws {
        let orphan = FocusSegmentSnapshot(
            id: uuid("orphan"), sessionId: nil, kind: .focus,
            startedAt: at("2026-11-19T07:00:00.000Z"), endedAt: at("2026-11-19T08:00:00.000Z"))
        let total = try FocusCalc.dailyFocusTotalMs(
            sessions: [session()], segments: [orphan], day: "2026-11-19",
            now: at("2026-11-20T09:00:00.000Z"), calendar: istanbul)
        #expect(total == 0)
    }

    @Test("dailyFocusTotalMs: geçersiz gün CalcError fırlatır")
    func dailyFocusTotalInvalidDay() {
        #expect(throws: FocusCalc.CalcError.invalidDay("2026-02-30")) {
            try FocusCalc.dailyFocusTotalMs(
                sessions: [], segments: [], day: "2026-02-30", now: at("2026-11-20T09:00:00.000Z"),
                calendar: istanbul)
        }
    }

    // MARK: dailyFocusTotals

    private static let totalsSessions = [session()]
    private static let totalsSegments = segments([
        SegmentSpec(startedAt: "2026-11-17T20:00:00.000Z", endedAt: "2026-11-18T22:00:00.000Z")
    ])
    private static let totalsNow = at("2026-11-20T09:00:00.000Z")

    @Test("dailyFocusTotals: boş gün listesi → boş sonuç")
    func totalsEmptyDays() throws {
        let totals = try FocusCalc.dailyFocusTotals(
            sessions: Self.totalsSessions, segments: Self.totalsSegments, days: [],
            now: Self.totalsNow, calendar: istanbul)
        #expect(totals.isEmpty)
    }

    @Test("dailyFocusTotals: days sırasını korur (sırasız girdi dahil)")
    func totalsKeepOrder() throws {
        let totals = try FocusCalc.dailyFocusTotals(
            sessions: Self.totalsSessions, segments: Self.totalsSegments,
            days: ["2026-11-19", "2026-11-16", "2026-11-18", "2026-11-17"],
            now: Self.totalsNow, calendar: istanbul)
        #expect(
            totals == [
                .init(day: "2026-11-19", focusMs: hour),
                .init(day: "2026-11-16", focusMs: 0),
                .init(day: "2026-11-18", focusMs: 24 * hour),
                .init(day: "2026-11-17", focusMs: hour),
            ])
    }

    @Test("dailyFocusTotals: recentDays ile birlikte grafik verisi üretir")
    func totalsWithRecentDays() throws {
        let days = FocusCalc.recentDays(
            now: at("2026-11-19T09:00:00.000Z"), count: 3, calendar: istanbul)
        let totals = try FocusCalc.dailyFocusTotals(
            sessions: Self.totalsSessions, segments: Self.totalsSegments, days: days,
            now: Self.totalsNow, calendar: istanbul)
        #expect(totals.map(\.focusMs) == [hour, 24 * hour, hour])
    }

    @Test("dailyFocusTotals: girdileri mutasyona uğratmaz")
    func totalsDoNotMutateInputs() throws {
        // Swift girdileri değer tipidir; çağrı sonrası aynı kalır (web: Object.freeze vakası).
        let sessionsBefore = Self.totalsSessions
        let segmentsBefore = Self.totalsSegments
        let totals = try FocusCalc.dailyFocusTotals(
            sessions: Self.totalsSessions, segments: Self.totalsSegments, days: ["2026-11-18"],
            now: Self.totalsNow, calendar: istanbul)
        #expect(totals == [.init(day: "2026-11-18", focusMs: 24 * hour)])
        #expect(Self.totalsSessions == sessionsBefore)
        #expect(Self.totalsSegments == segmentsBefore)
    }
}

// MARK: - America/New_York (DST: 2026-03-08 → 23 saat, 2026-11-01 → 25 saat)

@Suite("America/New_York (DST)")
struct NewYorkDSTTests {
    fileprivate struct BoundsCase: NamedCase {
        let name: String
        let day: ISODate
        let start: String
        let end: String
        let hours: Double
    }

    private static let boundsCases: [BoundsCase] = [
        BoundsCase(
            name: "normal gün (EST) 24 saat", day: "2026-01-15", start: "2026-01-15T05:00:00.000Z",
            end: "2026-01-16T05:00:00.000Z", hours: 24),
        BoundsCase(
            name: "ileri alma günü 23 saat", day: "2026-03-08", start: "2026-03-08T05:00:00.000Z",
            end: "2026-03-09T04:00:00.000Z", hours: 23),
        BoundsCase(
            name: "geri alma günü 25 saat", day: "2026-11-01", start: "2026-11-01T04:00:00.000Z",
            end: "2026-11-02T05:00:00.000Z", hours: 25),
    ]

    @Test("localDayBounds", arguments: boundsCases)
    fileprivate func localDayBounds(_ testCase: BoundsCase) throws {
        let bounds = try FocusCalc.localDayBounds(testCase.day, calendar: newYork)
        #expect(isoString(bounds.start) == testCase.start)
        #expect(isoString(bounds.end) == testCase.end)
        #expect(bounds.end.timeIntervalSince(bounds.start) * 1000 == testCase.hours * hour)
    }

    fileprivate struct RecentCase: NamedCase {
        let name: String
        let now: String
        let count: Int
        let expected: [ISODate]
    }

    private static let recentCases: [RecentCase] = [
        RecentCase(
            name: "ileri alma gününü atlamaz (now = 9 Mart 00:30 EDT)", now: "2026-03-09T04:30:00.000Z",
            count: 3, expected: ["2026-03-07", "2026-03-08", "2026-03-09"]),
        RecentCase(
            name: "geri alma gününü tekrarlamaz (now = 2 Kasım 23:30 EST)",
            now: "2026-11-03T04:30:00.000Z", count: 3,
            expected: ["2026-10-31", "2026-11-01", "2026-11-02"]),
    ]

    @Test("recentDays", arguments: recentCases)
    fileprivate func recentDays(_ testCase: RecentCase) {
        #expect(
            FocusCalc.recentDays(now: at(testCase.now), count: testCase.count, calendar: newYork)
                == testCase.expected)
    }

    fileprivate struct TotalsCase: NamedCase {
        let name: String
        let segment: SegmentSpec
        let days: [ISODate]
        let expectedMs: [Double]
    }

    private static let totalsCases: [TotalsCase] = [
        TotalsCase(
            name: "ileri alma günü boyunca süren segment: 1 + 23 + 1 saat",
            // 7 Mart 23:00 EST → 9 Mart 01:00 EDT
            segment: SegmentSpec(
                startedAt: "2026-03-08T04:00:00.000Z", endedAt: "2026-03-09T05:00:00.000Z"),
            days: ["2026-03-07", "2026-03-08", "2026-03-09"], expectedMs: [hour, 23 * hour, hour]),
        TotalsCase(
            name: "geri alma günü boyunca süren segment: 1 + 25 + 1 saat",
            // 31 Ekim 23:00 EDT → 2 Kasım 01:00 EST
            segment: SegmentSpec(
                startedAt: "2026-11-01T03:00:00.000Z", endedAt: "2026-11-02T06:00:00.000Z"),
            days: ["2026-10-31", "2026-11-01", "2026-11-02"], expectedMs: [hour, 25 * hour, hour]),
        TotalsCase(
            name: "geri alma saatinde (01:00–01:59 iki kez) segment tek güne gerçek süresiyle sayılır",
            // 1 Kasım 00:30 EDT → 01:30 EST (gerçek süre 2 saat)
            segment: SegmentSpec(
                startedAt: "2026-11-01T04:30:00.000Z", endedAt: "2026-11-01T06:30:00.000Z"),
            days: ["2026-10-31", "2026-11-01", "2026-11-02"], expectedMs: [0, 2 * hour, 0]),
    ]

    @Test("dailyFocusTotals", arguments: totalsCases)
    fileprivate func dailyFocusTotals(_ testCase: TotalsCase) throws {
        let totals = try FocusCalc.dailyFocusTotals(
            sessions: [session()], segments: [segment(testCase.segment)], days: testCase.days,
            now: at("2026-12-01T00:00:00.000Z"), calendar: newYork)
        let expected = zip(testCase.days, testCase.expectedMs).map {
            FocusCalc.DailyFocusTotal(day: $0, focusMs: $1)
        }
        #expect(totals == expected)
    }
}
