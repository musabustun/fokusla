import Foundation

/// Kitap modülünün Türkçe etiketleri ve biçimlendiricileri — web `features/books/bookLabels.ts`
/// karşılığı (aynı vakalar). SAF: yalnızca Foundation; yerel ayar her zaman açıkça `tr_TR`'dir.
public enum BooksFormat {
    private static let turkish = Locale(identifier: "tr_TR")

    // MARK: - Etiketler

    /// Kitap türü etiketi: "Soru bankası", "Konu anlatımı", "Deneme", "Diğer".
    public static func kindLabel(_ kind: BookKind) -> String {
        switch kind {
        case .questionBank: "Soru bankası"
        case .lecture: "Konu anlatımı"
        case .practiceExam: "Deneme"
        case .other: "Diğer"
        }
    }

    /// Birim adı (tekil, büyük harfle): "Test 34", "Sayfa 210", "Bölüm 3" içindeki ilk sözcük.
    public static func unitLabel(_ unit: BookUnit) -> String {
        switch unit {
        case .test: "Test"
        case .page: "Sayfa"
        case .section: "Bölüm"
        }
    }

    /// Birim adı (küçük harf, sayı sonrası): "12 test", "210 sayfa", "3 bölüm".
    public static func unitNoun(_ unit: BookUnit) -> String {
        switch unit {
        case .test: "test"
        case .page: "sayfa"
        case .section: "bölüm"
        }
    }

    /// Durum etiketi: "Başlanmadı", "Devam ediyor", "Tamamlandı", "Arşivlendi".
    public static func statusLabel(_ status: BooksCalc.BookStatus) -> String {
        switch status {
        case .notStarted: "Başlanmadı"
        case .inProgress: "Devam ediyor"
        case .completed: "Tamamlandı"
        case .archived: "Arşivlendi"
        }
    }

    // MARK: - Sayılar

    /// tr-TR sayı biçimi (binlik ayırıcı nokta): 1234 → "1.234".
    public static func number(_ value: Int) -> String {
        number(Double(value))
    }

    /// tr-TR sayı biçimi; en çok 3 ondalık: 1234.5 → "1.234,5".
    public static func number(_ value: Double) -> String {
        value.formatted(
            .number.locale(turkish).precision(.fractionLength(0...3))
                .rounded(rule: .toNearestOrAwayFromZero))
    }

    /// Yüzde: 0.456 → "%46" (tr-TR, ondalıksız).
    public static func percent(_ ratio: Double) -> String {
        ratio.formatted(
            .percent.locale(turkish).precision(.fractionLength(0))
                .rounded(rule: .toNearestOrAwayFromZero))
    }

    // MARK: - Birleşik metinler

    /// "Test 34" / "Sayfa 210".
    public static func position(_ unit: BookUnit, reached: Int) -> String {
        "\(unitLabel(unit)) \(number(reached))"
    }

    /// "34 / 120 test" ya da toplam yoksa (nil ya da ≤ 0) "34 test".
    public static func progressCount(_ unit: BookUnit, reached: Int, total: Int?) -> String {
        let noun = unitNoun(unit)
        guard let total, total > 0 else { return "\(number(reached)) \(noun)" }
        return "\(number(reached)) / \(number(total)) \(noun)"
    }

    /// "haftada ~12 test"; hız nil ise nil. Hız en yakın tam sayıya yuvarlanır (.5 yukarı, JS `Math.round`).
    public static func pace(_ unit: BookUnit, pacePerWeek: Double?) -> String? {
        guard let pacePerWeek else { return nil }
        return "haftada ~\(number((pacePerWeek + 0.5).rounded(.down))) \(unitNoun(unit))"
    }

    // MARK: - Tarih

    /// "19 Kasım" (`now` ile aynı yıl) ya da "19 Kasım 2025". Gün/yıl `calendar`'ın saat diliminde okunur.
    public static func day(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.locale = turkish
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = sameYear ? "d MMMM" : "d MMMM yyyy"
        return formatter.string(from: date)
    }

    /// `now`'dan `days` gün sonraki an (yerel gün aritmetiği; DST'de saat korunur).
    public static func addDays(_ now: Date, _ days: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: now) ?? now
    }

    // MARK: - Bölüm aralığı

    /// Bölüm aralığı: "Test 1–12", "Sayfa 10–40"; tek uç ya da başlangıç = bitiş → "Test 5";
    /// ikisi de yoksa `nil`.
    public static func sectionRange(_ unit: BookUnit, start: Int?, end: Int?) -> String? {
        let label = unitLabel(unit)
        switch (start, end) {
        case (nil, nil): return nil
        case (let value?, nil), (nil, let value?): return "\(label) \(number(value))"
        case (let first?, let last?):
            if first == last { return "\(label) \(number(first))" }
            return "\(label) \(number(first))\u{2013}\(number(last))"
        }
    }
}
