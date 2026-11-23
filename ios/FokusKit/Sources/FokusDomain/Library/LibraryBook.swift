import Foundation

// Gömülü kitap kütüphanesi (web `web/src/library/types.ts`). Paketle gelen `book-library.json`
// `npm run export:ios-library` ile üretilir; elle düzenlenmez.

/// Katalog kitabının bölümü.
public struct LibrarySection: Decodable, Sendable, Equatable {
    public let title: String
    public let order: Int
    public let startUnit: Int?
    public let endUnit: Int?
    /// Müfredat konusu anahtarı; yoksa `nil`.
    public let topicCatalogKey: String?

    public init(title: String, order: Int, startUnit: Int?, endUnit: Int?, topicCatalogKey: String?) {
        self.title = title
        self.order = order
        self.startUnit = startUnit
        self.endUnit = endUnit
        self.topicCatalogKey = topicCatalogKey
    }
}

/// Katalog kitabı.
public struct LibraryBook: Decodable, Sendable, Equatable {
    /// Stabil, değişmeyen anahtar (`Book.libraryKey`).
    public let key: String
    /// Normalleştirilmiş EAN-13 barkodlar.
    public let barcodes: [String]
    public let title: String
    public let publisher: String?
    public let kind: BookKind
    public let exam: ExamType?
    public let subjectCatalogKey: String?
    public let unit: BookUnit
    public let totalUnits: Int?
    public let editionYear: Int?
    public let sections: [LibrarySection]

    public init(
        key: String, barcodes: [String], title: String, publisher: String?, kind: BookKind,
        exam: ExamType?, subjectCatalogKey: String?, unit: BookUnit, totalUnits: Int?,
        editionYear: Int?, sections: [LibrarySection]
    ) {
        self.key = key
        self.barcodes = barcodes
        self.title = title
        self.publisher = publisher
        self.kind = kind
        self.exam = exam
        self.subjectCatalogKey = subjectCatalogKey
        self.unit = unit
        self.totalUnits = totalUnits
        self.editionYear = editionYear
        self.sections = sections
    }
}

/// Kitap kataloğu.
public struct BookLibrary: Decodable, Sendable, Equatable {
    public let version: Int
    /// Son güncelleme tarihi (`YYYY-MM-DD`).
    public let updatedAt: String
    public let books: [LibraryBook]

    public init(version: Int, updatedAt: String, books: [LibraryBook]) {
        self.version = version
        self.updatedAt = updatedAt
        self.books = books
    }
}

/// Kitap formunu dolduracak düz değer (web `ResolvedLibraryBook`).
public struct ResolvedLibraryBook: Sendable, Equatable {
    public struct Section: Sendable, Equatable {
        public let title: String
        public let order: Int
        public let startUnit: Int?
        public let endUnit: Int?
        public let topicId: UUID?
    }

    public let libraryKey: String
    /// Aranan (normalleştirilmiş) barkod; verilmediyse `nil`.
    public let barcode: String?
    public let title: String
    public let publisher: String?
    public let kind: BookKind
    public let exam: ExamType?
    public let subjectId: UUID?
    public let unit: BookUnit
    public let totalUnits: Int?
    public let sections: [Section]
}

extension LibraryBook {
    /// Ders/konu anahtarlarını `catalogEntityId` ile UUID'ye çevirerek form değerine dönüştürür.
    /// Geçersiz barkod verilirse `barcode` `nil` olur.
    public func resolved(barcode: String? = nil) -> ResolvedLibraryBook {
        ResolvedLibraryBook(
            libraryKey: key,
            barcode: barcode.flatMap(Barcode.normalize),
            title: title,
            publisher: publisher,
            kind: kind,
            exam: exam,
            subjectId: subjectCatalogKey.map(Identifiers.catalogEntityId),
            unit: unit,
            totalUnits: totalUnits,
            sections: sections.map {
                ResolvedLibraryBook.Section(
                    title: $0.title, order: $0.order, startUnit: $0.startUnit, endUnit: $0.endUnit,
                    topicId: $0.topicCatalogKey.map(Identifiers.catalogEntityId)
                )
            }
        )
    }
}

/// Barkodla katalog araması (web `findLibraryBook`).
public enum BookLibraryLookup {
    /// Ham barkodu normalleştirip eşleşen kaydı döndürür; geçersiz barkod veya eşleşme yoksa `nil`.
    public static func find(in library: BookLibrary, barcode raw: String) -> LibraryBook? {
        guard let barcode = Barcode.normalize(raw) else { return nil }
        return library.books.first { $0.barcodes.contains(barcode) }
    }
}
