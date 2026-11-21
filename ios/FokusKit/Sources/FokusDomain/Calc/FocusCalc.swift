import Foundation

/// Odak hesapları — SAF fonksiyonlar (SwiftUI/SwiftData yok). Web `web/src/domain/calc/focus.ts` karşılığı.
///
/// Ortak kurallar (web ile birebir aynıdır):
///  - Birim: milisaniye (`Double`). Tüm süreler `startedAt/endedAt` farkından hesaplanır.
///    Zaman damgaları web'deki gibi tam milisaniyeye yuvarlanarak okunur.
///  - Açık segment (`endedAt == nil`) `now` anında kapanmış sayılır.
///  - Negatif süre üretilmez: `endedAt < startedAt` (saat kayması) ya da `now < startedAt` → 0.
///  - `deletedAt != nil` olan oturum/segmentler her fonksiyonda yok sayılır.
///  - Takvim günü (`ISODate`) verilen `calendar`'ın saat diliminde yorumlanır (web: süreç saat
///    dilimi); gece yarısını aşan segmentler günlere bölünür. Gün sınırları DST'ye dayanıklıdır
///    (23/25 saatlik gün).
///  - `Date()` çağrılmaz; `now` her zaman parametredir. Girdiler mutasyona uğramaz.
public enum FocusCalc {
    /// Bu süreyi aşan molada "Molan uzadı" uyarısı gösterilir (oturum kendiliğinden BİTMEZ).
    public static let longBreakThresholdMs: Double = 30 * 60 * 1000

    /// Odak ekranındaki günlük grafikte gösterilen gün sayısı.
    public static let recentDaysCount = 7

    /// Segmentlerden üretilen istatistik.
    public struct FocusSessionStats: Sendable, Equatable {
        /// Toplam odak süresi (ms); açık odak segmenti `now`'a kadar sayılır.
        public var focusMs: Double
        /// Toplam mola süresi (ms); açık mola segmenti `now`'a kadar sayılır.
        public var breakMs: Double
        /// Odak segmenti sayısı (açık olan dahil).
        public var focusCount: Int
        /// Mola segmenti sayısı (açık olan dahil).
        public var breakCount: Int
        /// Ortalama kesintisiz odak süresi (ms): YALNIZCA kapanmış odak segmentlerinin ortalaması.
        /// Açık segment ortalamayı canlı olarak düşürmesin diye hariçtir. Kapanmış yoksa 0.
        public var averageFocusMs: Double
        /// Ortalama mola süresi (ms): yalnızca kapanmış mola segmentleri. Kapanmış yoksa 0.
        public var averageBreakMs: Double

        public init(
            focusMs: Double = 0, breakMs: Double = 0, focusCount: Int = 0, breakCount: Int = 0,
            averageFocusMs: Double = 0, averageBreakMs: Double = 0
        ) {
            self.focusMs = focusMs
            self.breakMs = breakMs
            self.focusCount = focusCount
            self.breakCount = breakCount
            self.averageFocusMs = averageFocusMs
            self.averageBreakMs = averageBreakMs
        }
    }

    /// Oturumun anlık durumu.
    public enum FocusPhase: String, Sendable, Equatable {
        case focus
        case `break`
        case ended
    }

    /// Bir takvim günü için toplam odak süresi.
    public struct DailyFocusTotal: Sendable, Equatable {
        public var day: ISODate
        public var focusMs: Double

        public init(day: ISODate, focusMs: Double) {
            self.day = day
            self.focusMs = focusMs
        }
    }

    /// Geçersiz takvim günü (web: `RangeError`).
    public enum CalcError: Error, Equatable, Sendable {
        /// `YYYY-MM-DD` biçiminde olmayan ya da takvimde bulunmayan gün (ör. 2026-02-30).
        case invalidDay(String)
    }

    // MARK: - Yardımcılar

