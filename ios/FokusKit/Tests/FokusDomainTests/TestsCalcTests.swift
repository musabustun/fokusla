import Foundation
import Testing

@testable import FokusDomain

// Test analizi hesapları testleri — web `web/src/domain/calc/tests.test.ts` ile aynı vakalar
// (aynı adlar, aynı girdi/çıktı değerleri). Büyük tuple dizileri tip denetimini yavaşlattığından
// vakalar tipli struct dizileridir.

// MARK: - Yardımcılar

private let subjectA = UUID(uuidString: "aaaaaaaa-0000-4000-8000-000000000001")!
private let subjectB = UUID(uuidString: "aaaaaaaa-0000-4000-8000-000000000002")!
private let topic1 = UUID(uuidString: "bbbbbbbb-0000-4000-8000-000000000001")!
private let topic2 = UUID(uuidString: "bbbbbbbb-0000-4000-8000-000000000002")!
private let topic3 = UUID(uuidString: "bbbbbbbb-0000-4000-8000-000000000003")!

private func at(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: iso)!
}

private let stamp = at("2026-11-19T10:00:00.000Z")

private func makeResult(
    subjectId: UUID? = subjectA, topicId: UUID? = topic1, takenAt: Date = stamp,
    correct: Int = 0, wrong: Int = 0, blank: Int = 0, deletedAt: Date? = nil
) -> TestResultSnapshot {
    TestResultSnapshot(
        subjectId: subjectId, topicId: topicId, takenAt: takenAt,
        correct: correct, wrong: wrong, blank: blank, deletedAt: deletedAt
    )
}

private let istanbul: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return calendar
}()

