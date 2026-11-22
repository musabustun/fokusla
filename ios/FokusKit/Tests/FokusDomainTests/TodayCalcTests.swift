import Foundation
import Testing

@testable import FokusDomain

// Bugün hesapları testleri — web `web/src/domain/calc/today.test.ts` vakaları (aynı adlar, aynı
// girdi/çıktı değerleri). Web'de anlar YEREL saatle üretilir; burada saat dilimi Europe/Istanbul'a
// sabittir. Web dize id'leri (`session-1`) deterministik UUID v5'e çevrilir.
// Swift'te karşılığı olmayanlar atlandı: `planTaskToggle`, `focusingFriends`, ring testleri; kesirli
// `days`/`windowDays` vakaları (Swift'te parametreler `Int`).

// MARK: - Yardımcılar

private let minute = 60.0 * 1000

/// Referans gün: 2026-11-19 Perşembe, "şimdi" 10:00 (yerel).
private let today = "2026-11-19"

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return calendar
}()

private let testNamespace = UUID(uuidString: "3c9d2a4e-8b17-4f6a-a1d5-7e0b9c2f6d18")!

private func uuid(_ name: String) -> UUID {
    Identifiers.uuidV5(name: name, namespace: testNamespace)
}

private func moment(_ month: Int, _ day: Int, _ hour: Int, _ min: Int, _ sec: Int = 0) -> Date {
    calendar.date(
        from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: min, second: sec))!
}

private let now = moment(11, 19, 10, 0)
private let fixed = moment(1, 1, 3, 0)
private let deletedAt = moment(11, 19, 15, 0)

/// Kasım 2026'nın `day` gününde yerel bir an.
private func local(_ day: Int, _ hour: Int = 12, _ min: Int = 0, _ sec: Int = 0) -> Date {
    moment(11, day, hour, min, sec)
}

private func session(
    _ id: String, startedAt: Date, endedAt: Date? = nil, deletedAt: Date? = nil
) -> FocusSessionSnapshot {
    FocusSessionSnapshot(id: uuid(id), startedAt: startedAt, endedAt: endedAt, deletedAt: deletedAt)
}

private func seg(
    _ sessionId: String, _ startedAt: Date, _ endedAt: Date?, kind: FocusSegmentKind = .focus,
    deletedAt: Date? = nil
) -> FocusSegmentSnapshot {
    FocusSegmentSnapshot(
        id: uuid("segment-\(sessionId)-\(startedAt.timeIntervalSince1970)-\(kind.rawValue)"),
        sessionId: uuid(sessionId), kind: kind, startedAt: startedAt, endedAt: endedAt,
        deletedAt: deletedAt)
}

private let daily = RecurrenceRule(frequency: .daily)

private func makeTask(
    _ title: String, order: Int = 0, deletedAt: Date? = nil
) -> TaskSnapshot {
    TaskSnapshot(
        id: uuid(title), title: title, kind: .routine, order: order, recurrence: daily,
        createdAt: local(1), deletedAt: deletedAt)
}

private func makeAssignment(
    _ title: String, dueDate: ISODate? = nil, completedAt: Date? = nil, deletedAt: Date? = nil
) -> TaskSnapshot {
    TaskSnapshot(
        id: uuid(title), title: title, kind: .assignment, dueDate: dueDate, completedAt: completedAt,
        createdAt: local(1), deletedAt: deletedAt)
}

private func makeCompletion(
    _ taskTitle: String, date: ISODate = today, deletedAt: Date? = nil
) -> TaskCompletionSnapshot {
    TaskCompletionSnapshot(
        id: uuid("completion-\(taskTitle)-\(date)-\(deletedAt != nil)"), taskId: uuid(taskTitle),
        date: date, completedAt: local(19, 9), deletedAt: deletedAt)
}

private func result(
    _ id: String, takenAt: Date, correct: Int, wrong: Int, blank: Int, topic: String? = nil,
    deletedAt: Date? = nil
) -> TestResultSnapshot {
    TestResultSnapshot(
        id: uuid(id), subjectId: uuid("subject-1"), topicId: topic.map(uuid), takenAt: takenAt,
        correct: correct, wrong: wrong, blank: blank, deletedAt: deletedAt)
}

