import Testing

@testable import FokusDomain

// Kullanıcı tanımlı ders/konu adı doğrulaması testleri — web `entityName.test.ts` ile aynı vakalar.

private struct NameCase: Sendable, CustomTestStringConvertible {
    var raw: String
    var max: Int
    var expected: EntityNameValidation.Result
    var testDescription: String { "\"\(raw)\" → \(expected)" }
}

private let nameCases: [NameCase] = [
    NameCase(raw: "Geometri", max: 60, expected: .valid("Geometri")),
    NameCase(raw: "  Paragraf   Soruları ", max: 60, expected: .valid("Paragraf Soruları")),
    NameCase(raw: "", max: 5, expected: .invalid("Ders adı boş olamaz.")),
    NameCase(raw: "   ", max: 5, expected: .invalid("Ders adı boş olamaz.")),
    NameCase(raw: "abcde", max: 5, expected: .valid("abcde")),
    NameCase(raw: "abcdef", max: 5, expected: .invalid("Ders adı en fazla 5 karakter olabilir.")),
]

@Suite("EntityNameValidation")
struct EntityNameValidationTests {
    @Test("validate", arguments: nameCases)
    fileprivate func validate(_ c: NameCase) {
        #expect(EntityNameValidation.validate(c.raw, label: "Ders adı", maxLength: c.max) == c.expected)
    }

    @Test("sekme, satır sonu ve tekrarlı boşluklar teke iner")
    func collapsesAllWhitespace() {
        let result = EntityNameValidation.validate("\tTürev \n  İntegral\u{00A0}Limit ", label: "Konu adı", maxLength: 80)
        #expect(result == .valid("Türev İntegral Limit"))
    }

    @Test("uzunluk sınırı kırpılmış ada uygulanır")
    func lengthAppliesToNormalizedName() {
        #expect(EntityNameValidation.validate("  abcde  ", label: "Konu adı", maxLength: 5) == .valid("abcde"))
        #expect(
            EntityNameValidation.validate("ab  cd", label: "Konu adı", maxLength: 4)
                == .invalid("Konu adı en fazla 4 karakter olabilir."))
    }

    @Test("sabitler")
    func constants() {
        #expect(EntityNameValidation.maxSubjectNameLength == 60)
        #expect(EntityNameValidation.maxTopicNameLength == 80)
    }
}
