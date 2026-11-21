import Foundation

/// Kitap ilerleme hesapları — SAF fonksiyonlar (SwiftUI/SwiftData yok). Web
/// `web/src/domain/calc/books.ts` karşılığı.
///
/// Ortak kurallar (web ile birebir aynıdır):
///  - Hiçbir fonksiyon saati okumaz; "şimdi" gereken yerde `now: Date` parametre olarak gelir.
///  - Girdiler mutasyona uğramaz; sıralama gereken yerde kopya sıralanır. Sıralamalar KARARLIDIR
///    (eşit anahtarlı öğeler girdi sırasını korur).
///  - Soft-delete edilmiş kayıtlar (`deletedAt != nil`) her hesapta yok sayılır.
///  - Türetilmiş değerler (yüzde, hız, tahmini bitiş) SAKLANMAZ; her seferinde buradan hesaplanır.
///  - Zaman damgaları web'deki gibi tam milisaniyeye yuvarlanarak karşılaştırılır.
public enum BooksCalc {
    /// Hız penceresi: son 7 gün.
    public static let paceWindowDays = 7

    private static let dayMs = 24.0 * 60 * 60 * 1000
    private static let turkish = Locale(identifier: "tr_TR")

    /// Kitabın türetilmiş durumu.
    public enum BookStatus: String, Sendable, Equatable, CaseIterable {
        /// Hiç ilerleme yok (ya da en son konum ≤ 0).
        case notStarted
        /// İlerleme var, bitmedi, arşivde değil.
        case inProgress
        /// Toplam biliniyor (> 0) ve en son konum ≥ toplam (arşivde olsa da `completed`).
        case completed
        /// Bitmeden rafa kaldırıldı (`archivedAt != nil`).
        case archived
    }

    /// Liste ve detay ekranlarının kullandığı, tek kitap için hesaplanmış özet.
    public struct BookSummary: Sendable, Equatable, Identifiable {
        /// Özetlenen kitap.
        public var book: BookSnapshot
        /// En son ilerleme kaydı; yoksa nil.
        public var latest: BookProgressSnapshot?
        /// Ulaşılan birim; kayıt yoksa 0.
        public var reachedUnit: Int
        /// 0–1 ilerleme oranı (sınırlanmış); toplam bilinmiyorsa (nil ya da ≤ 0) nil.
        public var ratio: Double?
        /// Türetilmiş durum.
        public var status: BookStatus
        /// Son ilerleme kaydının zamanı; yoksa nil.
        public var lastProgressAt: Date?
        /// Son 7 gündeki ilerleme (birim/hafta); veri yetersizse nil. Bkz. ``weeklyPace(_:now:)``.
        public var weeklyPace: Double?
        /// Bu hızla bitişe kalan gün; bkz. ``estimateDaysToFinish(book:latest:pacePerWeek:)``.
        public var daysToFinish: Int?
        /// Sıralama anahtarı: max(book.updatedAt, son ilerleme zamanı).
        public var activityAt: Date

        /// Kitabın kimliği.
        public var id: UUID { book.id }

        /// Tüm alanlarla oluşturur.
        public init(
            book: BookSnapshot, latest: BookProgressSnapshot?, reachedUnit: Int, ratio: Double?,
            status: BookStatus, lastProgressAt: Date?, weeklyPace: Double?, daysToFinish: Int?,
            activityAt: Date
        ) {
            self.book = book
            self.latest = latest
            self.reachedUnit = reachedUnit
            self.ratio = ratio
            self.status = status
            self.lastProgressAt = lastProgressAt
            self.weeklyPace = weeklyPace
            self.daysToFinish = daysToFinish
            self.activityAt = activityAt
        }
    }

    /// Derse göre bir grup (`subjectId == nil` → "ders seçilmedi" grubu).
    public struct BookGroup: Sendable, Equatable {
        /// Grubun dersi; ders seçilmemiş kitaplar için nil.
        public var subjectId: UUID?
        /// Gruptaki kitap özetleri (activityAt yeni → eski).
        public var books: [BookSummary]

        /// Dersi ve kitap özetlerini verir.
        public init(subjectId: UUID?, books: [BookSummary]) {
            self.subjectId = subjectId
            self.books = books
        }
    }

    // MARK: - Yardımcılar

    /// Anın epoch milisaniyesi (tam ms'ye yuvarlanır).
    private static func toMs(_ date: Date) -> Double {
        (date.timeIntervalSince1970 * 1000).rounded()
    }

    /// Kararlı sıralama: karşılaştırıcı `.orderedSame` derse girdi sırası korunur.
    private static func stableSorted<T>(
        _ items: [T], by compare: (T, T) -> ComparisonResult
    ) -> [T] {
        items.enumerated().sorted { lhs, rhs in
            switch compare(lhs.element, rhs.element) {
            case .orderedAscending: true
            case .orderedDescending: false
            case .orderedSame: lhs.offset < rhs.offset
            }
        }.map(\.element)
    }

