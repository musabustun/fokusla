import Testing

@testable import FokusDomain

// Web karşılığı: `web/src/domain/barcode.test.ts` — vaka adları ve değerleri birebir aynı.
// Numaralar sentetiktir, gerçek ürün değildir; sağlama basamakları elle hesaplanmıştır.
struct BarcodeTests {
    struct NormalizeCase: Sendable, CustomTestStringConvertible {
        let name: String
        let input: String
        let expected: String?
        var testDescription: String { name }
    }

    static let normalizeCases: [NormalizeCase] = [
        .init(name: "geçerli EAN-13 aynen", input: "9781234567897", expected: "9781234567897"),
        .init(name: "sıfırlı EAN-13", input: "9780000000002", expected: "9780000000002"),
        .init(name: "tireli EAN-13", input: "978-1-23-456789-7", expected: "9781234567897"),
        .init(name: "boşluklu EAN-13", input: " 978 1234 5678 97 ", expected: "9781234567897"),
        .init(name: "ISBN-10 X sağlamalı", input: "123456789X", expected: "9781234567897"),
        .init(name: "ISBN-10 küçük x", input: "123456789x", expected: "9781234567897"),
        .init(name: "ISBN-10 rakam sağlamalı", input: "0000000019", expected: "9780000000019"),
        .init(name: "ISBN-10 tireli", input: "1-234-56789-X", expected: "9781234567897"),
        .init(name: "UPC-A öne 0 eklenir", input: "012345678905", expected: "0012345678905"),
        .init(name: "EAN-13 sağlaması yanlış", input: "9781234567890", expected: nil),
        .init(name: "ISBN-10 sağlaması yanlış", input: "1234567890", expected: nil),
        .init(name: "UPC-A sağlaması yanlış", input: "978123456789", expected: nil),
        .init(name: "boş metin", input: "", expected: nil),
        .init(name: "yalnızca ayırıcılar", input: " - - ", expected: nil),
        .init(name: "harf içeren 13 karakter", input: "97812345678AB", expected: nil),
        .init(name: "harf içeren 12 karakter", input: "97812345678A", expected: nil),
        .init(name: "X ortada ISBN-10", input: "12345X7890", expected: nil),
        .init(name: "14 hane", input: "97812345678970", expected: nil),
        .init(name: "9 hane", input: "123456789", expected: nil),
    ]

    @Test(arguments: normalizeCases)
    func normalize(_ testCase: NormalizeCase) {
        #expect(Barcode.normalize(testCase.input) == testCase.expected)
    }

    struct EanCase: Sendable, CustomTestStringConvertible {
        let name: String
        let input: String
        let expected: Bool
        var testDescription: String { name }
    }

    static let eanCases: [EanCase] = [
        .init(name: "ean geçerli", input: "9781234567897", expected: true),
        .init(name: "ean yanlış sağlama", input: "9781234567898", expected: false),
        .init(name: "ean kısa", input: "978123456789", expected: false),
        .init(name: "ean harf", input: "978123456789X", expected: false),
    ]

    @Test(arguments: eanCases)
    func isValidEAN13(_ testCase: EanCase) {
        #expect(Barcode.isValidEAN13(testCase.input) == testCase.expected)
    }

    static let isbnCases: [NormalizeCase] = [
        .init(name: "isbn10 X", input: "123456789X", expected: "9781234567897"),
        .init(name: "isbn10 sıfırlar", input: "0000000000", expected: "9780000000002"),
        .init(name: "isbn10 yanlış sağlama", input: "1234567890", expected: nil),
        .init(name: "isbn10 kısa", input: "12345", expected: nil),
    ]

    @Test(arguments: isbnCases)
    func isbn10ToEAN13(_ testCase: NormalizeCase) {
        #expect(Barcode.isbn10ToEAN13(testCase.input) == testCase.expected)
    }
}
