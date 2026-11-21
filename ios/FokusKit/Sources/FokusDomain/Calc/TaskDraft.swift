import Foundation

/// Doğrulanmış, kaydedilmeye hazır görev değerleri (oluşturma ve düzenleme ortak).
public struct TaskValues: Sendable, Equatable {
    public var kind: TaskKind
    public var title: String
    public var notes: String?
    public var subjectId: UUID?
    /// Yalnızca ödev; rutinde `nil`.
    public var dueDate: ISODate?
    /// Yalnızca rutin; ödevde `nil`.
    public var recurrence: RecurrenceRule?
    public var targetQuantity: Int?
    public var quantityUnit: String?

    public init(
        kind: TaskKind, title: String, notes: String? = nil, subjectId: UUID? = nil,
        dueDate: ISODate? = nil, recurrence: RecurrenceRule? = nil, targetQuantity: Int? = nil,
        quantityUnit: String? = nil
    ) {
        self.kind = kind
        self.title = title
        self.notes = notes
        self.subjectId = subjectId
        self.dueDate = dueDate
        self.recurrence = recurrence
        self.targetQuantity = targetQuantity
        self.quantityUnit = quantityUnit
    }
}

/// Görev formunun ham (metin tabanlı) durumu + doğrulama. Web `features/tasks/taskModel.ts`
/// (`TaskDraft`, `validateDraft`, `parseQuantity`) karşılığı; hata metinleri birebir aynıdır.
public struct TaskDraft: Sendable, Equatable {
    public static let titleMaxLength = 120
    public static let notesMaxLength = 1000
    public static let quantityMax = 10_000
    public static let unitMaxLength = 24

    /// Hata verebilen alanlar.
    public enum Field: String, Sendable, CaseIterable {
        case title, notes, weekdays, dueDate, targetQuantity, quantityUnit
    }

    /// `validate()` sonucu.
    public enum Validation: Sendable, Equatable {
        case valid(TaskValues)
        /// Alan → Türkçe hata mesajı.
        case invalid([Field: String])
    }

    /// `parseQuantity` sonucu.
    public enum ParsedQuantity: Sendable, Equatable {
        /// Boş / yalnızca boşluk (miktar yok).
        case empty
        case value(Int)
        /// Tam sayı değil ya da ≤ 0.
        case notPositiveInteger
        /// Pozitif tam sayı ama `quantityMax`'tan büyük.
        case tooLarge
    }

    public var kind: TaskKind
    public var title: String
    public var notes: String
    public var subjectId: UUID?
    /// Rutin tekrarı.
    public var frequency: RecurrenceFrequency
    /// Rutin + haftalık: seçili ISO günleri.
    public var weekdays: [Int]
    /// Ödev: `YYYY-MM-DD` ("" = girilmedi).
    public var dueDate: String
    /// "" = hedef yok; aksi halde pozitif tam sayı metni (`1.000` kabul edilir).
    public var targetQuantity: String
    public var quantityUnit: String

    public init(
        kind: TaskKind, title: String = "", notes: String = "", subjectId: UUID? = nil,
        frequency: RecurrenceFrequency = .daily, weekdays: [Int] = [], dueDate: String = "",
        targetQuantity: String = "", quantityUnit: String = ""
    ) {
        self.kind = kind
        self.title = title
        self.notes = notes
        self.subjectId = subjectId
        self.frequency = frequency
        self.weekdays = weekdays
        self.dueDate = dueDate
        self.targetQuantity = targetQuantity
        self.quantityUnit = quantityUnit
    }

    /// Yeni görev için boş taslak. Ödevin varsayılan son tarihi `today`; rutin varsayılanı günlük.
    public static func empty(_ kind: TaskKind, today: ISODate) -> TaskDraft {
        // `dueDate` rutinde yok sayılır; formda tür değiştirilirse ödev için hazır bir varsayılan olur.
        TaskDraft(kind: kind, dueDate: today)
    }

    // MARK: - Doğrulama

