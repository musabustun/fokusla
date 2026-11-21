import Foundation
import Testing

@testable import FokusDomain

// Kitap hesapları testleri — web `web/src/domain/calc/books.test.ts` ile aynı vakalar (aynı adlar).
//
// Swift'te farklı olanlar:
//  - `totalUnits` / `reachedUnit` `Int`: web'deki NaN, Infinity, -Infinity toplam vakaları
//    ("Swift'te Int: NaN/Infinity vakaları geçersiz") ile ondalıklı birim vakaları
//    ('küçük pozitif' 0.5 toplam, 'ondalıklı birimler korunur') tabloya alınmadı.
//  - Değişmezlik testlerindeki `Object.freeze` karşılığı yoktur: Swift dizileri değer tipidir;
//    testler girdi kopyasının çağrıdan sonra eşit kaldığını doğrular.
//  - Web dize id'leri (`subject-a`) deterministik UUID v5'e çevrilir.

// MARK: - Yardımcılar

private let now = at("2026-11-19T12:00:00.000Z")
private let dayMs = 24.0 * 60 * 60 * 1000
private let windowMs = Double(BooksCalc.paceWindowDays) * dayMs
private let epoch = at("2026-01-01T00:00:00.000Z")

private let testNamespace = UUID(uuidString: "6f1c1e0a-7a53-4b6e-9a53-1d2c3b4a5f60")!

private func uuid(_ name: String) -> UUID {
    Identifiers.uuidV5(name: name, namespace: testNamespace)
}

private func at(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: iso)!
}

/// `now` + ofset (ms).
private func atOffset(_ offsetMs: Double) -> Date {
    Date(timeIntervalSince1970: now.timeIntervalSince1970 + offsetMs / 1000)
}

private func daysAgo(_ days: Double) -> Date {
    atOffset(-days * dayMs)
}

private func book(
    id: UUID = UUID(), title: String = "Kitap", subjectId: UUID? = nil, totalUnits: Int? = 100,
    archivedAt: Date? = nil, updatedAt: Date? = nil, deletedAt: Date? = nil
) -> BookSnapshot {
    BookSnapshot(
        id: id, title: title, kind: .questionBank, subjectId: subjectId, unit: .page,
        totalUnits: totalUnits, archivedAt: archivedAt, createdAt: epoch,
        updatedAt: updatedAt ?? epoch, deletedAt: deletedAt)
}

private func entry(
    bookId: UUID? = nil, reached: Int = 0, recordedAt: Date? = nil, createdAt: Date? = nil,
    deletedAt: Date? = nil
) -> BookProgressSnapshot {
    BookProgressSnapshot(
        id: UUID(), bookId: bookId ?? uuid("book-x"), reachedUnit: reached,
        recordedAt: recordedAt ?? epoch, createdAt: createdAt ?? epoch, deletedAt: deletedAt)
}

/// Kısa yol: `daysBack` gün önce `reached` konumunda kayıt.
private func entryAt(
    _ daysBack: Double, _ reached: Int, createdAt: Date? = nil, deletedAt: Date? = nil
) -> BookProgressSnapshot {
    entry(reached: reached, recordedAt: daysAgo(daysBack), createdAt: createdAt, deletedAt: deletedAt)
}

private func latestEntry(_ reached: Int?) -> BookProgressSnapshot? {
    reached.map { entry(reached: $0) }
}

private func titles(_ summaries: [BooksCalc.BookSummary]) -> [String] {
    summaries.map(\.book.title)
}

// MARK: - knownTotal

private struct KnownTotalCase: Sendable, CustomTestStringConvertible {
    let name: String
    let totalUnits: Int?
    let expected: Int?
    var testDescription: String { "totalUnits=\(name) → \(String(describing: expected))" }
}

private let knownTotalCases: [KnownTotalCase] = [
    KnownTotalCase(name: "null", totalUnits: nil, expected: nil),
    KnownTotalCase(name: "0", totalUnits: 0, expected: nil),
    KnownTotalCase(name: "negatif", totalUnits: -5, expected: nil),
    KnownTotalCase(name: "normal", totalUnits: 320, expected: 320),
]

@Suite("knownTotal")
struct KnownTotalTests {
    @Test("knownTotal", arguments: knownTotalCases)
    fileprivate func knownTotal(_ testCase: KnownTotalCase) {
        #expect(BooksCalc.knownTotal(book(totalUnits: testCase.totalUnits)) == testCase.expected)
    }
}

