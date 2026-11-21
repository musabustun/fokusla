import FokusDomain
import Foundation

/// Odak ekranındaki tarih etiketleri (tr-TR, yerel saat dilimi) — web `formatDate.ts`.
enum FocusDateFormat {
    private static let locale = Locale(identifier: "tr_TR")

    private static func formatter(_ pattern: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = pattern
        return formatter
    }

    private static let weekday = formatter("EEE")
    private static let dayMonthWeekday = formatter("d MMM EEE")
    private static let time = formatter("HH:mm")

    /// `YYYY-MM-DD` → yerel gün. Geçersizse `nil`.
    static func date(from day: ISODate, calendar: Calendar = .current) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Kısa gün adı: "Çar".
    static func weekdayShort(_ day: ISODate) -> String {
        date(from: day).map { weekday.string(from: $0) } ?? day
    }

    /// Erişilebilirlik için tam gün etiketi: "Çar 18 Kas".
    static func dayLabel(_ day: ISODate) -> String {
        guard let date = date(from: day) else { return day }
        return "\(weekday.string(from: date)) \(dayMonth(date))"
    }

    private static func dayMonth(_ date: Date) -> String {
        // "18 Kas Çar" → "18 Kas"
        dayMonthWeekday.string(from: date).split(separator: " ").prefix(2).joined(separator: " ")
    }

    /// Geçmiş oturum satırı: "19 Kas Per, 14:05".
    static func sessionStart(_ date: Date) -> String {
        "\(dayMonthWeekday.string(from: date)), \(time.string(from: date))"
    }
}