private func bookSummary(_ id: String, _ status: BooksCalc.BookStatus) -> BooksCalc.BookSummary {
    BooksCalc.BookSummary(
        book: BookSnapshot(
            id: uuid(id), title: id, kind: .questionBank, unit: .page, totalUnits: 100,
            createdAt: fixed, updatedAt: fixed),
        latest: nil, reachedUnit: 0, ratio: 0, status: status, lastProgressAt: nil, weeklyPace: nil,
        daysToFinish: nil, activityAt: fixed)
}

// MARK: - sabitler

@Suite("sabitler")
struct TodaySabitlerTests {
    @Test("belgelenen değerleri taşır")
    func documentedValues() {
        #expect(TodayCalc.chartDays == 7)
        #expect(TodayCalc.recentTestsWindowDays == 7)
        #expect(TodayCalc.weakTopicLimit == 3)
        #expect(TodayCalc.bookLimit == 3)
    }

    @Test("eşik tests calc ile aynı (20 soru)")
    func weaknessThreshold() {
        #expect(TestsCalc.minQuestionsForWeakness == 20)
    }

    @Test("selam metinleri Türkçe")
    func greetingTexts() {
        #expect(TodayCalc.Greeting.morning.text == "Günaydın")
        #expect(TodayCalc.Greeting.afternoon.text == "İyi günler")
        #expect(TodayCalc.Greeting.evening.text == "İyi akşamlar")
        #expect(TodayCalc.Greeting.night.text == "İyi geceler")
    }
}

// MARK: - greeting

struct TodayGreetingCase: Sendable, CustomTestStringConvertible {
    let name: String
    let hour: Int
    let minute: Int
    let expected: TodayCalc.Greeting
    var testDescription: String { name }
}

private let greetingCases: [TodayGreetingCase] = [
    TodayGreetingCase(name: "00:00 gece", hour: 0, minute: 0, expected: .night),
    TodayGreetingCase(name: "04:00 gece", hour: 4, minute: 0, expected: .night),
    TodayGreetingCase(name: "04:59 gece", hour: 4, minute: 59, expected: .night),
    TodayGreetingCase(name: "05:00 sabah (sınır)", hour: 5, minute: 0, expected: .morning),
    TodayGreetingCase(name: "11:00 sabah", hour: 11, minute: 0, expected: .morning),
    TodayGreetingCase(name: "11:59 sabah", hour: 11, minute: 59, expected: .morning),
    TodayGreetingCase(name: "12:00 öğleden sonra (sınır)", hour: 12, minute: 0, expected: .afternoon),
    TodayGreetingCase(name: "17:00 öğleden sonra", hour: 17, minute: 0, expected: .afternoon),
    TodayGreetingCase(name: "17:59 öğleden sonra", hour: 17, minute: 59, expected: .afternoon),
    TodayGreetingCase(name: "18:00 akşam (sınır)", hour: 18, minute: 0, expected: .evening),
    TodayGreetingCase(name: "21:00 akşam", hour: 21, minute: 0, expected: .evening),
    TodayGreetingCase(name: "21:59 akşam", hour: 21, minute: 59, expected: .evening),
    TodayGreetingCase(name: "22:00 gece (sınır)", hour: 22, minute: 0, expected: .night),
    TodayGreetingCase(name: "23:00 gece", hour: 23, minute: 0, expected: .night),
]

@Suite("greeting")
struct TodayGreetingTests {
    @Test("greeting", arguments: greetingCases)
    func greeting(_ testCase: TodayGreetingCase) {
        let date = local(19, testCase.hour, testCase.minute)
        #expect(TodayCalc.greeting(now: date, calendar: calendar) == testCase.expected)
    }
}

// MARK: - focusSummary

struct TodayFocusSummaryCase: Sendable, CustomTestStringConvertible {
    let name: String
    let sessions: [FocusSessionSnapshot]
    let segments: [FocusSegmentSnapshot]
    let expected: TodayCalc.FocusSummary
    var testDescription: String { name }
}