// MARK: - sortProgressHistory / latestProgress

@Suite("sortProgressHistory / latestProgress")
struct ProgressHistoryTests {
    @Test("boş geçmiş: boş liste ve undefined")
    func emptyHistory() {
        #expect(BooksCalc.sortProgressHistory([]).isEmpty)
        #expect(BooksCalc.latestProgress([]) == nil)
    }

    @Test("en yeni önce sıralar ve silinmişleri atar")
    func sortsNewestFirstAndDropsDeleted() {
        let a = entry(reached: 10, recordedAt: daysAgo(3))
        let b = entry(reached: 30, recordedAt: daysAgo(1))
        let c = entry(reached: 20, recordedAt: daysAgo(2))
        let deleted = entry(reached: 99, recordedAt: daysAgo(0), deletedAt: daysAgo(0))

        let sorted = BooksCalc.sortProgressHistory([a, deleted, b, c])

        #expect(sorted.map(\.id) == [b.id, c.id, a.id])
    }

    @Test("tüm kayıtlar silinmişse latest undefined")
    func allDeletedHasNoLatest() {
        #expect(BooksCalc.latestProgress([entry(deletedAt: daysAgo(1))]) == nil)
    }

    @Test("geri giden ilerlemede en son kayıt kazanır (daha küçük birim olsa da)")
    func latestWinsWhenProgressGoesBackwards() {
        let older = entryAt(5, 80)
        let newer = entryAt(1, 60)
        #expect(BooksCalc.latestProgress([older, newer]) == newer)
        #expect(BooksCalc.latestProgress([newer, older]) == newer)
    }

    @Test("recordedAt eşitliğinde createdAt daha yeni olan kazanır")
    func createdAtBreaksRecordedAtTie() {
        let first = entry(reached: 10, recordedAt: daysAgo(1), createdAt: atOffset(-3000))
        let second = entry(reached: 20, recordedAt: daysAgo(1), createdAt: atOffset(-1000))
        #expect(BooksCalc.latestProgress([first, second]) == second)
        #expect(BooksCalc.latestProgress([second, first]) == second)
    }

    @Test("recordedAt ve createdAt eşitse girdi sırası korunur (kararlı sıralama)")
    func fullTieKeepsInputOrder() {
        let first = entry(reached: 10, recordedAt: daysAgo(1))
        let second = entry(reached: 20, recordedAt: daysAgo(1))
        #expect(BooksCalc.sortProgressHistory([first, second]).map(\.id) == [first.id, second.id])
    }

    @Test("gelecek tarihli kayıtlar latestProgress içinde filtrelenmez")
    func futureEntriesAreNotFilteredByLatest() {
        let past = entryAt(1, 10)
        let future = entry(reached: 50, recordedAt: atOffset(dayMs))
        #expect(BooksCalc.latestProgress([past, future]) == future)
    }

    @Test("girdi dizisini mutasyona uğratmaz")
    func doesNotMutateInput() {
        let input = [entryAt(3, 10), entryAt(1, 30), entryAt(2, 20)]
        let snapshot = input
        _ = BooksCalc.sortProgressHistory(input)
        _ = BooksCalc.latestProgress(input)
        #expect(input == snapshot)
    }
}

// MARK: - progressRatio

private struct RatioCase: Sendable, CustomTestStringConvertible {
    let name: String
    let totalUnits: Int?
    let reached: Int?
    let expected: Double?
    var testDescription: String { name }
}

private let progressRatioCases: [RatioCase] = [
    RatioCase(name: "toplam null → null", totalUnits: nil, reached: 10, expected: nil),
    RatioCase(name: "toplam 0 → null", totalUnits: 0, reached: 10, expected: nil),
    RatioCase(name: "toplam negatif → null", totalUnits: -10, reached: 10, expected: nil),
    RatioCase(name: "kayıt yok → 0", totalUnits: 100, reached: nil, expected: 0),
    RatioCase(name: "yarısı", totalUnits: 200, reached: 50, expected: 0.25),
    RatioCase(name: "tam bitti → 1", totalUnits: 100, reached: 100, expected: 1),
    RatioCase(name: "toplamı aştı → 1 (sınırlı)", totalUnits: 100, reached: 150, expected: 1),
    RatioCase(name: "negatif konum → 0 (sınırlı)", totalUnits: 100, reached: -20, expected: 0),
]

