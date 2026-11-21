import Foundation

/// Kullanıcı tanımlı ders/konu adlarının doğrulaması — saf (web `entityName.ts`).
public enum EntityNameValidation {
    public static let maxSubjectNameLength = 60
    public static let maxTopicNameLength = 80

    public enum Result: Sendable, Equatable {
        case valid(String)
        case invalid(String)
    }

    /// Adı kırpar ve ardışık boşlukları teke indirir; boşsa veya `maxLength`'i aşıyorsa `label` ile
    /// Türkçe hata döner.
    public static func validate(_ raw: String, label: String, maxLength: Int) -> Result {
        let name = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if name.isEmpty { return .invalid("\(label) boş olamaz.") }
        if name.count > maxLength { return .invalid("\(label) en fazla \(maxLength) karakter olabilir.") }
        return .valid(name)
    }
}