    /// Anın epoch milisaniyesi (tam ms'ye yuvarlanır); geçersizse NaN.
    private static func toMs(_ date: Date) -> Double {
        (date.timeIntervalSince1970 * 1000).rounded()
    }

    /// Segmentin bitiş anı (ms): kapalıysa `endedAt`, açıksa `now`.
    private static func segmentEndMs(_ segment: FocusSegmentSnapshot, now: Date) -> Double {
        toMs(segment.endedAt ?? now)
    }

    /// [start, end) ile [rangeStart, rangeEnd) kesişiminin uzunluğu; negatif/NaN → 0.
    private static func overlapMs(
        _ start: Double, _ end: Double, _ rangeStart: Double, _ rangeEnd: Double
    ) -> Double {
        if start.isNaN || end.isNaN || rangeStart.isNaN || rangeEnd.isNaN { return 0 }
        let length = Swift.min(end, rangeEnd) - Swift.max(start, rangeStart)
        return length > 0 ? length : 0
    }

    private static func isLive(_ segment: FocusSegmentSnapshot) -> Bool { segment.deletedAt == nil }

    private static func isLive(_ session: FocusSessionSnapshot) -> Bool { session.deletedAt == nil }

    // MARK: - Süre ve istatistik

    /// Bir segmentin süresi (ms). Açık segment için `now` kullanılır. Negatif olmaz.
    public static func segmentDurationMs(_ segment: FocusSegmentSnapshot, now: Date) -> Double {
        guard isLive(segment) else { return 0 }
        let start = toMs(segment.startedAt)
        return overlapMs(start, segmentEndMs(segment, now: now), start, .infinity)
    }

    /// Segmentlerden (bir oturumun ya da tüm geçmişin) istatistik üretir. Sıra önemsizdir.
    public static func computeSessionStats(
        _ segments: [FocusSegmentSnapshot], now: Date
    ) -> FocusSessionStats {
        let live = segments.filter(isLive)
        let focus = live.filter { $0.kind == .focus }
        let breaks = live.filter { $0.kind == .break }
        return FocusSessionStats(
            focusMs: sumDurations(focus, now: now),
            breakMs: sumDurations(breaks, now: now),
            focusCount: focus.count,
            breakCount: breaks.count,
            averageFocusMs: averageClosedDuration(focus, now: now),
            averageBreakMs: averageClosedDuration(breaks, now: now)
        )
    }

    private static func sumDurations(_ segments: [FocusSegmentSnapshot], now: Date) -> Double {
        segments.reduce(0) { $0 + segmentDurationMs($1, now: now) }
    }

    private static func averageClosedDuration(_ segments: [FocusSegmentSnapshot], now: Date) -> Double {
        let closed = segments.filter { $0.endedAt != nil }
        return closed.isEmpty ? 0 : sumDurations(closed, now: now) / Double(closed.count)
    }

    // MARK: - Faz

    /// Açık (`endedAt == nil`) segment; birden fazlaysa (tutarsız veri) en son başlayanı.
    /// Başlangıçları eşitse listede ilk gelen kalır. Yoksa `nil`.
    public static func findOpenSegment(_ segments: [FocusSegmentSnapshot]) -> FocusSegmentSnapshot? {
        segments
            .filter { isLive($0) && $0.endedAt == nil }
            .reduce(nil) { (latest: FocusSegmentSnapshot?, segment) in
                guard let latest else { return segment }
                return toMs(segment.startedAt) > toMs(latest.startedAt) ? segment : latest
            }
    }

    /// Oturumun anlık durumu: `session.endedAt` doluysa `.ended`; değilse açık segmentin türü.
    /// Açık oturumda açık segment yoksa (tutarsız veri) `.break` döner — sayaç akmaz, kullanıcı
    /// "Devam et" ile yeni odak segmenti açabilir.
    /// Silinmiş oturum `.ended` sayılır; yalnızca bu oturuma (`sessionId`) ait segmentlere bakılır.
    public static func focusPhase(
        session: FocusSessionSnapshot, segments: [FocusSegmentSnapshot]
    ) -> FocusPhase {
        if session.endedAt != nil || !isLive(session) { return .ended }
        let open = findOpenSegment(segments.filter { $0.sessionId == session.id })
        return open?.kind == .focus ? .focus : .break
    }