@Suite("progressRatio")
struct ProgressRatioTests {
    @Test("progressRatio", arguments: progressRatioCases)
    fileprivate func progressRatio(_ testCase: RatioCase) {
        let result = BooksCalc.progressRatio(
            book(totalUnits: testCase.totalUnits), latest: latestEntry(testCase.reached))
        #expect(result == testCase.expected)
    }
}

// MARK: - isBookCompleted

private struct CompletedCase: Sendable, CustomTestStringConvertible {
    let name: String
    let totalUnits: Int?
    let reached: Int?
    let expected: Bool
    var testDescription: String { name }
}

private let isBookCompletedCases: [CompletedCase] = [
    CompletedCase(name: "toplam bilinmiyor → asla bitmez", totalUnits: nil, reached: 9999, expected: false),
    CompletedCase(name: "toplam 0 → bitmez", totalUnits: 0, reached: 0, expected: false),
    CompletedCase(name: "toplam negatif → bitmez", totalUnits: -1, reached: 5, expected: false),
    CompletedCase(name: "kayıt yok → bitmez", totalUnits: 100, reached: nil, expected: false),
    CompletedCase(name: "toplamdan az → bitmez", totalUnits: 100, reached: 99, expected: false),
    CompletedCase(name: "tam toplam → biter", totalUnits: 100, reached: 100, expected: true),
    CompletedCase(name: "toplamdan fazla → biter", totalUnits: 100, reached: 130, expected: true),
]

@Suite("isBookCompleted")
struct IsBookCompletedTests {
    @Test("isBookCompleted", arguments: isBookCompletedCases)
    fileprivate func isBookCompleted(_ testCase: CompletedCase) {
        let result = BooksCalc.isBookCompleted(
            book(totalUnits: testCase.totalUnits), latest: latestEntry(testCase.reached))
        #expect(result == testCase.expected)
    }
}

// MARK: - bookStatus

private struct StatusCase: Sendable, CustomTestStringConvertible {
    let name: String
    var totalUnits: Int? = 100
    var archivedAt: Date?
    let reached: Int?
    let expected: BooksCalc.BookStatus
    var testDescription: String { name }
}

private let bookStatusCases: [StatusCase] = {
    let archivedAt = daysAgo(1)
    return [
        StatusCase(name: "kayıt yok → notStarted", reached: nil, expected: .notStarted),
        StatusCase(name: "konum 0 → notStarted", reached: 0, expected: .notStarted),
        StatusCase(name: "konum negatif → notStarted", reached: -3, expected: .notStarted),
        StatusCase(name: "ilerleme var → inProgress", reached: 10, expected: .inProgress),
        StatusCase(
            name: "toplam bilinmiyor, ilerleme var → inProgress (asla completed değil)",
            totalUnits: nil, reached: 500, expected: .inProgress),
        StatusCase(name: "toplama ulaştı → completed", reached: 100, expected: .completed),
        StatusCase(name: "toplamı aştı → completed", reached: 120, expected: .completed),
        StatusCase(
            name: "arşivli, bitmemiş → archived", archivedAt: archivedAt, reached: 10,
            expected: .archived),
        StatusCase(
            name: "arşivli, kayıt yok → archived (notStarted’tan önce)", archivedAt: archivedAt,
            reached: nil, expected: .archived),
        StatusCase(
            name: "arşivli ve bitmiş → completed arşivlinin önüne geçer", archivedAt: archivedAt,
            reached: 100, expected: .completed),
    ]
}()

@Suite("bookStatus")
struct BookStatusTests {
    @Test("bookStatus", arguments: bookStatusCases)
    fileprivate func bookStatus(_ testCase: StatusCase) {
        let result = BooksCalc.bookStatus(
            book(totalUnits: testCase.totalUnits, archivedAt: testCase.archivedAt),
            latest: latestEntry(testCase.reached))
        #expect(result == testCase.expected)
    }
}

// MARK: - weeklyPace

private struct PaceCase: Sendable, CustomTestStringConvertible {
    let name: String
    let entries: [BookProgressSnapshot]
    let expected: Double?
    var testDescription: String { name }
}