private let focusSummaryCases: [TodayFocusSummaryCase] = [
    TodayFocusSummaryCase(
        name: "veri yok → hepsi 0", sessions: [], segments: [],
        expected: .init(totalMs: 0, sessionCount: 0, averageFocusMs: 0)),
    TodayFocusSummaryCase(
        name: "açık oturum: kapanmış + açık odak; ortalama yalnızca kapanmışlar, mola sayılmaz",
        sessions: [session("open", startedAt: local(19, 8))],
        segments: [
            seg("open", local(19, 8), local(19, 8, 30)),
            seg("open", local(19, 8, 30), local(19, 8, 40), kind: .break),
            seg("open", local(19, 8, 40), local(19, 9)),
            seg("open", local(19, 9, 40), nil),
        ],
        expected: .init(totalMs: 70 * minute, sessionCount: 1, averageFocusMs: 25 * minute)),
    TodayFocusSummaryCase(
        name: "dün başlayıp gece yarısını aşan oturum: yalnızca bugünkü kısım toplanır",
        sessions: [session("cross", startedAt: local(18, 23, 30), endedAt: local(19, 0, 30))],
        segments: [seg("cross", local(18, 23, 30), local(19, 0, 20))],
        expected: .init(totalMs: 20 * minute, sessionCount: 1, averageFocusMs: 50 * minute)),
    TodayFocusSummaryCase(
        name: "dün başlayıp gece yarısından sonra biten ama bugün yalnızca molası olan oturum sayılmaz",
        sessions: [session("cross-break", startedAt: local(18, 23), endedAt: local(19, 0, 15))],
        segments: [
            seg("cross-break", local(18, 23), local(18, 23, 50)),
            seg("cross-break", local(18, 23, 50), local(19, 0, 15), kind: .break),
        ],
        expected: .init(totalMs: 0, sessionCount: 0, averageFocusMs: 0)),
    TodayFocusSummaryCase(
        name: "silinmiş oturum ve silinmiş segment yok sayılır",
        sessions: [
            session("live", startedAt: local(19, 8), endedAt: local(19, 9)),
            session("gone", startedAt: local(19, 9), deletedAt: deletedAt),
        ],
        segments: [
            seg("live", local(19, 8), local(19, 8, 30)),
            seg("live", local(19, 8, 30), local(19, 9), deletedAt: deletedAt),
            seg("gone", local(19, 9), local(19, 9, 50)),
        ],
        expected: .init(totalMs: 30 * minute, sessionCount: 1, averageFocusMs: 30 * minute)),
    TodayFocusSummaryCase(
        name: "önceki günün oturumu sayıma ve ortalamaya girmez",
        sessions: [
            session("old", startedAt: local(17, 9), endedAt: local(17, 10)),
            session("today", startedAt: local(19, 8), endedAt: local(19, 8, 20)),
        ],
        segments: [
            seg("old", local(17, 9), local(17, 10)),
            seg("today", local(19, 8), local(19, 8, 20)),
        ],
        expected: .init(totalMs: 20 * minute, sessionCount: 1, averageFocusMs: 20 * minute)),
    TodayFocusSummaryCase(
        name: "bugün başlayıp segmentsiz biten oturum sayılır (süre 0)",
        sessions: [session("empty", startedAt: local(19, 7), endedAt: local(19, 7, 1))],
        segments: [],
        expected: .init(totalMs: 0, sessionCount: 1, averageFocusMs: 0)),
]

@Suite("todayFocusSummary")
struct TodayFocusSummaryTests {
    @Test("focusSummary", arguments: focusSummaryCases)
    func focusSummary(_ testCase: TodayFocusSummaryCase) {
        let summary = TodayCalc.focusSummary(
            sessions: testCase.sessions, segments: testCase.segments, today: today, now: now,
            calendar: calendar)
        #expect(summary == testCase.expected)
    }
}

// MARK: - activeFocus

struct TodayActiveFocusCase: Sendable, CustomTestStringConvertible {
    let name: String
    let session: FocusSessionSnapshot?
    let segments: [FocusSegmentSnapshot]
    let expected: TodayCalc.ActiveFocus?
    var testDescription: String { name }
}