    /// Açık segment verilen türdeyse onun `now`'a kadarki süresi; değilse 0.
    public static func openSegmentDurationMs(
        _ segments: [FocusSegmentSnapshot], kind: FocusSegmentKind, now: Date
    ) -> Double {
        guard let open = findOpenSegment(segments), open.kind == kind else { return 0 }
        return segmentDurationMs(open, now: now)
    }

    /// Açık mola süresi `thresholdMs`'e ulaştı mı (≥: tam eşikte true). Açık mola yoksa false.
    public static func isLongBreak(
        _ segments: [FocusSegmentSnapshot], now: Date, thresholdMs: Double = longBreakThresholdMs
    ) -> Bool {
        guard findOpenSegment(segments)?.kind == .break else { return false }
        return openSegmentDurationMs(segments, kind: .break, now: now) >= thresholdMs
    }

    // MARK: - Geçmiş oturumlar

    /// Odak ekranındaki geçmiş listesi sayısı.
    public static let historyLimit = 20

    /// Geçmiş listesindeki bir bitmiş oturum.
    public struct HistoryEntry: Sendable, Equatable, Identifiable {
        public var id: UUID
        public var startedAt: Date
        /// Oturumun toplam odak süresi (ms).
        public var focusMs: Double

        public init(id: UUID, startedAt: Date, focusMs: Double) {
            self.id = id
            self.startedAt = startedAt
            self.focusMs = focusMs
        }
    }

    /// Son `limit` BİTMİŞ (silinmemiş, `endedAt != nil`) oturum, en yeni önce (`startedAt` azalan;
    /// eşitlikte girdideki sıra korunur). Odak süresi yalnızca o oturumun segmentlerinden hesaplanır.
    public static func historyEntries(
        sessions: [FocusSessionSnapshot], segments: [FocusSegmentSnapshot],
        now: Date, limit: Int = historyLimit
    ) -> [HistoryEntry] {
        let finished = sessions
            .enumerated()
            .filter { isLive($0.element) && $0.element.endedAt != nil }
            .sorted { lhs, rhs in
                let (left, right) = (toMs(lhs.element.startedAt), toMs(rhs.element.startedAt))
                return left != right ? left > right : lhs.offset < rhs.offset
            }
            .prefix(Swift.max(0, limit))
            .map(\.element)
        let segmentsBySession = Dictionary(grouping: segments.filter { $0.sessionId != nil }) { $0.sessionId! }
        return finished.map { session in
            HistoryEntry(
                id: session.id, startedAt: session.startedAt,
                focusMs: computeSessionStats(segmentsBySession[session.id] ?? [], now: now).focusMs)
        }
    }

    // MARK: - Takvim günleri

    /// Yerel günün [başlangıç, sonraki günün başlangıcı) aralığı. Geçersiz biçimde `CalcError.invalidDay`.
    /// DST günlerinde aralık 23 ya da 25 saat olabilir.
    public static func localDayBounds(
        _ day: ISODate, calendar: Calendar = .current
    ) throws -> (start: Date, end: Date) {
        guard let parts = parseISODate(day),
            let date = calendar.date(from: DateComponents(
                year: parts.year, month: parts.month, day: parts.day)),
            // Takvimde olmayan gün (30 Şubat, ay 13…) bir sonraki aya taşar; geri dönüşüm farkı yakalar.
            Identifiers.isoDate(date, calendar: calendar) == day,
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
        else {
            throw CalcError.invalidDay(day)
        }
        return (calendar.startOfDay(for: date), end)
    }

