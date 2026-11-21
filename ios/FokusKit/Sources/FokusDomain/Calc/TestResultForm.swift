import Foundation

/// Test sonucu formu — SAF yardımcılar (web `features/analysis/testResultForm.ts`). Form alanları ham
/// metin tutar; doğrulama bunları kaydedilecek girdiye dönüştürür ve Türkçe hata mesajları üretir.
public enum TestResultForm {
    /// Serbest metin alanlarının azami uzunluğu.
    public static let maxTextLength = 80

    /// "Kaynak kitap" seçimi.
    public enum Source: Hashable, Sendable {
        case none
        case book(UUID)
        /// Serbest metin kaynak ("Diğer (yaz)").
        case other
    }

    public enum Field: Hashable, Sendable {
        case subject, questionCount, correct, wrong, blank, label, sourceName, date
    }

    public struct Values: Sendable, Equatable {
        public var subjectId: UUID?
        public var topicId: UUID?
        public var source: Source
        public var sourceName: String
        public var label: String
        public var questionCount: String
        public var correct: String
        public var wrong: String
        public var blank: String
        public var blankAuto: Bool
        public var date: Date

        public init(
            subjectId: UUID? = nil, topicId: UUID? = nil, source: Source = .none, sourceName: String = "",
            label: String = "", questionCount: String = "", correct: String = "", wrong: String = "",
            blank: String = "", blankAuto: Bool = true, date: Date
        ) {
            self.subjectId = subjectId
            self.topicId = topicId
            self.source = source
            self.sourceName = sourceName
            self.label = label
            self.questionCount = questionCount
            self.correct = correct
            self.wrong = wrong
            self.blank = blank
            self.blankAuto = blankAuto
            self.date = date
        }
    }

    /// Geçerli formdan kaydedilecek girdi.
    public struct Input: Sendable, Equatable {
        public var subjectId: UUID
        public var topicId: UUID?
        public var bookId: UUID?
        public var sourceName: String?
        public var label: String?
        public var correct: Int
        public var wrong: Int
        public var blank: Int
        public var date: Date

        public init(
            subjectId: UUID, topicId: UUID? = nil, bookId: UUID? = nil, sourceName: String? = nil,
            label: String? = nil, correct: Int, wrong: Int, blank: Int, date: Date
        ) {
            self.subjectId = subjectId
            self.topicId = topicId
            self.bookId = bookId
            self.sourceName = sourceName
            self.label = label
            self.correct = correct
            self.wrong = wrong
            self.blank = blank
            self.date = date
        }
    }

    public enum Validation: Sendable, Equatable {
        case valid(Input)
        case invalid([Field: String])
    }

    public struct Counts: Sendable, Equatable {
        public var correct: Int
        public var wrong: Int
        public var blank: Int

        public init(correct: Int, wrong: Int, blank: Int) {
            self.correct = correct
            self.wrong = wrong
            self.blank = blank
        }
    }

    public enum Message {
        public static let subjectRequired = "Ders seçmelisin."
        public static let countInvalid = "Negatif olmayan bir tam sayı gir."
        public static let questionCountInvalid = "Soru sayısı en az 1 olan bir tam sayı olmalı."
        public static let sumExceeds = "Doğru + yanlış + boş, soru sayısını aşamaz."
        public static let noQuestions = "En az bir soru girmelisin."
        public static let dateInFuture = "Gelecekteki bir tarih seçilemez."
        public static let textTooLong = "En fazla \(maxTextLength) karakter olabilir."

        /// Doğru + yanlış + boş toplamı soru sayısından azsa gösterilen mesaj.
        public static func sumMismatch(sum: Int, questionCount: Int) -> String {
            "Doğru + yanlış + boş (\(sum)) soru sayısına (\(questionCount)) eşit olmalı."
        }
    }

    // MARK: - Başlangıç değerleri

    /// Yeni kayıt için boş form. Boş otomatik hesaplanır.
    public static func emptyValues(today: Date, subjectId: UUID? = nil, topicId: UUID? = nil) -> Values {
        Values(subjectId: subjectId, topicId: topicId, date: today)
    }

    /// Düzenleme için mevcut kayıttan form. Soru sayısı = D + Y + B.
    public static func values(
        subjectId: UUID?, topicId: UUID?, bookId: UUID?, sourceName: String?, label: String?,
        correct: Int, wrong: Int, blank: Int, takenAt: Date
    ) -> Values {
        let name = sourceName ?? ""
        let source: Source =
            if let bookId { .book(bookId) } else if !name.isEmpty { .other } else { .none }
        return Values(
            subjectId: subjectId, topicId: topicId, source: source,
            sourceName: bookId == nil ? name : "", label: label ?? "",
            questionCount: String(correct + wrong + blank), correct: String(correct),
            wrong: String(wrong), blank: String(blank), blankAuto: false, date: takenAt)
    }

    // MARK: - Ayrıştırma

