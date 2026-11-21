import Foundation

/// Bir grup test sonucunun özeti (web `TestSummary`).
public struct TestSummary: Sendable, Equatable {
    /// Özetlenen test sonucu sayısı.
    public var testCount: Int
    public var totalQuestions: Int
    public var correct: Int
    public var wrong: Int
    public var blank: Int
    /// D − Y/4; negatif olabilir.
    public var net: Double
    /// Doğru / toplam soru (0–1); soru yoksa 0.
    public var accuracy: Double
    /// Net / toplam soru (−0.25…1); soru yoksa 0. Zayıflık sıralamasında kullanılır.
    public var netRatio: Double
    /// En son çözülen testin `takenAt` değeri; hiç test yoksa `nil`.
    public var lastTakenAt: Date?

    public init(
        testCount: Int = 0, totalQuestions: Int = 0, correct: Int = 0, wrong: Int = 0, blank: Int = 0,
        net: Double = 0, accuracy: Double = 0, netRatio: Double = 0, lastTakenAt: Date? = nil
    ) {
        self.testCount = testCount
        self.totalQuestions = totalQuestions
        self.correct = correct
        self.wrong = wrong
        self.blank = blank
        self.net = net
        self.accuracy = accuracy
        self.netRatio = netRatio
        self.lastTakenAt = lastTakenAt
    }
}

/// "En zayıf konular" satırı.
public struct WeakTopic: Sendable, Equatable {
    public var topicId: UUID
    public var summary: TestSummary

    public init(topicId: UUID, summary: TestSummary) {
        self.topicId = topicId
        self.summary = summary
    }
}

/// Net trendinin bir günü.
public struct NetTrendPoint: Sendable, Equatable {
    /// Yerel takvim günü.
    public var date: ISODate
    /// O gün çözülen testlerin özeti (`net` = günlük toplam net).
    public var summary: TestSummary

    public init(date: ISODate, summary: TestSummary) {
        self.date = date
        self.summary = summary
    }
}

/// Test analizi hesapları — SAF fonksiyonlar (SwiftUI/SwiftData yok). Web `web/src/domain/calc/tests.ts`
/// karşılığı; tablo vakaları `TestsCalcTests` içinde aynı adlarla taşınmıştır.
///
/// Kurallar:
///  - Net SAKLANMAZ: `net = D − Y/4`. Başarı = D / soru. Soru sayısı = D + Y + B.
///  - Soru yoksa oranlar 0'dır (sıfıra bölme yok).
///  - `deletedAt != nil` sonuçlar ve `subjectId`/`topicId` anahtarı `nil` olanlar ilgili gruplamada yok sayılır.
///  - Takvim günü verilen `calendar`'a göre YEREL gündür; `Date()` çağrılmaz. Girdiler mutasyona uğramaz.
public enum TestsCalc {
    /// YKS'de 4 yanlış 1 doğruyu götürür.
    public static let wrongAnswerPenalty: Double = 0.25

    /// "En zayıf konular" listesine girmek için bir konuda çözülmüş en az soru sayısı.
    public static let minQuestionsForWeakness = 20

    /// "En zayıf konular" listesinin varsayılan uzunluğu.
    public static let defaultWeakTopicLimit = 5

    // MARK: - Tekil sonuç

    /// Net = doğru − yanlış × 0.25. Negatif olabilir.
    public static func computeNet(correct: Int, wrong: Int) -> Double {
        Double(correct) - Double(wrong) * wrongAnswerPenalty
    }

    /// Soru sayısı = doğru + yanlış + boş.
    public static func questionCount(correct: Int, wrong: Int, blank: Int) -> Int {
        correct + wrong + blank
    }

    /// Başarı oranı = doğru / soru (0–1); soru yoksa 0.
    public static func accuracyOf(correct: Int, wrong: Int, blank: Int) -> Double {
        ratio(Double(correct), Double(questionCount(correct: correct, wrong: wrong, blank: blank)))
    }

    private static func ratio(_ numerator: Double, _ denominator: Double) -> Double {
        denominator == 0 ? 0 : numerator / denominator
    }

    // MARK: - Özetler