private let weeklyPaceCases: [PaceCase] = [
    PaceCase(name: "boş geçmiş → null", entries: [], expected: nil),
    PaceCase(name: "pencere içinde tek kayıt → null", entries: [entryAt(2, 40)], expected: nil),
    PaceCase(
        name: "yalnızca silinmiş kayıtlar → null",
        entries: [entryAt(2, 40, deletedAt: daysAgo(1)), entryAt(3, 10, deletedAt: daysAgo(1))],
        expected: nil),
    PaceCase(
        name: "yalnızca gelecek tarihli kayıt → null",
        entries: [entry(reached: 50, recordedAt: atOffset(dayMs))], expected: nil),
    PaceCase(
        name: "pencere öncesi kayıt + pencere içi kayıt → fark",
        entries: [entryAt(10, 50), entryAt(2, 80)], expected: 30),
    PaceCase(
        name: "pencere öncesi baseline: en son (pencereye en yakın) olan seçilir",
        entries: [entryAt(20, 10), entryAt(9, 40), entryAt(2, 70)], expected: 30),
    PaceCase(
        name: "pencere öncesi tek kayıt, pencerede kayıt yok → 0 (durmuş)",
        entries: [entryAt(10, 50)], expected: 0),
    PaceCase(
        name: "pencere öncesi birden fazla kayıt, pencerede yok → 0",
        entries: [entryAt(20, 10), entryAt(10, 50)], expected: 0),
    PaceCase(
        name: "tam now−7g kayıt baseline sayılır (pencere öncesi)",
        entries: [entry(reached: 10, recordedAt: atOffset(-windowMs)), entryAt(3, 20)],
        expected: 10),
    PaceCase(
        name: "tam now−7g tek kayıt: baseline = bitiş → 0",
        entries: [entry(reached: 10, recordedAt: atOffset(-windowMs))], expected: 0),
    PaceCase(
        name: "now−7g−1ms kayıt baseline sayılır",
        entries: [entry(reached: 10, recordedAt: atOffset(-windowMs - 1)), entryAt(3, 25)],
        expected: 15),
    PaceCase(
        name: "now−7g+1ms kayıt pencere içidir: tek kayıt → null",
        entries: [entry(reached: 10, recordedAt: atOffset(-windowMs + 1))], expected: nil),
    PaceCase(
        name: "öncesi yoksa pencere içindeki en eski kayıt baseline",
        entries: [entryAt(5, 20), entryAt(3, 35), entryAt(1, 50)], expected: 30),
    PaceCase(
        name: "geri giden ilerleme negatif hız üretmez",
        entries: [entryAt(10, 100), entryAt(1, 80)], expected: 0),
    PaceCase(
        name: "geri giden ilerleme (pencere içi) negatif hız üretmez",
        entries: [entryAt(5, 90), entryAt(1, 40)], expected: 0),
    PaceCase(
        name: "gelecek tarihli kayıt bitiş noktası olmaz",
        entries: [entryAt(10, 50), entry(reached: 500, recordedAt: atOffset(dayMs)), entryAt(1, 70)],
        expected: 20),
    PaceCase(
        name: "tam now anındaki kayıt bitiş noktası sayılır",
        entries: [entryAt(3, 10), entry(reached: 30, recordedAt: now)], expected: 20),
    PaceCase(
        name: "silinmiş kayıtlar baseline/bitiş olmaz",
        entries: [entryAt(10, 50), entryAt(2, 60), entryAt(1, 500, deletedAt: daysAgo(0))],
        expected: 10),
    PaceCase(
        name: "recordedAt eşitliğinde createdAt’i yeni olan bitiş noktasıdır",
        entries: [
            entryAt(3, 10),
            entryAt(1, 30, createdAt: atOffset(-2000)),
            entryAt(1, 40, createdAt: atOffset(-1000)),
        ],
        expected: 30),
]

@Suite("weeklyPace")
struct WeeklyPaceTests {
    @Test("weeklyPace", arguments: weeklyPaceCases)
    fileprivate func weeklyPace(_ testCase: PaceCase) {
        #expect(BooksCalc.weeklyPace(testCase.entries, now: now) == testCase.expected)
    }

    @Test("girdi dizisini mutasyona uğratmaz")
    func doesNotMutateInput() {
        let input = [entryAt(1, 70), entryAt(10, 50), entryAt(3, 60)]
        let snapshot = input
        #expect(BooksCalc.weeklyPace(input, now: now) == 20)
        #expect(input == snapshot)
    }

    @Test("PACE_WINDOW_DAYS 7’dir")
    func paceWindowIsSevenDays() {
        #expect(BooksCalc.paceWindowDays == 7)
    }
}

// MARK: - estimateDaysToFinish