    private static func isDigits(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// Boş alan 0 sayılır; geçersizse `nil`.
    private static func parseCount(_ raw: String) -> Int? {
        let value = raw.trimmingCharacters(in: .whitespaces)
        if value.isEmpty { return 0 }
        return isDigits(value) ? Int(value) : nil
    }

    private enum ParsedQuestionCount: Equatable {
        case notGiven
        case invalid
        case value(Int)
    }

    private static func parseQuestionCount(_ raw: String) -> ParsedQuestionCount {
        let value = raw.trimmingCharacters(in: .whitespaces)
        if value.isEmpty { return .notGiven }
        if isDigits(value), let number = Int(value), number >= 1 { return .value(number) }
        return .invalid
    }

    /// Otomatik boş açıksa ve soru/doğru/yanlış okunabiliyorsa boş = soru − doğru − yanlış.
    /// Negatif çıkarsa olduğu gibi bırakılır; doğrulama "aşamaz" hatası verir.
    public static func resolveBlank(_ values: Values) -> Values {
        guard values.blankAuto,
            case .value(let questions) = parseQuestionCount(values.questionCount),
            let correct = parseCount(values.correct), let wrong = parseCount(values.wrong)
        else { return values }
        var resolved = values
        resolved.blank = String(questions - correct - wrong)
        return resolved
    }

    /// Önizleme için sayılar (boş otomatik çözülmüş); biri geçersizse `nil`.
    public static func previewCounts(_ values: Values) -> Counts? {
        let resolved = resolveBlank(values)
        guard let correct = parseCount(resolved.correct), let wrong = parseCount(resolved.wrong),
            let blank = parseCount(resolved.blank)
        else { return nil }
        return Counts(correct: correct, wrong: wrong, blank: blank)
    }

    // MARK: - Doğrulama

    private struct ParsedCounts {
        var correct: Int?
        var wrong: Int?
        var blank: Int?
    }

    private static func validateCounts(_ values: Values, errors: inout [Field: String]) -> ParsedCounts {
        let resolved = resolveBlank(values)
        let correct = parseCount(resolved.correct)
        let wrong = parseCount(resolved.wrong)
        let negativeAutoBlank =
            resolved.blankAuto && resolved.blank.hasPrefix("-") && isDigits(String(resolved.blank.dropFirst()))
        let blank = negativeAutoBlank ? nil : parseCount(resolved.blank)
        let questions = parseQuestionCount(resolved.questionCount)

        if correct == nil { errors[.correct] = Message.countInvalid }
        if wrong == nil { errors[.wrong] = Message.countInvalid }
        if blank == nil && !negativeAutoBlank { errors[.blank] = Message.countInvalid }
        let parsed = ParsedCounts(correct: correct, wrong: wrong, blank: blank)
        if questions == .invalid {
            errors[.questionCount] = Message.questionCountInvalid
            return parsed
        }
        guard let correct, let wrong else { return parsed }

        if case .value(let questionTotal) = questions {
            let sum = correct + wrong + (blank ?? 0)
            if negativeAutoBlank || sum > questionTotal {
                errors[.questionCount] = Message.sumExceeds
            } else if blank != nil && sum < questionTotal {
                errors[.questionCount] = Message.sumMismatch(sum: sum, questionCount: questionTotal)
            }
        } else if let blank, correct + wrong + blank == 0 {
            errors[.questionCount] = Message.noQuestions
        }
        return parsed
    }

    private static func optionalText(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// Formu doğrular; geçerliyse kaydedilecek girdiyi, değilse alan bazlı Türkçe hataları döner.
    public static func validate(
        _ values: Values, today: Date, calendar: Calendar = .current
    ) -> Validation {
        var errors: [Field: String] = [:]
        if values.subjectId == nil { errors[.subject] = Message.subjectRequired }
        let counts = validateCounts(values, errors: &errors)
        if Identifiers.isoDate(values.date, calendar: calendar) > Identifiers.isoDate(today, calendar: calendar) {
            errors[.date] = Message.dateInFuture
        }

        var bookId: UUID?
        var sourceName: String?
        switch values.source {
        case .none: break
        case .book(let id): bookId = id
        case .other: sourceName = optionalText(values.sourceName)
        }
        let label = optionalText(values.label)
        if (label?.count ?? 0) > maxTextLength { errors[.label] = Message.textTooLong }
        if (sourceName?.count ?? 0) > maxTextLength { errors[.sourceName] = Message.textTooLong }

        guard errors.isEmpty, let subjectId = values.subjectId, let correct = counts.correct,
            let wrong = counts.wrong, let blank = counts.blank
        else { return .invalid(errors) }
        return .valid(
            Input(
                subjectId: subjectId, topicId: values.topicId, bookId: bookId, sourceName: sourceName,
                label: label, correct: correct, wrong: wrong, blank: blank, date: values.date))
    }

    // MARK: - Kayıt zamanı

    /// Seçilen günün kayıt zamanı: bugünse şu an, değilse o günün YEREL öğleni (gün kaymasın diye).
    public static func takenAt(for date: Date, now: Date, calendar: Calendar = .current) -> Date {
        if Identifiers.isoDate(date, calendar: calendar) == Identifiers.isoDate(now, calendar: calendar) {
            return now
        }
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(
            from: DateComponents(year: parts.year, month: parts.month, day: parts.day, hour: 12)) ?? date
    }

    /// Düzenlemede: gün değişmediyse mevcut zaman korunur; değiştiyse `takenAt(for:)`.
    public static func takenAt(
        for date: Date, existing: Date, now: Date, calendar: Calendar = .current
    ) -> Date {
        Identifiers.isoDate(date, calendar: calendar) == Identifiers.isoDate(existing, calendar: calendar)
            ? existing : takenAt(for: date, now: now, calendar: calendar)
    }
}
