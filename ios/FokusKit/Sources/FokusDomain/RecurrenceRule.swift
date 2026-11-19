/// Rutin görevin tekrar kuralı (web `RecurrenceRule`). SwiftData'da kodlanmış (composite)
/// alan olarak saklanır; alan adları ve değerleri web ile aynıdır.
///
/// - `frequency`: `RecurrenceFrequency` raw value'su (`daily` / `weekly`).
/// - `weekdays`: ISO hafta günleri, 1 = Pazartesi … 7 = Pazar. `Calendar` 1 = Pazar verir;
///   dönüştürmek için `Weekday.iso(fromGregorian:)` kullan.
public struct RecurrenceRule: Codable, Sendable, Hashable {
    public var frequency: String
    public var weekdays: [Int]

    public init(frequency: RecurrenceFrequency, weekdays: [Int] = []) {
        self.frequency = frequency.rawValue
        self.weekdays = weekdays
    }

    /// Bilinmeyen raw value (ileride eklenen bir sıklık) `nil` döner.
    public var frequencyValue: RecurrenceFrequency? { RecurrenceFrequency(rawValue: frequency) }
}

/// ISO hafta günü yardımcıları (1 = Pazartesi … 7 = Pazar).
public enum Weekday {
    /// `Calendar.component(.weekday, …)` (1 = Pazar … 7 = Cumartesi) → ISO (1 = Pazartesi … 7 = Pazar).
    public static func iso(fromGregorian weekday: Int) -> Int {
        weekday == 1 ? 7 : weekday - 1
    }
}
