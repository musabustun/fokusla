import FokusDomain
import Foundation

/// `ISODate` ⇄ `Date` dönüşümleri (yerel takvim günü). Yalnızca form tarih seçicisi için.
enum TaskISODate {
    /// `YYYY-MM-DD` → o günün öğle saati (DST'ye dayanıklı); geçersizse `nil`.
    static func date(from day: ISODate, calendar: Calendar = .current) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    static func isoDate(from date: Date, calendar: Calendar = .current) -> ISODate {
        Identifiers.isoDate(date, calendar: calendar)
    }
}