private struct EstimateCase: Sendable, CustomTestStringConvertible {
    let name: String
    let totalUnits: Int?
    let reached: Int?
    let pace: Double?
    let expected: Int?
    var testDescription: String { name }
}

private let estimateCases: [EstimateCase] = [
    EstimateCase(name: "toplam null → null", totalUnits: nil, reached: 10, pace: 14, expected: nil),
    EstimateCase(name: "toplam 0 → null", totalUnits: 0, reached: 0, pace: 14, expected: nil),
    EstimateCase(name: "toplam negatif → null", totalUnits: -5, reached: 0, pace: 14, expected: nil),
    EstimateCase(
        name: "tam bitti → 0 (hız null olsa da)", totalUnits: 100, reached: 100, pace: nil,
        expected: 0),
    EstimateCase(name: "toplamı aştı → 0", totalUnits: 100, reached: 130, pace: 0, expected: 0),
    EstimateCase(name: "hız null → null", totalUnits: 100, reached: 70, pace: nil, expected: nil),
    EstimateCase(name: "hız 0 → null", totalUnits: 100, reached: 70, pace: 0, expected: nil),
    EstimateCase(name: "hız negatif → null", totalUnits: 100, reached: 70, pace: -4, expected: nil),
    EstimateCase(
        name: "tam bölünür: 30 / (7/7)", totalUnits: 100, reached: 70, pace: 7, expected: 30),
    EstimateCase(
        name: "yukarı yuvarlanır: 30 / (20/7) = 10.5 → 11", totalUnits: 100, reached: 70, pace: 20,
        expected: 11),
    EstimateCase(
        name: "tam gün: 30 / (10/7) = 21", totalUnits: 100, reached: 70, pace: 10, expected: 21),
    EstimateCase(
        name: "çok küçük kalan bile 1 gün", totalUnits: 100, reached: 99, pace: 700, expected: 1),
    EstimateCase(
        name: "kayıt yoksa konum 0 sayılır", totalUnits: 100, reached: nil, pace: 14, expected: 50),
]

@Suite("estimateDaysToFinish")
struct EstimateDaysToFinishTests {
    @Test("estimateDaysToFinish", arguments: estimateCases)
    fileprivate func estimate(_ testCase: EstimateCase) {
        let result = BooksCalc.estimateDaysToFinish(
            book: book(totalUnits: testCase.totalUnits), latest: latestEntry(testCase.reached),
            pacePerWeek: testCase.pace)
        #expect(result == testCase.expected)
    }
}

// MARK: - summarizeBook

