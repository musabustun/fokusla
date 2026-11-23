import Foundation

/// iMessage paylaşım bağlantılarının hata türleri. Mesajdaki bağlantı DIŞARIDAN gelir (güvenilmez);
/// çözme her zaman doğrular ve geçersizse bunlardan birini fırlatır.
public enum ShareLinkError: Error, Equatable, Sendable {
    /// `fokus://<host>` biçiminde, beklenen türde bir bağlantı değil.
    case notAShareLink
    /// Sürüm desteklenmiyor (gelecekteki bir uygulama sürümü üretmiş olabilir).
    case unsupportedVersion
    /// Zorunlu alan eksik ya da aralık dışı.
    case invalid(String)
}

/// Sunucusuz paylaşım: durum, mesajın bağlantısında (`MSMessage.url`) taşınır. Şema `fokus://` mevcut
/// derin bağlantı şemasıyla aynıdır; host türü belirler (`study`, `room`). Ortak yardımcılar burada.
public enum ShareLink {
    public static let scheme = "fokus"
    /// Bağlantı biçimi sürümü; uyumsuz değişikliklerde artar.
    public static let version = 1
    /// Takma ad üst sınırı (URL boyutunu da sınırlar).
    public static let nameMaxLength = 20
    public static let subjectNameMaxLength = 30

    /// Görünen adı güvenle kısaltır: denetim/biçim karakterleri atılır, boşluklar tekilleştirilir,
    /// `maxLength` karaktere kırpılır. Geriye anlamlı karakter kalmazsa `nil`.
    public static func sanitizedName(_ raw: String, maxLength: Int = nameMaxLength) -> String? {
        var scalars = String.UnicodeScalarView()
        for scalar in raw.unicodeScalars {
            switch scalar.properties.generalCategory {
            case .control: scalars.append(" ")
            case .format: continue
            default: scalars.append(scalar)
            }
        }
        let words = String(scalars).split(whereSeparator: \.isWhitespace)
        let joined = words.joined(separator: " ")
        let clipped = String(joined.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
        return clipped.isEmpty ? nil : clipped
    }

    // MARK: - İç yardımcılar (kodlama)

    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    /// `fokus://<host>?k=v&…` — değerler katı yüzde-kodlama ile (`&`, `=`, `+`, `,` güvenli).
    static func makeURL(host: String, items: [(String, String)]) -> URL {
        let query = items.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? "")"
        }.joined(separator: "&")
        return URL(string: "\(scheme)://\(host)?\(query)")!
    }

    /// Bağlantıyı doğrular (şema, host, sürüm) ve çözülmüş sorgu çiftlerini sırasıyla döndürür.
    static func parse(_ url: URL, host: String) throws -> [(key: String, value: String)] {
        guard url.scheme?.lowercased() == scheme, url.host?.lowercased() == host else {
            throw ShareLinkError.notAShareLink
        }
        let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery ?? ""
        let items: [(key: String, value: String)] = raw.split(separator: "&").compactMap { part in
            let pieces = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pieces.count == 2, let value = String(pieces[1]).removingPercentEncoding else { return nil }
            return (String(pieces[0]), value)
        }
        guard let versionText = items.first(where: { $0.key == "v" })?.value, let found = Int(versionText) else {
            throw ShareLinkError.unsupportedVersion
        }
        guard found == version else { throw ShareLinkError.unsupportedVersion }
        return items
    }

    /// `YYYY-MM-DD` gerçekten var olan bir takvim günü mü?
    static func isValidDay(_ day: String) -> Bool {
        let parts = day.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 3 - 1,
            let year = Int(parts[0]), let month = Int(parts[1]), let dayNumber = Int(parts[2])
        else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: dayNumber)) else {
            return false
        }
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        return back.year == year && back.month == month && back.day == dayNumber
    }
}
