import Foundation

/// Görevler ekranının Türkçe metin biçimlendiricileri — SAF. Web `features/tasks/format.ts` karşılığı.
/// Gün/ay adları sabit tablolardır (ICU/yerel ayar sürümüne bağlı değil); sayılar `tr_TR` biçimindedir
/// (`12.345`, `%57`).
public enum TaskFormatting {
    /// ISO hafta günleri (1 = Pazartesi … 7 = Pazar) kısa adları.
    public static let weekdayShortNames = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
    /// ISO hafta günleri tam adları.
    public static let weekdayLongNames = [
        "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar",
    ]
    /// Ay adları (1 = Ocak).
    public static let monthNames = [
        "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
        "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık",
    ]

    private static let locale = Locale(identifier: "tr_TR")

    /// Kısa gün adı: "Pzt", "Sal", … (`weekday` 1…7; dışındaki değerler 7'ye göre döner).
    public static func weekdayShortName(_ weekday: Int) -> String {
        weekdayShortNames[((weekday - 1) % 7 + 7) % 7]
    }

    /// Tam gün adı: "Pazartesi", … (`weekday` 1…7; dışındaki değerler 7'ye göre döner).
    public static func weekdayLongName(_ weekday: Int) -> String {
        weekdayLongNames[((weekday - 1) % 7 + 7) % 7]
    }

    private static let workWeek = [1, 2, 3, 4, 5]
    private static let weekend = [6, 7]

    /// Tekrar kuralı metni: "Her gün", "Hafta içi", "Hafta sonu" ya da "Pzt, Çar, Cum".
    public static func recurrenceText(_ rule: RecurrenceRule) -> String {
        guard rule.frequencyValue == .weekly else { return "Her gün" }
        let days = Array(Set(rule.weekdays)).sorted()
        if days.isEmpty { return "Gün seçilmedi" }
        if days.count == 7 { return "Her gün" }
        if days == workWeek { return "Hafta içi" }
        if days == weekend { return "Hafta sonu" }
        return days.map(weekdayShortName).joined(separator: ", ")
    }

    /// Ekran alt başlığı: "19 Kasım Perşembe".
    public static func dayTitle(_ day: ISODate) -> String {
        let date = TasksCalc.civilDate(of: day)
        return "\(date.day) \(monthNames[date.month - 1]) \(weekdayLongName(TasksCalc.weekday(of: day)))"
    }

    /// Uzun tarih: "19 Kasım 2026".
    public static func longDate(_ day: ISODate) -> String {
        let date = TasksCalc.civilDate(of: day)
        return "\(date.day) \(monthNames[date.month - 1]) \(date.year)"
    }

    /// Tamsayı, binlik ayraçlı: `12.345`.
    public static func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    /// 0–1 oran → "%57".
    public static func percent(_ rate: Double) -> String {
        rate.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// Son tarihe kalan gün → "Bugün", "Yarın", "2 gün kaldı", "Dün", "3 gün gecikti".
    public static func dueText(daysUntil: Int) -> String {
        switch daysUntil {
        case 0: "Bugün"
        case 1: "Yarın"
        case -1: "Dün"
        case 2...: "\(number(daysUntil)) gün kaldı"
        default: "\(number(-daysUntil)) gün gecikti"
        }
    }

    /// Hedef/gerçekleşen miktar: "50 soru", "42/50 soru", "42 soru" (hedefsiz), "50".
    /// İkisi de yoksa `nil`.
    public static func quantityText(target: Int?, actual: Int?, unit: String?) -> String? {
        let amount: String
        switch (target, actual) {
        case (nil, nil): return nil
        case let (target?, actual?): amount = "\(number(actual))/\(number(target))"
        case let (target?, nil): amount = number(target)
        case let (nil, actual?): amount = number(actual)
        }
        let trimmedUnit = unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedUnit.isEmpty ? amount : "\(amount) \(trimmedUnit)"
    }

    /// Seri metni: "3 gün seri".
    public static func streakText(_ days: Int) -> String {
        "\(number(days)) gün seri"
    }

    /// "Son 7 gün %57".
    public static func rateText(_ rate: Double, windowDays: Int = TasksCalc.completionRateWindowDays) -> String {
        "Son \(number(windowDays)) gün \(percent(rate))"
    }
}