@Suite("summarizeBook")
struct SummarizeBookTests {
    @Test("geçmişi boş kitap: varsayılan değerler")
    func emptyHistoryDefaults() {
        let b = book(totalUnits: 100, updatedAt: daysAgo(4))

        let s = BooksCalc.summarizeBook(b, entries: [], now: now)

        #expect(
            s
                == BooksCalc.BookSummary(
                    book: b, latest: nil, reachedUnit: 0, ratio: 0, status: .notStarted,
                    lastProgressAt: nil, weeklyPace: nil, daysToFinish: nil, activityAt: b.updatedAt))
        #expect(s.id == b.id)
    }

    @Test("toplamı bilinmeyen kitap: ratio ve daysToFinish null, status inProgress")
    func unknownTotal() {
        let s = BooksCalc.summarizeBook(
            book(totalUnits: nil), entries: [entryAt(10, 20), entryAt(1, 50)], now: now)

        #expect(s.ratio == nil)
        #expect(s.daysToFinish == nil)
        #expect(s.status == .inProgress)
        #expect(s.weeklyPace == 30)
    }

    @Test("tüm alanları birlikte hesaplar")
    func computesAllFieldsTogether() {
        let b = book(totalUnits: 100, updatedAt: daysAgo(30))
        let older = entryAt(10, 40)
        let latest = entryAt(1, 70)

        let s = BooksCalc.summarizeBook(b, entries: [older, latest], now: now)

        #expect(s.latest == latest)
        #expect(s.reachedUnit == 70)
        #expect(s.ratio == 0.7)
        #expect(s.status == .inProgress)
        #expect(s.lastProgressAt == latest.recordedAt)
        #expect(s.weeklyPace == 30)
        #expect(s.daysToFinish == 7)  // 30 kalan / (30/7 per gün) = 7
        #expect(s.activityAt == latest.recordedAt)
    }

    @Test("toplamı aşan konum: ratio 1, completed, daysToFinish 0")
    func overshootingPosition() {
        let s = BooksCalc.summarizeBook(book(totalUnits: 100), entries: [entryAt(1, 150)], now: now)

        #expect(s.ratio == 1)
        #expect(s.status == .completed)
        #expect(s.daysToFinish == 0)
    }

    @Test("activityAt: book.updatedAt daha yeniyse onu kullanır")
    func activityUsesNewerBookUpdate() {
        let b = book(updatedAt: daysAgo(1))
        let s = BooksCalc.summarizeBook(b, entries: [entryAt(5, 10)], now: now)
        #expect(s.activityAt == b.updatedAt)
    }

    @Test("activityAt: son ilerleme daha yeniyse onu kullanır")
    func activityUsesNewerProgress() {
        let b = book(updatedAt: daysAgo(9))
        let latest = entryAt(2, 10)
        let s = BooksCalc.summarizeBook(b, entries: [latest], now: now)
        #expect(s.activityAt == latest.recordedAt)
    }

    @Test("activityAt: eşitse ikisi de aynı değeri verir")
    func activityWhenEqual() {
        let b = book(updatedAt: daysAgo(2))
        let s = BooksCalc.summarizeBook(b, entries: [entryAt(2, 10)], now: now)
        #expect(s.activityAt == daysAgo(2))
    }

    @Test("silinmiş kayıtlar yok sayılır")
    func ignoresDeletedEntries() {
        let live = entryAt(3, 20)
        let deleted = entryAt(1, 90, deletedAt: daysAgo(0))
        let s = BooksCalc.summarizeBook(book(updatedAt: daysAgo(30)), entries: [live, deleted], now: now)

        #expect(s.latest == live)
        #expect(s.reachedUnit == 20)
        #expect(s.activityAt == live.recordedAt)
    }

    @Test("gelecek tarihli kayıt latest/activityAt’i etkiler ama hıza girmez")
    func futureEntryAffectsLatestButNotPace() {
        let past = entryAt(10, 50)
        let mid = entryAt(1, 60)
        let future = entry(reached: 90, recordedAt: atOffset(2 * dayMs))

        let s = BooksCalc.summarizeBook(
            book(updatedAt: daysAgo(30)), entries: [past, mid, future], now: now)

        #expect(s.latest == future)
        #expect(s.reachedUnit == 90)
        #expect(s.activityAt == future.recordedAt)
        #expect(s.weeklyPace == 10)
    }

    @Test("girdileri mutasyona uğratmaz")
    func doesNotMutateInputs() {
        let b = book()
        let entries = [entryAt(5, 10), entryAt(1, 30)]
        let snapshot = entries
        _ = BooksCalc.summarizeBook(b, entries: entries, now: now)
        #expect(entries == snapshot)
    }
}

// MARK: - summarizeBooks

@Suite("summarizeBooks")
struct SummarizeBooksTests {
    @Test("boş girdi → boş liste")
    func emptyInput() {
        #expect(BooksCalc.summarizeBooks([], progress: [], now: now).isEmpty)
    }

    @Test("silinmiş kitapları atar, kayıtsız kitabı tutar")
    func dropsDeletedBooksKeepsEmptyOnes() {
        let live = book(title: "Canlı")
        let gone = book(title: "Silinmiş", deletedAt: daysAgo(1))

        let result = BooksCalc.summarizeBooks([live, gone], progress: [], now: now)

        #expect(result.map(\.book.id) == [live.id])
    }

    @Test("eşleşmeyen (yetim) ve başka kitaba ait kayıtları yok sayar")
    func ignoresOrphanAndForeignEntries() {
        let a = book(title: "A")
        let b = book(title: "B")
        let forA = entry(bookId: a.id, reached: 30, recordedAt: daysAgo(2))
        let forB = entry(bookId: b.id, reached: 60, recordedAt: daysAgo(3))
        let orphan = entry(bookId: uuid("yok-boyle-kitap"), reached: 99, recordedAt: daysAgo(0))
        let unlinked = BookProgressSnapshot(
            id: UUID(), bookId: nil, reachedUnit: 77, recordedAt: daysAgo(0), createdAt: epoch)

        let result = BooksCalc.summarizeBooks(
            [a, b], progress: [forA, forB, orphan, unlinked], now: now)
        let byId = Dictionary(uniqueKeysWithValues: result.map { ($0.book.id, $0) })

        #expect(byId[a.id]?.reachedUnit == 30)
        #expect(byId[b.id]?.reachedUnit == 60)
        #expect(result.count == 2)
    }