private let otherSessionOpen = seg("other", local(19, 7), nil)

private let activeFocusCases: [TodayActiveFocusCase] = [
    TodayActiveFocusCase(name: "oturum yok → nil", session: nil, segments: [], expected: nil),
    TodayActiveFocusCase(
        name: "bitmiş oturum → nil",
        session: session("a", startedAt: local(19, 8), endedAt: local(19, 9)),
        segments: [seg("a", local(19, 8), local(19, 9))], expected: nil),
    TodayActiveFocusCase(
        name: "silinmiş oturum → nil",
        session: session("a", startedAt: local(19, 9), deletedAt: deletedAt),
        segments: [seg("a", local(19, 9), nil)], expected: nil),
    TodayActiveFocusCase(
        name: "odak evresi: açık odak segmenti now’a kadar; başka oturumun segmenti sayılmaz",
        session: session("a", startedAt: local(19, 9)),
        segments: [
            otherSessionOpen,
            seg("a", local(19, 9), local(19, 9, 30)),
            seg("a", local(19, 9, 30), local(19, 9, 40), kind: .break),
            seg("a", local(19, 9, 40), nil),
        ],
        expected: .init(phase: .focus, sessionFocusMs: 50 * minute)),
    TodayActiveFocusCase(
        name: "mola evresi: açık mola odak süresine eklenmez",
        session: session("a", startedAt: local(19, 9)),
        segments: [
            otherSessionOpen,
            seg("a", local(19, 9), local(19, 9, 45)),
            seg("a", local(19, 9, 45), nil, kind: .break),
        ],
        expected: .init(phase: .break, sessionFocusMs: 45 * minute)),
    TodayActiveFocusCase(
        name: "açık oturumda yalnızca başka oturumun açık odağı var → mola, 0",
        session: session("a", startedAt: local(19, 9)),
        segments: [otherSessionOpen],
        expected: .init(phase: .break, sessionFocusMs: 0)),
]

@Suite("activeFocusState")
struct TodayActiveFocusTests {
    @Test("activeFocus", arguments: activeFocusCases)
    func activeFocus(_ testCase: TodayActiveFocusCase) {
        let state = TodayCalc.activeFocus(
            session: testCase.session, segments: testCase.segments, now: now)
        #expect(state == testCase.expected)
    }
}

// MARK: - recentFocusTotals

struct TodayRecentDaysCase: Sendable, CustomTestStringConvertible {
    let name: String
    let now: Date
    let days: Int
    let expected: [ISODate]
    var testDescription: String { name }
}

private let recentDaysCases: [TodayRecentDaysCase] = [
    TodayRecentDaysCase(name: "days = 0 → boş", now: now, days: 0, expected: []),
    TodayRecentDaysCase(name: "days < 0 → boş", now: now, days: -3, expected: []),
    TodayRecentDaysCase(name: "days = 1 → yalnızca bugün", now: now, days: 1, expected: [today]),
    TodayRecentDaysCase(
        name: "ay sınırı (artık olmayan yıl şubatı)", now: moment(3, 1, 10, 0), days: 3,
        expected: ["2026-02-27", "2026-02-28", "2026-03-01"]),
]

@Suite("recentFocusTotals")
struct TodayRecentFocusTotalsTests {
    private let sessions = [
        session("past", startedAt: local(17, 9), endedAt: local(17, 10)),
        session("now", startedAt: local(19, 9, 30)),
    ]
    private let segments = [
        seg("past", local(17, 9), local(17, 9, 30)),
        seg("now", local(19, 9, 30), nil),
    ]

    @Test("varsayılan 7 gün, eskiden yeniye (son eleman bugün), açık segment now’a kadar")
    func defaultSevenDays() {
        let totals = TodayCalc.recentFocusTotals(
            sessions: sessions, segments: segments, now: now, calendar: calendar)
        #expect(
            totals == [
                .init(day: "2026-11-13", focusMs: 0),
                .init(day: "2026-11-14", focusMs: 0),
                .init(day: "2026-11-15", focusMs: 0),
                .init(day: "2026-11-16", focusMs: 0),
                .init(day: "2026-11-17", focusMs: 30 * minute),
                .init(day: "2026-11-18", focusMs: 0),
                .init(day: "2026-11-19", focusMs: 30 * minute),
            ])
    }

    @Test("günler", arguments: recentDaysCases)
    func days(_ testCase: TodayRecentDaysCase) {
        let totals = TodayCalc.recentFocusTotals(
            sessions: [], segments: [], now: testCase.now, days: testCase.days, calendar: calendar)
        #expect(totals.map(\.day) == testCase.expected)
    }
}