    /// Katı `YYYY-MM-DD` ayrıştırma (4+2+2 rakam, ASCII).
    private static func parseISODate(_ day: String) -> (year: Int, month: Int, day: Int)? {
        let bytes = Array(day.utf8)
        guard bytes.count == 10, bytes[4] == UInt8(ascii: "-"), bytes[7] == UInt8(ascii: "-") else {
            return nil
        }
        let zero = UInt8(ascii: "0")
        let nine = UInt8(ascii: "9")
        let digitIndices = [0, 1, 2, 3, 5, 6, 8, 9]
        guard digitIndices.allSatisfy({ (zero...nine).contains(bytes[$0]) }) else { return nil }
        func number(_ range: Range<Int>) -> Int {
            bytes[range].reduce(0) { $0 * 10 + Int($1 - zero) }
        }
        return (number(0..<4), number(5..<7), number(8..<10))
    }

    /// Takvim adımında DST'den etkilenmemek için günün öğle saati kullanılır.
    private static let noonHour = 12

    /// `now`'un yerel gününde biten `count` günlük liste, ESKİDEN YENİYE (son eleman bugün).
    /// `count <= 0` → boş liste.
    public static func recentDays(
        now: Date, count: Int = recentDaysCount, calendar: Calendar = .current
    ) -> [ISODate] {
        let length = Swift.max(0, count)
        guard length > 0,
            let noon = calendar.date(bySettingHour: noonHour, minute: 0, second: 0, of: now)
        else { return [] }
        return (0..<length).compactMap { index in
            calendar.date(byAdding: .day, value: -(length - 1 - index), to: noon)
                .map { Identifiers.isoDate($0, calendar: calendar) }
        }
    }

    // MARK: - Günlük toplamlar

    /// Belirli bir yerel gündeki toplam odak süresi (ms). Gece yarısını aşan segmentler bölünür;
    /// yalnızca `sessions` içindeki (silinmemiş) oturumlara ait odak segmentleri sayılır.
    /// Geçersiz `day` için `CalcError.invalidDay` fırlatır.
    public static func dailyFocusTotalMs(
        sessions: [FocusSessionSnapshot], segments: [FocusSegmentSnapshot],
        day: ISODate, now: Date, calendar: Calendar = .current
    ) throws -> Double {
        try focusMsInDay(
            countableFocusSegments(sessions: sessions, segments: segments),
            day: day, now: now, calendar: calendar)
    }

    /// `days` sırasını koruyarak her gün için `dailyFocusTotalMs`.
    public static func dailyFocusTotals(
        sessions: [FocusSessionSnapshot], segments: [FocusSegmentSnapshot],
        days: [ISODate], now: Date, calendar: Calendar = .current
    ) throws -> [DailyFocusTotal] {
        let countable = countableFocusSegments(sessions: sessions, segments: segments)
        return try days.map { day in
            DailyFocusTotal(
                day: day, focusMs: try focusMsInDay(countable, day: day, now: now, calendar: calendar))
        }
    }

    /// Silinmemiş oturumlara ait, silinmemiş odak segmentleri.
    private static func countableFocusSegments(
        sessions: [FocusSessionSnapshot], segments: [FocusSegmentSnapshot]
    ) -> [FocusSegmentSnapshot] {
        let sessionIds = Set(sessions.filter(isLive).map(\.id))
        return segments.filter { segment in
            guard isLive(segment), segment.kind == .focus, let id = segment.sessionId else {
                return false
            }
            return sessionIds.contains(id)
        }
    }

    private static func focusMsInDay(
        _ segments: [FocusSegmentSnapshot], day: ISODate, now: Date, calendar: Calendar
    ) throws -> Double {
        let bounds = try localDayBounds(day, calendar: calendar)
        let dayStart = toMs(bounds.start)
        let dayEnd = toMs(bounds.end)
        return segments.reduce(0) {
            $0 + overlapMs(toMs($1.startedAt), segmentEndMs($1, now: now), dayStart, dayEnd)
        }
    }
}
