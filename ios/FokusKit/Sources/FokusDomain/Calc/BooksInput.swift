import Foundation

/// Kitap formlarının girdi ayrıştırma ve uyarı kuralları — SAF (web `progressInput.ts` +
/// `ProgressSheet.progressWarnings` + `bookActions.normalize` karşılığı).
public enum BooksInput {
    /// "34" → 34. Boş, ondalıklı, negatif, harf içeren ya da taşan girdi → `nil`.
    /// Baştaki/sondaki boşluklar yok sayılır; yalnızca ASCII rakam kabul edilir.
    public static func parseReachedUnit(_ raw: String) -> Int? {
        parseNonNegativeInteger(raw)
    }

    /// "Toplam" alanı: boş → `.unknown` (toplam bilinmiyor), pozitif tam sayı → `.value`,
    /// diğer her şey (0, negatif, ondalık, harf) → `.invalid`.
    public static func parseTotal(_ raw: String) -> TotalInput {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .unknown }
        guard let value = parseNonNegativeInteger(trimmed), value > 0 else { return .invalid }
        return .value(value)
    }

    /// "Toplam" alanının ayrıştırma sonucu.
    public enum TotalInput: Sendable, Equatable {
        /// Alan boş: toplam bilinmiyor (`totalUnits == nil`).
        case unknown
        /// Geçerli pozitif toplam.
        case value(Int)
        /// Geçersiz metin (form hata gösterir).
        case invalid
    }

    /// İlerleme girerken gösterilen uyarılar: önceki kayıttan geride ("düzeltme") ve toplama
    /// ulaşıldığında ("tamamlandı"). `value == nil` (geçersiz girdi) → uyarı yok.
    public static func progressWarnings(value: Int?, currentReached: Int, total: Int?) -> [ProgressWarning] {
        guard let value else { return [] }
        var warnings: [ProgressWarning] = []
        if value < currentReached { warnings.append(.behindPrevious) }
        if let total, total > 0, value >= total { warnings.append(.completesBook) }
        return warnings
    }

    /// İlerleme girişi uyarısı.
    public enum ProgressWarning: Sendable, Equatable {
        /// Önceki kayıttan geride; düzeltme olarak kaydedilir.
        case behindPrevious
        /// Kitap tamamlandı olarak işaretlenecek.
        case completesBook

        /// Kullanıcıya görünen Türkçe metin.
        public var message: String {
            switch self {
            case .behindPrevious: "Önceki kayıttan geride; düzeltme olarak kaydedilir."
            case .completesBook: "Kitap tamamlandı olarak işaretlenecek."
            }
        }
    }

    private static func parseNonNegativeInteger(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }) else { return nil }
        return Int(trimmed)
    }
}
