import Foundation

/// Barkod normalleştirme — web `web/src/domain/barcode.ts` ile birebir aynı davranış.
/// Kitap barkodları EAN-13 (ISBN-13 dahil) biçimine çevrilir.
public enum Barcode {
    /// Ham barkod metnini (boşluk/tire içerebilir) EAN-13'e çevirir; geçersizse `nil`.
    /// - 13 hane geçerli EAN-13 → aynen
    /// - 10 karakter geçerli ISBN-10 → `978` önekli EAN-13
    /// - 12 hane geçerli UPC-A → başına `0` eklenmiş EAN-13
    public static func normalize(_ raw: String) -> String? {
        let cleaned = raw.filter { !$0.isWhitespace && $0 != "-" }
        switch cleaned.count {
        case 13: return isValidEAN13(cleaned) ? cleaned : nil
        case 10: return isbn10ToEAN13(cleaned)
        case 12: return isValidUPCA(cleaned) ? "0" + cleaned : nil
        default: return nil
        }
    }

    /// 13 haneli, sağlaması doğru EAN-13 mü?
    public static func isValidEAN13(_ value: String) -> Bool {
        guard let digits = asciiDigits(value), digits.count == 13 else { return false }
        return ean13CheckDigit(Array(digits.prefix(12))) == digits[12]
    }

    /// ISBN-10'u (son karakter X/x olabilir) EAN-13'e çevirir; sağlama geçersizse `nil`.
    public static func isbn10ToEAN13(_ value: String) -> String? {
        let chars = Array(value.uppercased())
        guard chars.count == 10 else { return nil }
        var sum = 0
        var first9: [Int] = []
        for (index, char) in chars.enumerated() {
            let digit: Int
            if char == "X", index == 9 {
                digit = 10
            } else if let ascii = char.asciiValue, ascii >= 48, ascii <= 57 {
                digit = Int(ascii) - 48
            } else {
                return nil
            }
            if index < 9 { first9.append(digit) }
            sum += digit * (10 - index)
        }
        guard sum % 11 == 0 else { return nil }
        let first12 = [9, 7, 8] + first9
        let check = ean13CheckDigit(first12)
        return (first12 + [check]).map(String.init).joined()
    }

    // MARK: - İç yardımcılar

    private static func asciiDigits(_ value: String) -> [Int]? {
        var result: [Int] = []
        for char in value {
            guard let ascii = char.asciiValue, ascii >= 48, ascii <= 57 else { return nil }
            result.append(Int(ascii) - 48)
        }
        return result
    }

    private static func ean13CheckDigit(_ first12: [Int]) -> Int {
        var sum = 0
        for (index, digit) in first12.enumerated() {
            sum += digit * (index % 2 == 0 ? 1 : 3)
        }
        return (10 - sum % 10) % 10
    }

    private static func isValidUPCA(_ value: String) -> Bool {
        guard let digits = asciiDigits(value), digits.count == 12 else { return false }
        var sum = 0
        for index in 0..<11 {
            sum += digits[index] * (index % 2 == 0 ? 3 : 1)
        }
        return (10 - sum % 10) % 10 == digits[11]
    }
}