    /// Bir grup test sonucunu (ör. bir konu) özetler. Silinmişler yok sayılır.
    /// Boş liste → tüm sayılar 0, `lastTakenAt == nil`.
    public static func summarize(_ results: [TestResultSnapshot]) -> TestSummary {
        let live = results.filter { $0.deletedAt == nil }
        let correct = live.reduce(0) { $0 + $1.correct }
        let wrong = live.reduce(0) { $0 + $1.wrong }
        let blank = live.reduce(0) { $0 + $1.blank }
        let total = questionCount(correct: correct, wrong: wrong, blank: blank)
        let net = computeNet(correct: correct, wrong: wrong)
        return TestSummary(
            testCount: live.count,
            totalQuestions: total,
            correct: correct,
            wrong: wrong,
            blank: blank,
            net: net,
            accuracy: ratio(Double(correct), Double(total)),
            netRatio: ratio(net, Double(total)),
            lastTakenAt: live.map(\.takenAt).max()
        )
    }

    /// `subjectId`'ye göre gruplayıp özetler. Yalnızca en az bir sonucu olan dersler anahtar olur.
    public static func summarizeBySubject(_ results: [TestResultSnapshot]) -> [UUID: TestSummary] {
        summarizeGroups(results, key: \.subjectId)
    }

    /// `topicId`'ye göre gruplayıp özetler; `topicId == nil` olanlar atlanır.
    public static func summarizeByTopic(_ results: [TestResultSnapshot]) -> [UUID: TestSummary] {
        summarizeGroups(results, key: \.topicId)
    }

    private static func summarizeGroups<Key: Hashable>(
        _ results: [TestResultSnapshot], key: KeyPath<TestResultSnapshot, Key?>
    ) -> [Key: TestSummary] {
        var groups: [Key: [TestResultSnapshot]] = [:]
        for result in results where result.deletedAt == nil {
            guard let groupKey = result[keyPath: key] else { continue }
            groups[groupKey, default: []].append(result)
        }
        return groups.mapValues(summarize)
    }

    // MARK: - En zayıf konular

    /// En zayıf konular: eşiği geçen konular `netRatio`'ya göre ARTAN sıralanır. Eşitlikte daha çok
    /// soru çözülmüş konu önce, o da eşitse küçük harfli `topicId` dizgesine göre (deterministik).
    /// - Parameters:
    ///   - minQuestions: Bundan az sorusu olan konu listeye girmez.
    ///   - limit: Listenin azami uzunluğu; 0 veya negatifse boş döner.
    public static func findWeakestTopics(
        _ summaries: [UUID: TestSummary],
        minQuestions: Int = minQuestionsForWeakness,
        limit: Int = defaultWeakTopicLimit
    ) -> [WeakTopic] {
        summaries
            .filter { $0.value.totalQuestions >= minQuestions }
            .map { WeakTopic(topicId: $0.key, summary: $0.value) }
            .sorted(by: isMoreWeak)
            .prefix(Swift.max(0, limit))
            .map { $0 }
    }

    private static func isMoreWeak(_ a: WeakTopic, _ b: WeakTopic) -> Bool {
        if a.summary.netRatio != b.summary.netRatio { return a.summary.netRatio < b.summary.netRatio }
        if a.summary.totalQuestions != b.summary.totalQuestions {
            return a.summary.totalQuestions > b.summary.totalQuestions
        }
        return Identifiers.lowercasedString(a.topicId) < Identifiers.lowercasedString(b.topicId)
    }

    // MARK: - Trend

    /// Günlük net trendi: sonuçları `takenAt`'in YEREL gününe göre gruplar, güne göre ARTAN sıralı
    /// noktalar döner. Boş liste → `[]`.
    public static func dailyNetTrend(
        _ results: [TestResultSnapshot], calendar: Calendar = .current
    ) -> [NetTrendPoint] {
        var byDay: [ISODate: [TestResultSnapshot]] = [:]
        for result in results where result.deletedAt == nil {
            byDay[Identifiers.isoDate(result.takenAt, calendar: calendar), default: []].append(result)
        }
        return byDay
            .map { NetTrendPoint(date: $0.key, summary: summarize($0.value)) }
            .sorted { $0.date < $1.date }
    }
}
