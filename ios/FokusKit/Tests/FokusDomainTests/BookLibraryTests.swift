import Foundation
import Testing

@testable import FokusDomain

// Web karşılığı: `web/src/library/lookup.test.ts`. Kitaplar sentetiktir.
struct BookLibraryTests {
    static let json = """
        {
          "version": 1,
          "updatedAt": "2026-11-23",
          "books": [
            {
              "key": "ornek-yayinlari-tyt-matematik-soru-bankasi",
              "barcodes": ["9781234567897"],
              "title": "Örnek Yayınları TYT Matematik Soru Bankası",
              "publisher": "Örnek Yayınları",
              "kind": "questionBank",
              "exam": "TYT",
              "subjectCatalogKey": "tyt-matematik",
              "unit": "test",
              "totalUnits": 40,
              "editionYear": 2026,
              "sections": [
                { "title": "Temel Kavramlar", "order": 1, "startUnit": 1, "endUnit": 10,
                  "topicCatalogKey": "tyt-matematik.temel-kavramlar" },
                { "title": "Karma", "order": 2, "startUnit": 11, "endUnit": 40, "topicCatalogKey": null }
              ]
            },
            {
              "key": "ornek-yayinlari-genel",
              "barcodes": ["9780000000002", "9780000000019"],
              "title": "Örnek Yayınları Genel",
              "publisher": null,
              "kind": "other",
              "exam": null,
              "subjectCatalogKey": null,
              "unit": "page",
              "totalUnits": null,
              "editionYear": null,
              "sections": []
            }
          ]
        }
        """

    static func library() throws -> BookLibrary {
        try JSONDecoder().decode(BookLibrary.self, from: Data(json.utf8))
    }

    @Test func decodesCatalog() throws {
        let library = try Self.library()
        #expect(library.version == 1)
        #expect(library.books.count == 2)
        #expect(library.books[0].kind == .questionBank)
        #expect(library.books[0].sections[1].topicCatalogKey == nil)
        #expect(library.books[1].publisher == nil)
    }

    @Test(arguments: [
        ("9781234567897", "ornek-yayinlari-tyt-matematik-soru-bankasi"),
        ("978-1-23-456789-7", "ornek-yayinlari-tyt-matematik-soru-bankasi"),
        ("123456789X", "ornek-yayinlari-tyt-matematik-soru-bankasi"),
        ("9780000000019", "ornek-yayinlari-genel"),
        ("0000000019", "ornek-yayinlari-genel"),
    ])
    func findsBook(raw: String, key: String) throws {
        #expect(BookLibraryLookup.find(in: try Self.library(), barcode: raw)?.key == key)
    }

    @Test(arguments: ["9780000000026", "9781234567890", ""])
    func returnsNilWhenNotFound(raw: String) throws {
        #expect(BookLibraryLookup.find(in: try Self.library(), barcode: raw) == nil)
    }

    @Test func resolvesCatalogIds() throws {
        let book = try #require(Self.library().books.first)
        let resolved = book.resolved(barcode: "123456789X")
        #expect(resolved.libraryKey == book.key)
        #expect(resolved.barcode == "9781234567897")
        #expect(resolved.subjectId == Identifiers.catalogEntityId("tyt-matematik"))
        #expect(resolved.sections[0].topicId == Identifiers.catalogEntityId("tyt-matematik.temel-kavramlar"))
        #expect(resolved.sections[1].topicId == nil)
        #expect(resolved.unit == .test)
        #expect(resolved.totalUnits == 40)
    }

    @Test func resolvedWithoutBarcodeOrSubject() throws {
        let book = try #require(Self.library().books.last)
        let resolved = book.resolved()
        #expect(resolved.barcode == nil)
        #expect(resolved.subjectId == nil)
        #expect(book.resolved(barcode: "abc").barcode == nil)
    }
}