    /// Taslağı doğrular ve normalize eder (kırp, boş → `nil`, günler sıralı/tekil, günlük → `weekdays` boş).
    /// Hatalar: başlık boş/uzun, haftalık + gün yok, ödev + son tarih yok/geçersiz, miktar tam sayı
    /// değil/≤ 0/> `quantityMax`, birim uzun, not uzun. Rutinde `dueDate` `nil`; ödevde `recurrence` `nil`.
    public func validate() -> Validation {
        var errors: [Field: String] = [:]
        let isRoutine = kind == .routine

        let trimmedTitle = title.trimmed
        if trimmedTitle.isEmpty {
            errors[.title] = "Başlık gerekli"
        } else if trimmedTitle.count > Self.titleMaxLength {
            errors[.title] = "Başlık en fazla \(TaskFormatting.number(Self.titleMaxLength)) karakter olabilir"
        }

        let trimmedNotes = notes.trimmed
        if trimmedNotes.count > Self.notesMaxLength {
            errors[.notes] = "Not en fazla \(TaskFormatting.number(Self.notesMaxLength)) karakter olabilir"
        }

        let normalizedWeekdays = frequency == .weekly ? Self.normalizeWeekdays(weekdays) : []
        if isRoutine, frequency == .weekly, normalizedWeekdays.isEmpty {
            errors[.weekdays] = "En az bir gün seç"
        }

        let trimmedDueDate = dueDate.trimmed
        if !isRoutine {
            if trimmedDueDate.isEmpty {
                errors[.dueDate] = "Son tarih gerekli"
            } else if !Self.isValidISODate(trimmedDueDate) {
                errors[.dueDate] = "Geçerli bir tarih gir"
            }
        }

        let quantity = Self.parseQuantity(targetQuantity)
        switch quantity {
        case .notPositiveInteger: errors[.targetQuantity] = "Pozitif bir tam sayı gir"
        case .tooLarge: errors[.targetQuantity] = "En fazla \(TaskFormatting.number(Self.quantityMax)) olabilir"
        case .empty, .value: break
        }

        let trimmedUnit = quantityUnit.trimmed
        if trimmedUnit.count > Self.unitMaxLength {
            errors[.quantityUnit] = "Birim en fazla \(TaskFormatting.number(Self.unitMaxLength)) karakter olabilir"
        }

        guard errors.isEmpty else { return .invalid(errors) }

        var target: Int?
        if case let .value(amount) = quantity { target = amount }
        return .valid(TaskValues(
            kind: kind,
            title: trimmedTitle,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            subjectId: subjectId,
            dueDate: isRoutine ? nil : trimmedDueDate,
            recurrence: isRoutine ? RecurrenceRule(frequency: frequency, weekdays: normalizedWeekdays) : nil,
            targetQuantity: target,
            quantityUnit: trimmedUnit.isEmpty ? nil : trimmedUnit))
    }

    // MARK: - Yardımcılar

    /// Kullanıcı girdisi miktar: boş → `.empty`; rakam ya da Türkçe binlik ayraçlı (`1.000`) pozitif tam sayı
    /// → `.value`; `quantityMax`'tan büyük → `.tooLarge`; diğer her şey → `.notPositiveInteger`.
    public static func parseQuantity(_ input: String) -> ParsedQuantity {
        let trimmed = input.trimmed
        if trimmed.isEmpty { return .empty }
        guard trimmed.wholeMatch(of: /(?:[0-9]+|[0-9]{1,3}(?:\.[0-9]{3})+)/) != nil else {
            return .notPositiveInteger
        }
        guard let value = Int(trimmed.replacingOccurrences(of: ".", with: "")) else { return .tooLarge }
        if value <= 0 { return .notPositiveInteger }
        return value > quantityMax ? .tooLarge : .value(value)
    }

    /// Geçerli (1…7), tekil ve artan sıralı yeni dizi.
    public static func normalizeWeekdays(_ weekdays: [Int]) -> [Int] {
        Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
    }

    /// `YYYY-MM-DD` biçiminde ve gerçek bir takvim günü mü (ör. 2026-02-30 değil).
    public static func isValidISODate(_ value: String) -> Bool {
        guard value.wholeMatch(of: /[0-9]{4}-[0-9]{2}-[0-9]{2}/) != nil else { return false }
        return TasksCalc.addDays(value, 0) == value
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