/// Yerel (İstanbul) saatle bir an — gün sınırı vakaları için.
private func local(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    istanbul.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

private func makeSummary(
    testCount: Int = 1, totalQuestions: Int = 0, correct: Int = 0, wrong: Int = 0, blank: Int = 0,
    net: Double = 0, accuracy: Double = 0, netRatio: Double = 0, lastTakenAt: Date? = nil
) -> TestSummary {
    TestSummary(
        testCount: testCount, totalQuestions: totalQuestions, correct: correct, wrong: wrong,
        blank: blank, net: net, accuracy: accuracy, netRatio: netRatio, lastTakenAt: lastTakenAt
    )
}

private func expectSummary(_ actual: TestSummary, _ expected: TestSummary) {
    #expect(actual.testCount == expected.testCount)
    #expect(actual.totalQuestions == expected.totalQuestions)
    #expect(actual.correct == expected.correct)
    #expect(actual.wrong == expected.wrong)
    #expect(actual.blank == expected.blank)
    #expect(actual.net == expected.net)
    #expect(abs(actual.accuracy - expected.accuracy) < 1e-10)
    #expect(abs(actual.netRatio - expected.netRatio) < 1e-10)
    #expect(actual.lastTakenAt == expected.lastTakenAt)
}

// MARK: - Sabitler

@Suite("sabitler")
struct TestsCalcConstantsTests {
    @Test("YKS kuralları")
    func yksRules() {
        #expect(TestsCalc.wrongAnswerPenalty == 0.25)
        #expect(TestsCalc.minQuestionsForWeakness == 20)
        #expect(TestsCalc.defaultWeakTopicLimit == 5)
    }
}

// MARK: - Tekil sonuç hesapları

private struct CountCase: Sendable, CustomTestStringConvertible {
    var name: String
    var correct: Int
    var wrong: Int
    var blank: Int
    var net: Double
    var questions: Int
    var accuracy: Double
    var testDescription: String { name }
}

private let countCases: [CountCase] = [
    CountCase(name: "hiç soru yok", correct: 0, wrong: 0, blank: 0, net: 0, questions: 0, accuracy: 0),
    CountCase(name: "hepsi doğru", correct: 20, wrong: 0, blank: 0, net: 20, questions: 20, accuracy: 1),
    CountCase(
        name: "yalnızca yanlış (negatif net)", correct: 0, wrong: 6, blank: 0, net: -1.5,
        questions: 6, accuracy: 0),
    CountCase(name: "yalnızca boş", correct: 0, wrong: 0, blank: 10, net: 0, questions: 10, accuracy: 0),
    CountCase(
        name: "4 yanlış 1 doğruyu götürür", correct: 1, wrong: 4, blank: 0, net: 0, questions: 5,
        accuracy: 0.2),
    CountCase(name: "karışık", correct: 30, wrong: 7, blank: 3, net: 28.25, questions: 40, accuracy: 0.75),
    CountCase(
        name: "tek yanlış çeyrek düşer", correct: 10, wrong: 1, blank: 9, net: 9.75, questions: 20,
        accuracy: 0.5),
]

@Suite("tekil sonuç hesapları")
struct TestsCalcCountTests {
    @Test("computeNet", arguments: countCases)
    fileprivate func computeNet(_ c: CountCase) {
        #expect(TestsCalc.computeNet(correct: c.correct, wrong: c.wrong) == c.net)
    }

    @Test("questionCount", arguments: countCases)
    fileprivate func questionCount(_ c: CountCase) {
        #expect(TestsCalc.questionCount(correct: c.correct, wrong: c.wrong, blank: c.blank) == c.questions)
    }

    @Test("accuracyOf", arguments: countCases)
    fileprivate func accuracyOf(_ c: CountCase) {
        let accuracy = TestsCalc.accuracyOf(correct: c.correct, wrong: c.wrong, blank: c.blank)
        #expect(abs(accuracy - c.accuracy) < 1e-10)
    }
}

// MARK: - summarize

private struct Row: Sendable {
    var correct: Int
    var wrong: Int
    var blank: Int
    var takenAt: Date
}

private struct SummaryCase: Sendable, CustomTestStringConvertible {
    var name: String
    var rows: [Row]
    var expected: TestSummary
    var testDescription: String { name }
}

private let summaryCases: [SummaryCase] = [
    SummaryCase(name: "boş liste", rows: [], expected: makeSummary(testCount: 0)),
    SummaryCase(
        name: "tek sonuç",
        rows: [Row(correct: 15, wrong: 4, blank: 1, takenAt: at("2026-11-19T09:00:00.000Z"))],
        expected: makeSummary(
            testCount: 1, totalQuestions: 20, correct: 15, wrong: 4, blank: 1, net: 14,
            accuracy: 0.75, netRatio: 0.7, lastTakenAt: at("2026-11-19T09:00:00.000Z"))),
    SummaryCase(
        name: "birden çok sonuç, lastTakenAt en geç olan (sıra karışık)",
        rows: [
            Row(correct: 10, wrong: 2, blank: 0, takenAt: at("2026-11-18T09:00:00.000Z")),
            Row(correct: 5, wrong: 5, blank: 2, takenAt: at("2026-11-19T20:00:00.000Z")),
            Row(correct: 3, wrong: 1, blank: 4, takenAt: at("2026-11-17T09:00:00.000Z")),
        ],
        expected: makeSummary(
            testCount: 3, totalQuestions: 32, correct: 18, wrong: 8, blank: 6, net: 16,
            accuracy: 18.0 / 32, netRatio: 16.0 / 32, lastTakenAt: at("2026-11-19T20:00:00.000Z"))),
    SummaryCase(
        name: "yalnızca yanlış (negatif net ve netRatio −0.25)",
        rows: [Row(correct: 0, wrong: 8, blank: 0, takenAt: at("2026-11-19T09:00:00.000Z"))],
        expected: makeSummary(
            testCount: 1, totalQuestions: 8, wrong: 8, net: -2, accuracy: 0, netRatio: -0.25,
            lastTakenAt: at("2026-11-19T09:00:00.000Z"))),
    SummaryCase(
        name: "yalnızca boş",
        rows: [Row(correct: 0, wrong: 0, blank: 12, takenAt: at("2026-11-19T09:00:00.000Z"))],
        expected: makeSummary(
            testCount: 1, totalQuestions: 12, blank: 12, lastTakenAt: at("2026-11-19T09:00:00.000Z"))),
    SummaryCase(
        name: "sıfır sorulu test sayılır ama oranlar 0",
        rows: [Row(correct: 0, wrong: 0, blank: 0, takenAt: at("2026-11-19T09:00:00.000Z"))],
        expected: makeSummary(testCount: 1, lastTakenAt: at("2026-11-19T09:00:00.000Z"))),
    SummaryCase(
        name: "hepsi doğru",
        rows: [
            Row(correct: 10, wrong: 0, blank: 0, takenAt: at("2026-11-19T09:00:00.000Z")),
            Row(correct: 30, wrong: 0, blank: 0, takenAt: at("2026-11-19T08:00:00.000Z")),
        ],
        expected: makeSummary(
            testCount: 2, totalQuestions: 40, correct: 40, net: 40, accuracy: 1, netRatio: 1,
            lastTakenAt: at("2026-11-19T09:00:00.000Z"))),
]

@Suite("summarize")
struct TestsCalcSummarizeTests {
    @Test("summarizeResults", arguments: summaryCases)
    fileprivate func summarizeResults(_ c: SummaryCase) {
        let results = c.rows.map {
            makeResult(takenAt: $0.takenAt, correct: $0.correct, wrong: $0.wrong, blank: $0.blank)
        }
        expectSummary(TestsCalc.summarize(results), c.expected)
    }

    @Test("silinmiş sonuçlar yok sayılır")
    func ignoresDeleted() {
        let results = [
            makeResult(correct: 10, wrong: 2),
            makeResult(takenAt: at("2026-11-20T10:00:00.000Z"), correct: 99, deletedAt: stamp),
        ]
        let summary = TestsCalc.summarize(results)
        #expect(summary.testCount == 1)
        #expect(summary.correct == 10)
        #expect(summary.lastTakenAt == stamp)
    }

    @Test("girdiyi değiştirmez")
    func doesNotMutateInput() {
        let results = [makeResult(correct: 5, wrong: 1), makeResult(correct: 2, wrong: 3)]
        let copy = results
        _ = TestsCalc.summarize(results)
        #expect(results == copy)
    }
}

// MARK: - summarizeBySubject / summarizeByTopic

private struct GroupRow: Sendable {
    var subjectId: UUID?
    var topicId: UUID?
    var correct: Int
    var wrong: Int
    var blank: Int
}

private struct GroupExpectation: Sendable {
    var key: UUID
    var testCount: Int
    var totalQuestions: Int
    var net: Double
}

private struct GroupCase: Sendable, CustomTestStringConvertible {
    var name: String
    var rows: [GroupRow]
    var bySubject: [GroupExpectation]
    var byTopic: [GroupExpectation]
    var testDescription: String { name }
}

private let groupCases: [GroupCase] = [
    GroupCase(name: "boş liste", rows: [], bySubject: [], byTopic: []),
    GroupCase(
        name: "tek sonuç",
        rows: [GroupRow(subjectId: subjectA, topicId: topic1, correct: 8, wrong: 4, blank: 0)],
        bySubject: [GroupExpectation(key: subjectA, testCount: 1, totalQuestions: 12, net: 7)],
        byTopic: [GroupExpectation(key: topic1, testCount: 1, totalQuestions: 12, net: 7)]),
    GroupCase(
        name: "iki ders, üç konu",
        rows: [
            GroupRow(subjectId: subjectA, topicId: topic1, correct: 10, wrong: 2, blank: 0),
            GroupRow(subjectId: subjectA, topicId: topic2, correct: 5, wrong: 4, blank: 1),
            GroupRow(subjectId: subjectA, topicId: topic1, correct: 6, wrong: 0, blank: 2),
            GroupRow(subjectId: subjectB, topicId: topic3, correct: 0, wrong: 4, blank: 0),
        ],
        bySubject: [
            GroupExpectation(key: subjectA, testCount: 3, totalQuestions: 30, net: 19.5),
            GroupExpectation(key: subjectB, testCount: 1, totalQuestions: 4, net: -1),
        ],
        byTopic: [
            GroupExpectation(key: topic1, testCount: 2, totalQuestions: 20, net: 15.5),
            GroupExpectation(key: topic2, testCount: 1, totalQuestions: 10, net: 4),
            GroupExpectation(key: topic3, testCount: 1, totalQuestions: 4, net: -1),
        ]),
    GroupCase(
        name: "topicId null olanlar konu özetinde atlanır, ders özetinde sayılır",
        rows: [
            GroupRow(subjectId: subjectA, topicId: nil, correct: 20, wrong: 0, blank: 0),
            GroupRow(subjectId: subjectA, topicId: topic1, correct: 4, wrong: 4, blank: 0),
        ],
        bySubject: [GroupExpectation(key: subjectA, testCount: 2, totalQuestions: 28, net: 23)],
        byTopic: [GroupExpectation(key: topic1, testCount: 1, totalQuestions: 8, net: 3)]),
    GroupCase(
        name: "yalnızca topicId null",
        rows: [GroupRow(subjectId: subjectB, topicId: nil, correct: 3, wrong: 0, blank: 0)],
        bySubject: [GroupExpectation(key: subjectB, testCount: 1, totalQuestions: 3, net: 3)],
        byTopic: []),
    GroupCase(
        name: "subjectId null olanlar ders özetinde atlanır",
        rows: [GroupRow(subjectId: nil, topicId: topic1, correct: 3, wrong: 0, blank: 0)],
        bySubject: [],
        byTopic: [GroupExpectation(key: topic1, testCount: 1, totalQuestions: 3, net: 3)]),
]

private func expectGroups(_ actual: [UUID: TestSummary], _ expected: [GroupExpectation]) {
    #expect(Set(actual.keys) == Set(expected.map(\.key)))
    for e in expected {
        let summary = actual[e.key]
        #expect(summary?.testCount == e.testCount)
        #expect(summary?.totalQuestions == e.totalQuestions)
        #expect(summary?.net == e.net)
    }
}

private func makeResults(_ rows: [GroupRow]) -> [TestResultSnapshot] {
    rows.map {
        makeResult(
            subjectId: $0.subjectId, topicId: $0.topicId,
            correct: $0.correct, wrong: $0.wrong, blank: $0.blank)
    }
}

@Suite("gruplama")
struct TestsCalcGroupTests {
    @Test("summarizeBySubject", arguments: groupCases)
    fileprivate func bySubject(_ c: GroupCase) {
        expectGroups(TestsCalc.summarizeBySubject(makeResults(c.rows)), c.bySubject)
    }

    @Test("summarizeByTopic", arguments: groupCases)
    fileprivate func byTopic(_ c: GroupCase) {
        expectGroups(TestsCalc.summarizeByTopic(makeResults(c.rows)), c.byTopic)
    }

    @Test("silinmiş sonuçlar gruplamada yok sayılır")
    func ignoresDeleted() {
        let results = [
            makeResult(correct: 5),
            makeResult(subjectId: subjectB, topicId: topic2, correct: 9, deletedAt: stamp),
        ]
        #expect(Set(TestsCalc.summarizeBySubject(results).keys) == [subjectA])
        #expect(Set(TestsCalc.summarizeByTopic(results).keys) == [topic1])
    }
}

// MARK: - findWeakestTopics

private struct WeakInput: Sendable {
    var topicId: UUID
    var totalQuestions: Int
    var netRatio: Double
}

private struct WeakOptions: Sendable {
    var minQuestions: Int?
    var limit: Int?
}

private struct WeakCase: Sendable, CustomTestStringConvertible {
    var name: String
    var topics: [WeakInput]
    var options: WeakOptions = WeakOptions()
    var expected: [UUID]
    var testDescription: String { name }
}

private func t(_ n: Int) -> UUID {
    UUID(uuidString: "dddddddd-0000-4000-8000-" + String(format: "%012d", n))!
}

private let weakCases: [WeakCase] = [
    WeakCase(name: "boş harita", topics: [], expected: []),
    WeakCase(
        name: "netRatio artan sıralı",
        topics: [
            WeakInput(topicId: t(1), totalQuestions: 40, netRatio: 0.8),
            WeakInput(topicId: t(2), totalQuestions: 40, netRatio: 0.1),
            WeakInput(topicId: t(3), totalQuestions: 40, netRatio: -0.2),
            WeakInput(topicId: t(4), totalQuestions: 40, netRatio: 0.5),
        ],
        expected: [t(3), t(2), t(4), t(1)]),
    WeakCase(
        name: "varsayılan eşiğin altındaki konu dışarıda (19 soru)",
        topics: [
            WeakInput(topicId: t(1), totalQuestions: 19, netRatio: -0.25),
            WeakInput(topicId: t(2), totalQuestions: 25, netRatio: 0.4),
        ],
        expected: [t(2)]),
    WeakCase(
        name: "eşik tam sınırda (20 soru) dahil",
        topics: [
            WeakInput(topicId: t(1), totalQuestions: 20, netRatio: 0.1),
            WeakInput(topicId: t(2), totalQuestions: 50, netRatio: 0.3),
        ],
        expected: [t(1), t(2)]),
    WeakCase(
        name: "özel eşik (minQuestions 5)",
        topics: [
            WeakInput(topicId: t(1), totalQuestions: 4, netRatio: 0),
            WeakInput(topicId: t(2), totalQuestions: 5, netRatio: 0.5),
            WeakInput(topicId: t(3), totalQuestions: 10, netRatio: 0.2),
        ],
        options: WeakOptions(minQuestions: 5),
        expected: [t(3), t(2)]),
    WeakCase(
        name: "eşitlikte çok soru çözülen önce",
        topics: [
            WeakInput(topicId: t(1), totalQuestions: 30, netRatio: 0.5),
            WeakInput(topicId: t(2), totalQuestions: 80, netRatio: 0.5),
            WeakInput(topicId: t(3), totalQuestions: 50, netRatio: 0.5),
        ],
        expected: [t(2), t(3), t(1)]),
    WeakCase(
        name: "netRatio ve soru eşitse topicId artan",
        topics: [
            WeakInput(topicId: t(3), totalQuestions: 40, netRatio: 0.25),
            WeakInput(topicId: t(1), totalQuestions: 40, netRatio: 0.25),
            WeakInput(topicId: t(2), totalQuestions: 40, netRatio: 0.25),
        ],
        expected: [t(1), t(2), t(3)]),
    WeakCase(
        name: "varsayılan limit 5",
        topics: (1...7).map { WeakInput(topicId: t($0), totalQuestions: 20, netRatio: Double($0) / 10) },
        expected: [t(1), t(2), t(3), t(4), t(5)]),
    WeakCase(
        name: "özel limit 2",
        topics: [
            WeakInput(topicId: t(1), totalQuestions: 20, netRatio: 0.9),
            WeakInput(topicId: t(2), totalQuestions: 20, netRatio: 0.3),
            WeakInput(topicId: t(3), totalQuestions: 20, netRatio: 0.6),
        ],
        options: WeakOptions(limit: 2),
        expected: [t(2), t(3)]),
    WeakCase(
        name: "limit 0 → boş",
        topics: [WeakInput(topicId: t(1), totalQuestions: 20, netRatio: 0.1)],
        options: WeakOptions(limit: 0),
        expected: []),
    WeakCase(
        name: "negatif limit → boş",
        topics: [WeakInput(topicId: t(1), totalQuestions: 20, netRatio: 0.1)],
        options: WeakOptions(limit: -3),
        expected: []),
    WeakCase(
        name: "limit konu sayısından büyük",
        topics: [
            WeakInput(topicId: t(2), totalQuestions: 20, netRatio: 0.2),
            WeakInput(topicId: t(1), totalQuestions: 20, netRatio: 0.1),
        ],
        options: WeakOptions(limit: 10),
        expected: [t(1), t(2)]),
    WeakCase(
        name: "hiçbiri eşiği geçmiyor",
        topics: [
            WeakInput(topicId: t(1), totalQuestions: 0, netRatio: 0),
            WeakInput(topicId: t(2), totalQuestions: 10, netRatio: -0.1),
        ],
        expected: []),
]

private func toSummaryMap(_ topics: [WeakInput]) -> [UUID: TestSummary] {
    Dictionary(
        uniqueKeysWithValues: topics.map {
            ($0.topicId, makeSummary(totalQuestions: $0.totalQuestions, netRatio: $0.netRatio))
        })
}

@Suite("findWeakestTopics")
struct TestsCalcWeakestTests {
    @Test("sıralama ve eşik", arguments: weakCases)
    fileprivate func weakest(_ c: WeakCase) {
        let summaries = toSummaryMap(c.topics)
        let weakest = TestsCalc.findWeakestTopics(
            summaries,
            minQuestions: c.options.minQuestions ?? TestsCalc.minQuestionsForWeakness,
            limit: c.options.limit ?? TestsCalc.defaultWeakTopicLimit
        )
        #expect(weakest.map(\.topicId) == c.expected)
        for w in weakest { #expect(w.summary == summaries[w.topicId]) }
    }

    @Test("varsayılan parametreler")
    func defaults() {
        let summaries = toSummaryMap(
            (1...7).map { WeakInput(topicId: t($0), totalQuestions: 20, netRatio: Double($0) / 10) })
        #expect(TestsCalc.findWeakestTopics(summaries).count == 5)
    }
}

// MARK: - dailyNetTrend

private struct TrendRow: Sendable {
    var takenAt: Date
    var correct: Int
    var wrong: Int
}

private struct TrendExpectation: Sendable, Equatable {
    var date: String
    var testCount: Int
    var net: Double
}

private struct TrendCase: Sendable, CustomTestStringConvertible {
    var name: String
    var rows: [TrendRow]
    var expected: [TrendExpectation]
    var testDescription: String { name }
}

private let trendCases: [TrendCase] = [
    TrendCase(name: "boş liste", rows: [], expected: []),
    TrendCase(
        name: "tek sonuç",
        rows: [TrendRow(takenAt: local(2026, 11, 19, 10), correct: 10, wrong: 2)],
        expected: [TrendExpectation(date: "2026-11-19", testCount: 1, net: 9.5)]),
    TrendCase(
        name: "aynı gün birden çok test toplanır",
        rows: [
            TrendRow(takenAt: local(2026, 11, 19, 8), correct: 10, wrong: 4),
            TrendRow(takenAt: local(2026, 11, 19, 21), correct: 5, wrong: 1),
        ],
        expected: [TrendExpectation(date: "2026-11-19", testCount: 2, net: 13.75)]),
    TrendCase(
        name: "gün sırasına göre artan (girdi karışık)",
        rows: [
            TrendRow(takenAt: local(2026, 11, 20, 9), correct: 3, wrong: 0),
            TrendRow(takenAt: local(2026, 11, 17, 9), correct: 1, wrong: 0),
            TrendRow(takenAt: local(2026, 11, 19, 9), correct: 2, wrong: 0),
        ],
        expected: [
            TrendExpectation(date: "2026-11-17", testCount: 1, net: 1),
            TrendExpectation(date: "2026-11-19", testCount: 1, net: 2),
            TrendExpectation(date: "2026-11-20", testCount: 1, net: 3),
        ]),
    TrendCase(
        name: "gece yarısı sınırı: 23:59 ve 00:00 farklı günler",
        rows: [
            TrendRow(takenAt: local(2026, 11, 19, 23, 59), correct: 4, wrong: 0),
            TrendRow(takenAt: local(2026, 11, 20, 0, 0), correct: 6, wrong: 4),
        ],
        expected: [
            TrendExpectation(date: "2026-11-19", testCount: 1, net: 4),
            TrendExpectation(date: "2026-11-20", testCount: 1, net: 5),
        ]),
    TrendCase(
        name: "ay ve yıl geçişi",
        rows: [
            TrendRow(takenAt: local(2027, 1, 1, 0, 30), correct: 2, wrong: 0),
            TrendRow(takenAt: local(2026, 12, 31, 23, 30), correct: 1, wrong: 0),
        ],
        expected: [
            TrendExpectation(date: "2026-12-31", testCount: 1, net: 1),
            TrendExpectation(date: "2027-01-01", testCount: 1, net: 2),
        ]),
    TrendCase(
        name: "negatif günlük net",
        rows: [TrendRow(takenAt: local(2026, 11, 19, 12), correct: 0, wrong: 12)],
        expected: [TrendExpectation(date: "2026-11-19", testCount: 1, net: -3)]),
]

@Suite("dailyNetTrend")
struct TestsCalcTrendTests {
    @Test("günlük trend", arguments: trendCases)
    fileprivate func trend(_ c: TrendCase) {
        let results = c.rows.map { makeResult(takenAt: $0.takenAt, correct: $0.correct, wrong: $0.wrong) }
        let trend = TestsCalc.dailyNetTrend(results, calendar: istanbul)
        let actual = trend.map {
            TrendExpectation(date: $0.date, testCount: $0.summary.testCount, net: $0.summary.net)
        }
        #expect(actual == c.expected)
    }

    @Test("her noktanın özeti o günün summarize sonucudur")
    func pointSummaryMatches() {
        let morning = makeResult(takenAt: local(2026, 11, 19, 8), correct: 7, wrong: 2, blank: 1)
        let evening = makeResult(takenAt: local(2026, 11, 19, 22), correct: 3, wrong: 1, blank: 6)
        let points = TestsCalc.dailyNetTrend([evening, morning], calendar: istanbul)
        #expect(points.first?.summary == TestsCalc.summarize([morning, evening]))
    }

    @Test("silinmiş sonuçlar trende girmez; varsayılan takvim")
    func ignoresDeleted() {
        let results = [
            makeResult(takenAt: local(2026, 11, 19, 12), correct: 4),
            makeResult(takenAt: local(2026, 11, 20, 12), correct: 9, deletedAt: stamp),
        ]
        #expect(TestsCalc.dailyNetTrend(results).count == 1)
    }

    @Test("girdiyi değiştirmez")
    func doesNotMutateInput() {
        let results = [
            makeResult(takenAt: local(2026, 11, 20, 9), correct: 3),
            makeResult(takenAt: local(2026, 11, 18, 9), correct: 1),
        ]
        let copy = results
        _ = TestsCalc.dailyNetTrend(results, calendar: istanbul)
        #expect(results == copy)
    }
}