    @Test("silinmiş kitabın kayıtları başka kitaplara sızmaz")
    func deletedBookEntriesDoNotLeak() {
        let live = book()
        let gone = book(deletedAt: daysAgo(1))
        let goneEntry = entry(bookId: gone.id, reached: 50, recordedAt: daysAgo(1))

        let result = BooksCalc.summarizeBooks([live, gone], progress: [goneEntry], now: now)

        #expect(result.count == 1)
        #expect(result.first?.latest == nil)
    }

    @Test("silinmiş ilerleme kayıtları sayılmaz")
    func deletedProgressIsNotCounted() {
        let b = book()
        let e = entry(bookId: b.id, reached: 50, recordedAt: daysAgo(1), deletedAt: daysAgo(0))

        let result = BooksCalc.summarizeBooks([b], progress: [e], now: now)

        #expect(result.first?.status == .notStarted)
        #expect(result.first?.lastProgressAt == nil)
    }

    @Test("activityAt’e göre yeni → eski sıralar")
    func sortsByActivityNewestFirst() {
        let old = book(title: "Eski", updatedAt: daysAgo(20))
        let mid = book(title: "Orta", updatedAt: daysAgo(10))
        let fresh = book(title: "Yeni", updatedAt: daysAgo(30))
        // "Yeni" kitabın son ilerlemesi en taze → en üste çıkar.
        let freshEntry = entry(bookId: fresh.id, reached: 5, recordedAt: daysAgo(1))

        let result = BooksCalc.summarizeBooks([old, mid, fresh], progress: [freshEntry], now: now)

        #expect(titles(result) == ["Yeni", "Orta", "Eski"])
    }

    @Test("eşit activityAt’te başlığa göre tr-TR alfabetik")
    func titleTieBreakUsesTurkishAlphabet() {
        let same = daysAgo(2)
        let books = ["Zeka", "İpek", "ışık", "Cebir", "Çözüm"].map {
            book(title: $0, updatedAt: same)
        }

        let result = BooksCalc.summarizeBooks(books, progress: [], now: now)

        // tr-TR: c < ç < ı < i < İ... ('ışık' < 'İpek'), z sonda
        #expect(titles(result) == ["Cebir", "Çözüm", "ışık", "İpek", "Zeka"])
    }

    @Test("eşit activityAt ve eşit başlıkta girdi sırası korunur (kararlı sıralama)")
    func equalTitlesKeepInputOrder() {
        let same = daysAgo(2)
        let first = book(title: "Aynı", updatedAt: same)
        let second = book(title: "Aynı", updatedAt: same)

        let result = BooksCalc.summarizeBooks([first, second], progress: [], now: now)

        #expect(result.map(\.book.id) == [first.id, second.id])
    }

    @Test("girdi dizilerini mutasyona uğratmaz")
    func doesNotMutateInputs() {
        let a = book(title: "A", updatedAt: daysAgo(5))
        let b = book(title: "B", updatedAt: daysAgo(1))
        let books = [a, b]
        let progress = [entry(bookId: a.id, reached: 1, recordedAt: daysAgo(2))]

        let result = BooksCalc.summarizeBooks(books, progress: progress, now: now)

        #expect(result.map(\.book.id) == [b.id, a.id])
        #expect(books == [a, b])
    }
}

// MARK: - isFinished / splitByFinished

private struct FinishedCase: Sendable, CustomTestStringConvertible {
    let status: BooksCalc.BookStatus
    let expected: Bool
    var testDescription: String { "isFinished(\(status.rawValue)) = \(expected)" }
}

private let finishedCases: [FinishedCase] = [
    FinishedCase(status: .notStarted, expected: false),
    FinishedCase(status: .inProgress, expected: false),
    FinishedCase(status: .completed, expected: true),
    FinishedCase(status: .archived, expected: true),
]

private func summaryWithStatus(_ status: BooksCalc.BookStatus) -> BooksCalc.BookSummary {
    let archivedAt: Date? = status == .archived ? daysAgo(1) : nil
    let reached: Int =
        switch status {
        case .notStarted: 0
        case .inProgress: 10
        case .completed: 100
        case .archived: 10
        }
    let b = book(title: status.rawValue, archivedAt: archivedAt)
    return BooksCalc.summarizeBook(b, entries: reached > 0 ? [entryAt(1, reached)] : [], now: now)
}