// MARK: - taskOverview

private struct OverviewRow: Equatable {
    let title: String
    let group: TodayCalc.TaskGroup
    let done: Bool
}

@Suite("todayTaskOverview")
struct TodayTaskOverviewTests {
    @Test("boş → öğe yok, sayılar 0")
    func empty() {
        let overview = TodayCalc.taskOverview(
            tasks: [], completions: [], today: today, calendar: calendar)
        #expect(overview == TodayCalc.TaskOverview(items: [], totalCount: 0, doneCount: 0))
    }

    @Test("gruplar sırayla: geciken, rutin, bugün, yaklaşan; yaklaşanlar sayılmaz; silinenler yok")
    func groupsInOrder() {
        let tasks = [
            makeAssignment("Yaklaşan (bugün bitti)", dueDate: "2026-11-22", completedAt: local(19, 9)),
            makeAssignment("Tarihsiz"),
            makeTask("Rutin B", order: 1),
            makeAssignment("Bugün teslim (bitti)", dueDate: today, completedAt: local(19, 8)),
            makeAssignment("Geciken", dueDate: "2026-11-17"),
            makeTask("Rutin A", order: 0),
            makeAssignment("Silinmiş ödev", dueDate: today, deletedAt: deletedAt),
            makeTask("Silinmiş rutin", deletedAt: deletedAt),
            makeAssignment("Ufkun ötesi", dueDate: "2026-12-31"),
        ]
        let completions = [
            makeCompletion("Rutin A"),
            makeCompletion("Rutin B", date: "2026-11-18"),
            makeCompletion("Rutin B", deletedAt: deletedAt),
        ]

        let overview = TodayCalc.taskOverview(
            tasks: tasks, completions: completions, today: today, calendar: calendar)

        let rows = overview.items.map { OverviewRow(title: $0.task.title, group: $0.group, done: $0.isDone) }
        #expect(
            rows == [
                OverviewRow(title: "Geciken", group: .overdue, done: false),
                OverviewRow(title: "Rutin A", group: .routine, done: true),
                OverviewRow(title: "Rutin B", group: .routine, done: false),
                OverviewRow(title: "Bugün teslim (bitti)", group: .dueToday, done: true),
                OverviewRow(title: "Tarihsiz", group: .dueToday, done: false),
                OverviewRow(title: "Yaklaşan (bugün bitti)", group: .upcoming, done: true),
            ])
        #expect(overview.totalCount == 5)
        #expect(overview.doneCount == 2)
    }
}

// MARK: - recentTests

private let todayLate = result("today-late", takenAt: local(19, 23, 59), correct: 10, wrong: 2, blank: 3)
private let todayEarly = result("today-early", takenAt: local(19, 0, 0), correct: 5, wrong: 0, blank: 0)
private let yesterday = result("yesterday", takenAt: local(18, 12), correct: 3, wrong: 0, blank: 0)
private let sixDaysAgo = result("six", takenAt: local(13, 0, 0), correct: 4, wrong: 4, blank: 2)
private let sevenDaysAgo = result("seven", takenAt: local(12, 23, 59), correct: 9, wrong: 9, blank: 9)
private let tomorrow = result("future", takenAt: local(20, 0, 0), correct: 7, wrong: 7, blank: 7)
private let deletedToday = result(
    "deleted", takenAt: local(19, 9), correct: 50, wrong: 0, blank: 0, deletedAt: deletedAt)
private let allResults = [
    todayLate, todayEarly, yesterday, sixDaysAgo, sevenDaysAgo, tomorrow, deletedToday,
]

