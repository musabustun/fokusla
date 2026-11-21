import FokusDomain
import Foundation

// Paketle gelen YKS müfredat kataloğu (`Resources/yks-curriculum.json`). Kaynak web kataloğudur;
// dosya `npm run export:ios-curriculum` ile üretilir, elle düzenlenmez.

/// Katalog konusu (web `CatalogTopic`).
public struct CatalogTopic: Decodable, Sendable, Equatable {
    /// Stabil, değişmeyen anahtar (`<subjectKey>.<konu-slug>`).
    public let key: String
    public let name: String
}

/// Katalog dersi (web `CatalogSubject`).
public struct CatalogSubject: Decodable, Sendable, Equatable {
    public let key: String
    public let name: String
    public let exam: ExamType
    public let fields: [YksField]
    /// Bilinmiyorsa `nil`.
    public let questionCount: Int?
    public let topics: [CatalogTopic]
}

/// Müfredat kataloğu (web `Curriculum`).
public struct CurriculumCatalog: Decodable, Sendable, Equatable {
    public let examYear: Int
    public let sources: [String]
    /// Son doğrulama tarihi (`YYYY-MM-DD`).
    public let verifiedAt: String
    public let subjects: [CatalogSubject]

    public enum LoadError: Error, Equatable {
        case resourceMissing
    }

    /// Paket kaynağından kataloğu yükler.
    public static func bundled() throws -> CurriculumCatalog {
        guard let url = Bundle.module.url(forResource: "yks-curriculum", withExtension: "json") else {
            throw LoadError.resourceMissing
        }
        return try JSONDecoder().decode(CurriculumCatalog.self, from: Data(contentsOf: url))
    }

    /// Bir alanın dersleri, katalog sırasıyla (web `subjectsForField`).
    public func subjects(for field: YksField) -> [CatalogSubject] {
        subjects.filter { $0.fields.contains(field) }
    }
}