@Suite("isFinished / splitByFinished")
struct FinishedTests {
    @Test("isFinished", arguments: finishedCases)
    fileprivate func isFinished(_ testCase: FinishedCase) {
        #expect(BooksCalc.isFinished(summaryWithStatus(testCase.status)) == testCase.expected)
    }

    @Test("boş girdi → iki boş liste")
    func emptyInput() {
        let result = BooksCalc.splitByFinished([])
        #expect(result.active.isEmpty)
        #expect(result.finished.isEmpty)
    }

    @Test("devam edenleri ve bitenleri ayırır, girdi sırasını korur")
    func splitsKeepingInputOrder() {
        let s1 = summaryWithStatus(.inProgress)
        let s2 = summaryWithStatus(.completed)
        let s3 = summaryWithStatus(.notStarted)
        let s4 = summaryWithStatus(.archived)

        let result = BooksCalc.splitByFinished([s1, s2, s3, s4])

        #expect(result.active == [s1, s3])
        #expect(result.finished == [s2, s4])
    }
}

// MARK: - groupBySubject

private let subjectA = uuid("subject-a")
private let subjectB = uuid("subject-b")

private func summary(
    _ title: String, _ subjectId: UUID?, _ updatedDaysAgo: Double
) -> BooksCalc.BookSummary {
    BooksCalc.summarizeBook(
        book(title: title, subjectId: subjectId, updatedAt: daysAgo(updatedDaysAgo)), entries: [],
        now: now)
}

@Suite("groupBySubject")
struct GroupBySubjectTests {
    @Test("boş girdi → boş liste")
    func emptyInput() {
        #expect(BooksCalc.groupBySubject([]).isEmpty)
    }

    @Test("dersleri en yeni etkinliğe göre sıralar; dersi olmayan grup her zaman sonda")
    func ordersGroupsAndKeepsUnassignedLast() {
        let none1 = summary("Dersiz-1", nil, 0)  // en taze ama null grubu sonda
        let a1 = summary("A-1", subjectA, 5)
        let a2 = summary("A-2", subjectA, 9)
        let b1 = summary("B-1", subjectB, 2)
        let none2 = summary("Dersiz-2", nil, 7)

        let groups = BooksCalc.groupBySubject([none1, a1, a2, b1, none2])

        #expect(groups.map(\.subjectId) == [subjectB, subjectA, nil])
    }

    @Test("grup içi sıra activityAt yeni → eski")
    func ordersWithinGroup() {
        let a1 = summary("A-eski", subjectA, 9)
        let a2 = summary("A-yeni", subjectA, 1)
        let a3 = summary("A-orta", subjectA, 5)
        let n1 = summary("N-eski", nil, 8)
        let n2 = summary("N-yeni", nil, 3)

        let groups = BooksCalc.groupBySubject([a1, n1, a2, n2, a3])

        #expect(groups.count == 2)
        #expect(groups.first.map { titles($0.books) } == ["A-yeni", "A-orta", "A-eski"])
        #expect(groups.last?.subjectId == nil)
        #expect(groups.last.map { titles($0.books) } == ["N-yeni", "N-eski"])
    }

    @Test("yalnızca dersi olmayan kitaplar → tek null grup")
    func onlyUnassignedBooks() {
        let groups = BooksCalc.groupBySubject([summary("X", nil, 1), summary("Y", nil, 2)])
        #expect(groups.map(\.subjectId) == [nil])
        #expect(groups.first?.books.count == 2)
    }

    @Test("eşit activityAt’te başlık tr-TR sırası uygulanır")
    func titleTieBreakWithinGroup() {
        let z = summary("Zeka", subjectA, 3)
        let c = summary("Cebir", subjectA, 3)
        let groups = BooksCalc.groupBySubject([z, c])
        #expect(groups.first.map { titles($0.books) } == ["Cebir", "Zeka"])
    }

    @Test("girdi dizisini mutasyona uğratmaz")
    func doesNotMutateInput() {
        let first = summary("Eski", subjectA, 9)
        let second = summary("Yeni", subjectA, 1)
        let input = [first, second]

        let groups = BooksCalc.groupBySubject(input)

        #expect(groups.first.map { titles($0.books) } == ["Yeni", "Eski"])
        #expect(input == [first, second])
    }
}