struct TodayWindowCase: Sendable, CustomTestStringConvertible {
    let name: String
    let windowDays: Int
    let expectedIds: [String]
    var testDescription: String { name }
}

private let windowCases: [TodayWindowCase] = [
    TodayWindowCase(name: "7 gün", windowDays: 7, expectedIds: ["today-late", "today-early", "yesterday", "six"]),
    TodayWindowCase(
        name: "8 gün → 7 gün önce de dahil", windowDays: 8,
        expectedIds: ["today-late", "today-early", "yesterday", "six", "seven"]),
    TodayWindowCase(name: "1 gün → yalnızca bugün", windowDays: 1, expectedIds: ["today-late", "today-early"]),
    TodayWindowCase(name: "0 gün → 1 sayılır", windowDays: 0, expectedIds: ["today-late", "today-early"]),
    TodayWindowCase(name: "negatif → 1 sayılır", windowDays: -5, expectedIds: ["today-late", "today-early"]),
]

@Suite("recentTestsSummary")
struct TodayRecentTestsTests {
    @Test("varsayılan 7 günlük pencere: 6 gün önce dahil, 7 gün önce / gelecek / silinmiş hariç")
    func defaultWindow() {
        let summary = TodayCalc.recentTests(results: allResults, today: today, calendar: calendar)
        #expect(summary.todayQuestions == 20)
        #expect(
            summary.window == TestsCalc.summarize([todayLate, todayEarly, yesterday, sixDaysAgo]))
        #expect(summary.window.testCount == 4)
        #expect(summary.window.totalQuestions == 33)
        #expect(summary.window.correct == 22)
        #expect(summary.window.wrong == 6)
        #expect(summary.window.blank == 5)
        #expect(summary.window.net == 20.5)
        #expect(summary.window.lastTakenAt == todayLate.takenAt)
        #expect(summary.allTimeCount == 6)
    }

    @Test("pencere", arguments: windowCases)
    func window(_ testCase: TodayWindowCase) {
        let byId = Dictionary(uniqueKeysWithValues: allResults.map { ($0.id, $0) })
        let expected = TestsCalc.summarize(testCase.expectedIds.map { byId[uuid($0)]! })
        let summary = TodayCalc.recentTests(
            results: allResults, today: today, windowDays: testCase.windowDays, calendar: calendar)
        #expect(summary.window == expected)
        #expect(summary.todayQuestions == 20)
        #expect(summary.allTimeCount == 6)
    }

    @Test("boş → sıfırlar, lastTakenAt nil")
    func empty() {
        let summary = TodayCalc.recentTests(results: [], today: today, calendar: calendar)
        #expect(
            summary
                == TodayCalc.RecentTests(
                    todayQuestions: 0, window: TestsCalc.summarize([]), allTimeCount: 0))
        #expect(summary.window.lastTakenAt == nil)
    }

    @Test("yalnızca silinmiş sonuçlar → allTimeCount 0")
    func onlyDeleted() {
        let summary = TodayCalc.recentTests(results: [deletedToday], today: today, calendar: calendar)
        #expect(summary.allTimeCount == 0)
    }
}

// MARK: - weakestTopics

private let weakAt = local(19, 10)

// Her konu 20 soru (eşik); netRatio: t1 −0.1, t2 0.125, t3 0.4, t4 0.7, t5 1.
private let weakResults: [TestResultSnapshot] = [
    result("w-t5", takenAt: weakAt, correct: 20, wrong: 0, blank: 0, topic: "t5"),
    result("w-t3", takenAt: weakAt, correct: 10, wrong: 8, blank: 2, topic: "t3"),
    result("w-t1", takenAt: weakAt, correct: 2, wrong: 16, blank: 2, topic: "t1"),
    result("w-t4", takenAt: weakAt, correct: 15, wrong: 4, blank: 1, topic: "t4"),
    result("w-t2", takenAt: weakAt, correct: 5, wrong: 10, blank: 5, topic: "t2"),
    // Eşiğin altında (19 soru) — çok kötü olsa da listeye girmez.
    result("w-few", takenAt: weakAt, correct: 0, wrong: 19, blank: 0, topic: "few"),
    // Yalnızca silinmiş sonucu olan konu.
    result("w-gone", takenAt: weakAt, correct: 0, wrong: 40, blank: 0, topic: "gone", deletedAt: deletedAt),
    // Silinmiş sonuç sayılmazsa eşiğin altında kalır (10 + 10 silinmiş).
    result("w-half-1", takenAt: weakAt, correct: 0, wrong: 10, blank: 0, topic: "half"),
    result("w-half-2", takenAt: weakAt, correct: 0, wrong: 10, blank: 0, topic: "half", deletedAt: deletedAt),
    // Konusuz sonuç atlanır.
    result("w-none", takenAt: weakAt, correct: 0, wrong: 30, blank: 0),
]