    private static func compareDescending(_ lhs: Double, _ rhs: Double) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        return lhs > rhs ? .orderedAscending : .orderedDescending
    }

    /// recordedAt'e göre yeni → eski; eşitlikte createdAt'e göre yeni → eski.
    private static func compareNewestFirst(
        _ lhs: BookProgressSnapshot, _ rhs: BookProgressSnapshot
    ) -> ComparisonResult {
        let byRecorded = compareDescending(toMs(lhs.recordedAt), toMs(rhs.recordedAt))
        if byRecorded != .orderedSame { return byRecorded }
        return compareDescending(toMs(lhs.createdAt), toMs(rhs.createdAt))
    }

    // MARK: - Geçmiş

    /// Silinmemiş kayıtlar, en yeni önce (geçmiş listesi için). Girdi değişmez.
    /// Sıralama: `recordedAt` yeni → eski; eşitlikte `createdAt` yeni → eski.
    public static func sortProgressHistory(
        _ entries: [BookProgressSnapshot]
    ) -> [BookProgressSnapshot] {
        stableSorted(entries.filter { $0.deletedAt == nil }, by: compareNewestFirst)
    }

    /// En son ilerleme kaydı (`recordedAt`'e göre; eşitlikte en son oluşturulan); yoksa nil.
    /// Gelecek tarihli kayıtlar FİLTRELENMEZ (yalnızca hız hesabı onları yok sayar).
    public static func latestProgress(_ entries: [BookProgressSnapshot]) -> BookProgressSnapshot? {
        sortProgressHistory(entries).first
    }

    // MARK: - Toplam, oran, durum

    /// Geçerli toplam; nil, 0 ve negatif değerler "bilinmiyor" (nil) sayılır.
    public static func knownTotal(_ book: BookSnapshot) -> Int? {
        guard let total = book.totalUnits, total > 0 else { return nil }
        return total
    }

    /// İlerleme oranı (0–1, sınırlanmış). Toplam bilinmiyorsa nil; kayıt yoksa 0.
    public static func progressRatio(_ book: BookSnapshot, latest: BookProgressSnapshot?) -> Double? {
        guard let total = knownTotal(book) else { return nil }
        let reached = latest?.reachedUnit ?? 0
        return Swift.min(1, Swift.max(0, Double(reached) / Double(total)))
    }

    /// Toplam biliniyor ve en son konum toplama ulaştı/aştı mı?
    public static func isBookCompleted(_ book: BookSnapshot, latest: BookProgressSnapshot?) -> Bool {
        guard let total = knownTotal(book), let latest else { return false }
        return latest.reachedUnit >= total
    }

    /// Türetilmiş durum; öncelik: completed > archived > notStarted > inProgress.
    public static func bookStatus(_ book: BookSnapshot, latest: BookProgressSnapshot?) -> BookStatus {
        if isBookCompleted(book, latest: latest) { return .completed }
        if book.archivedAt != nil { return .archived }
        guard let latest, latest.reachedUnit > 0 else { return .notStarted }
        return .inProgress
    }

    // MARK: - Hız ve tahmin

    /// Son 7 gündeki ilerleme (birim/hafta), pencere = (now − 7 gün, now].
    ///
    ///  - Bitiş noktası: `now` anında veya öncesindeki en son kayıt (gelecek tarihli kayıtlar yok sayılır).
    ///  - Başlangıç noktası: pencere başlangıcında veya öncesindeki en son kayıt; yoksa pencere
    ///    içindeki en eski kayıt (ilk kayıt "takibe başladığım yer" sayılır, sıfırdan değil).
    ///  - Pencerede hiç kayıt yoksa ama öncesinde varsa: 0 (durmuş).
    ///  - Hiç kullanılabilir kayıt yoksa ya da yalnızca tek kayıt varsa: nil (hız hesaplanamaz).
    ///  - Geri giden ilerleme (düzeltme) negatif hız üretmez: sonuç en az 0.
    public static func weeklyPace(_ entries: [BookProgressSnapshot], now: Date) -> Double? {
        let nowMs = toMs(now)
        let windowStartMs = nowMs - Double(paceWindowDays) * dayMs
        let usable = sortProgressHistory(entries).filter { toMs($0.recordedAt) <= nowMs }
        guard let end = usable.first else { return nil }

        let beforeWindow = usable.first { toMs($0.recordedAt) <= windowStartMs }
        guard let start = beforeWindow ?? usable.dropFirst().last else { return nil }
        return Double(Swift.max(0, end.reachedUnit - start.reachedUnit))
    }

    /// Bu hızla bitişe kalan gün (yukarı yuvarlanır).
    ///  - Toplam bilinmiyorsa nil.
    ///  - Kitap bitmişse (kalan ≤ 0) 0 (hız nil olsa da).
    ///  - Hız nil ya da ≤ 0 ise nil.
    public static func estimateDaysToFinish(
        book: BookSnapshot, latest: BookProgressSnapshot?, pacePerWeek: Double?
    ) -> Int? {
        guard let total = knownTotal(book) else { return nil }
        let remaining = total - (latest?.reachedUnit ?? 0)
        if remaining <= 0 { return 0 }
        guard let pacePerWeek, pacePerWeek > 0 else { return nil }
        return Int((Double(remaining) / (pacePerWeek / Double(paceWindowDays))).rounded(.up))
    }

    // MARK: - Özetler

    /// Tek kitap için tüm türetilmiş değerler. `entries` bu kitabın kayıtlarıdır (bookId filtreli).
    public static func summarizeBook(
        _ book: BookSnapshot, entries: [BookProgressSnapshot], now: Date
    ) -> BookSummary {
        let latest = latestProgress(entries)
        let pace = weeklyPace(entries, now: now)
        let lastProgressAt = latest?.recordedAt
        let activityAt: Date =
            if let lastProgressAt, toMs(lastProgressAt) > toMs(book.updatedAt) {
                lastProgressAt
            } else {
                book.updatedAt
            }
        return BookSummary(
            book: book,
            latest: latest,
            reachedUnit: latest?.reachedUnit ?? 0,
            ratio: progressRatio(book, latest: latest),
            status: bookStatus(book, latest: latest),
            lastProgressAt: lastProgressAt,
            weeklyPace: pace,
            daysToFinish: estimateDaysToFinish(book: book, latest: latest, pacePerWeek: pace),
            activityAt: activityAt
        )
    }

    /// activityAt'e göre yeni → eski; eşitlikte başlığa göre (tr-TR) alfabetik.
    private static func compareByActivity(_ lhs: BookSummary, _ rhs: BookSummary) -> ComparisonResult {
        let byActivity = compareDescending(toMs(lhs.activityAt), toMs(rhs.activityAt))
        if byActivity != .orderedSame { return byActivity }
        return lhs.book.title.compare(rhs.book.title, options: [], range: nil, locale: turkish)
    }

    /// Tüm kitapların özetleri, son etkinlik en üstte (eşitlikte başlığa göre tr-TR alfabetik).
    /// Silinmiş kitaplar hariç; ilerleme kayıtları `bookId` ile eşlenir (bookId'si nil olan ya da
    /// hiçbir kitapla eşleşmeyen kayıtlar yok sayılır).
    public static func summarizeBooks(
        _ books: [BookSnapshot], progress: [BookProgressSnapshot], now: Date
    ) -> [BookSummary] {
        var byBook: [UUID: [BookProgressSnapshot]] = [:]
        for entry in progress {
            guard let bookId = entry.bookId else { continue }
            byBook[bookId, default: []].append(entry)
        }
        let summaries = books
            .filter { $0.deletedAt == nil }
            .map { summarizeBook($0, entries: byBook[$0.id] ?? [], now: now) }
        return stableSorted(summaries, by: compareByActivity)
    }

    /// Bitti mi (tamamlandı ya da arşivlendi)? "Bitenler" sekmesi bunu kullanır.
    public static func isFinished(_ summary: BookSummary) -> Bool {
        summary.status == .completed || summary.status == .archived
    }

    /// Devam eden / bitenler ayrımı; her liste girdi sırasını korur.
    public static func splitByFinished(
        _ summaries: [BookSummary]
    ) -> (active: [BookSummary], finished: [BookSummary]) {
        (
            active: summaries.filter { !isFinished($0) },
            finished: summaries.filter { isFinished($0) }
        )
    }

    /// Derse göre gruplar. Gruplar en yeni etkinliklerine göre sıralanır; ders seçilmemiş
    /// (`subjectId == nil`) grup her zaman en sondadır. Grup içi sıra: activityAt yeni → eski.
    public static func groupBySubject(_ summaries: [BookSummary]) -> [BookGroup] {
        var groups: [BookGroup] = []
        for summary in stableSorted(summaries, by: compareByActivity) {
            let key = summary.book.subjectId
            if let index = groups.firstIndex(where: { $0.subjectId == key }) {
                groups[index].books.append(summary)
            } else {
                groups.append(BookGroup(subjectId: key, books: [summary]))
            }
        }
        return groups.filter { $0.subjectId != nil } + groups.filter { $0.subjectId == nil }
    }
}
