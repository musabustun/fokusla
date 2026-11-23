import Foundation
import Testing

@testable import FokusDomain

// Barkod akışı kararı ve bölüm aralığı biçimi. Kitaplar sentetiktir.
struct BookScanResolverTests {
    static let library = BookLibrary(
        version: 1, updatedAt: "2026-11-24",
        books: [
            LibraryBook(
                key: "ornek-tyt-mat", barcodes: ["9781234567897"], title: "Örnek TYT Matematik",
                publisher: "Örnek Yayınları", kind: .questionBank, exam: .tyt,
                subjectCatalogKey: "tyt-matematik", unit: .test, totalUnits: 40, editionYear: 2026,
                sections: [
                    LibrarySection(
                        title: "Temel Kavramlar", order: 1, startUnit: 1, endUnit: 10, topicCatalogKey: nil)
                ])
        ])
    static let existingId = UUID()

    @Test("Geçersiz metin → invalid", arguments: ["", "abc", "123", "9781234567890", "12345678901234"])
    func invalid(raw: String) {
        #expect(BookScanResolver.resolve(raw, library: Self.library, existingBooks: [:]) == .invalid)
    }

    @Test func existingWinsOverLibrary() {
        let outcome = BookScanResolver.resolve(
            "978-1-2345-6789-7", library: Self.library, existingBooks: ["9781234567897": Self.existingId])
        #expect(outcome == .existing(bookId: Self.existingId))
    }

    @Test func foundInLibrary() {
        let outcome = BookScanResolver.resolve(" 9781234567897 ", library: Self.library, existingBooks: [:])
        guard case .found(let book) = outcome else {
            Issue.record("found bekleniyordu: \(outcome)")
            return
        }
        #expect(book.libraryKey == "ornek-tyt-mat")
        #expect(book.barcode == "9781234567897")
        #expect(book.sections.count == 1)
    }

    @Test func notFoundCarriesNormalizedBarcode() {
        // ISBN-10 → EAN-13 (978 öneki); katalogda olmayan geçerli barkod.
        let outcome = BookScanResolver.resolve("9780306406157", library: Self.library, existingBooks: [:])
        #expect(outcome == .notFound(barcode: "9780306406157"))
        let fromIsbn10 = BookScanResolver.resolve("0306406152", library: Self.library, existingBooks: [:])
        #expect(fromIsbn10 == .notFound(barcode: "9780306406157"))
    }
}

struct SectionRangeFormatTests {
    fileprivate struct Case: Sendable, CustomTestStringConvertible {
        let unit: BookUnit
        let start: Int?
        let end: Int?
        let expected: String?
        var testDescription: String { "\(unit) \(String(describing: start))-\(String(describing: end))" }
    }

    fileprivate static let cases: [Case] = [
        Case(unit: .test, start: 1, end: 12, expected: "Test 1\u{2013}12"),
        Case(unit: .page, start: 10, end: 40, expected: "Sayfa 10\u{2013}40"),
        Case(unit: .section, start: 2, end: 3, expected: "Bölüm 2\u{2013}3"),
        Case(unit: .test, start: 5, end: 5, expected: "Test 5"),
        Case(unit: .test, start: 5, end: nil, expected: "Test 5"),
        Case(unit: .page, start: nil, end: 30, expected: "Sayfa 30"),
        Case(unit: .page, start: nil, end: nil, expected: nil),
        Case(unit: .page, start: 1, end: 1200, expected: "Sayfa 1\u{2013}1.200"),
    ]

    @Test(arguments: cases)
    fileprivate func sectionRange(_ item: Case) {
        #expect(BooksFormat.sectionRange(item.unit, start: item.start, end: item.end) == item.expected)
    }
}