struct TodayWeakLimitCase: Sendable, CustomTestStringConvertible {
    let name: String
    let limit: Int?
    let expected: [String]
    var testDescription: String { name }
}

private let weakLimitCases: [TodayWeakLimitCase] = [
    TodayWeakLimitCase(name: "varsayılan limit 3", limit: nil, expected: ["t1", "t2", "t3"]),
    TodayWeakLimitCase(name: "limit 1", limit: 1, expected: ["t1"]),
    TodayWeakLimitCase(name: "limit 10 → eşiği geçen tümü", limit: 10, expected: ["t1", "t2", "t3", "t4", "t5"]),
    TodayWeakLimitCase(name: "limit 0 → boş", limit: 0, expected: []),
]

@Suite("weakestTopicsForToday")
struct TodayWeakestTopicsTests {
    @Test("limit", arguments: weakLimitCases)
    func limit(_ testCase: TodayWeakLimitCase) {
        let weak =
            testCase.limit.map { TodayCalc.weakestTopics(results: weakResults, limit: $0) }
            ?? TodayCalc.weakestTopics(results: weakResults)
        #expect(weak.map(\.topicId) == testCase.expected.map(uuid))
    }

    @Test("özet tests calc summarize ile aynı")
    func summaryMatchesTestsCalc() {
        let first = TodayCalc.weakestTopics(results: weakResults, limit: 1).first
        let t1Results = weakResults.filter { $0.topicId == uuid("t1") }
        #expect(first?.summary == TestsCalc.summarize(t1Results))
    }

    @Test("boş → boş")
    func empty() {
        #expect(TodayCalc.weakestTopics(results: []).isEmpty)
    }
}

// MARK: - booksInProgress

struct TodayBookLimitCase: Sendable, CustomTestStringConvertible {
    let name: String
    let limit: Int?
    let expected: [String]
    var testDescription: String { name }
}

private let bookLimitCases: [TodayBookLimitCase] = [
    TodayBookLimitCase(
        name: "varsayılan limit 3: önce devam edenler, sonra başlanmamışlar", limit: nil,
        expected: ["p1", "p2", "n1"]),
    TodayBookLimitCase(
        name: "büyük limit: bitmiş/arşivlenmiş hariç tümü, girdi sırası korunur", limit: 10,
        expected: ["p1", "p2", "n1", "n2"]),
    TodayBookLimitCase(name: "limit 1", limit: 1, expected: ["p1"]),
    TodayBookLimitCase(name: "limit 0 → boş", limit: 0, expected: []),
    TodayBookLimitCase(name: "limit negatif → boş", limit: -1, expected: []),
]

@Suite("booksInProgress")
struct TodayBooksInProgressTests {
    private let summaries = [
        bookSummary("completed", .completed),
        bookSummary("n1", .notStarted),
        bookSummary("p1", .inProgress),
        bookSummary("archived", .archived),
        bookSummary("p2", .inProgress),
        bookSummary("n2", .notStarted),
    ]

    @Test("limit", arguments: bookLimitCases)
    func limit(_ testCase: TodayBookLimitCase) {
        let list =
            testCase.limit.map { TodayCalc.booksInProgress(summaries, limit: $0) }
            ?? TodayCalc.booksInProgress(summaries)
        #expect(list.map(\.book.title) == testCase.expected)
    }

    @Test("boş → boş")
    func empty() {
        #expect(TodayCalc.booksInProgress([]).isEmpty)
    }
}
