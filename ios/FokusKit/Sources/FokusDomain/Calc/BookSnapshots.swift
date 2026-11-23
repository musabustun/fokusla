import Foundation

// Kitap hesaplarının (`BooksCalc`) girdisi olan SAF değer tipleri. `Snapshots.swift` gibi
// SwiftData'yı bilmez; FokusData'daki `Book` / `BookProgress` `@Model`'leri bunlara dönüşür.

/// `Book`'un hesaplar için gereken alanları (web `Book`, `domain/types.ts`).
public struct BookSnapshot: Sendable, Hashable, Identifiable {
    /// Kitabın kimliği (UUID v4).
    public var id: UUID
    /// Kitap adı.
    public var title: String
    /// Yayınevi; yoksa nil.
    public var publisher: String?
    /// Kitap türü.
    public var kind: BookKind
    /// Bağlı ders (`Subject.id`); ders seçilmediyse nil.
    public var subjectId: UUID?
    /// Hedef sınav oturumu; belirtilmediyse nil.
    public var exam: ExamType?
    /// İlerleme birimi (sayfa, test, bölüm).
    public var unit: BookUnit
    /// Toplam birim sayısı; bilinmiyorsa nil (0 ve negatif değerler de "bilinmiyor" sayılır).
    public var totalUnits: Int?
    /// Bitmeden rafa kaldırıldığı an; arşivde değilse nil.
    public var archivedAt: Date?
    /// Normalize EAN-13 barkodu; yoksa nil.
    public var barcode: String?
    /// Gömülü katalog kaydının kalıcı anahtarı; yoksa nil.
    public var libraryKey: String?
    /// Oluşturulma zamanı.
    public var createdAt: Date
    /// Son güncelleme zamanı (liste sıralamasında `activityAt` için kullanılır).
    public var updatedAt: Date
    /// Soft-delete zamanı; silinmemişse nil.
    public var deletedAt: Date?

    /// Tüm alanlarla oluşturur; isteğe bağlı alanların varsayılanı nil, tür `.other`, birim `.page`.
    public init(
        id: UUID, title: String, publisher: String? = nil, kind: BookKind = .other,
        subjectId: UUID? = nil, exam: ExamType? = nil, unit: BookUnit = .page,
        totalUnits: Int? = nil, archivedAt: Date? = nil, createdAt: Date, updatedAt: Date,
        deletedAt: Date? = nil, barcode: String? = nil, libraryKey: String? = nil
    ) {
        self.id = id
        self.title = title
        self.publisher = publisher
        self.kind = kind
        self.subjectId = subjectId
        self.exam = exam
        self.unit = unit
        self.totalUnits = totalUnits
        self.archivedAt = archivedAt
        self.barcode = barcode
        self.libraryKey = libraryKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

/// `BookProgress`'in hesaplar için gereken alanları (web `BookProgress`).
public struct BookProgressSnapshot: Sendable, Hashable, Identifiable {
    /// Kaydın kimliği (UUID v4).
    public var id: UUID
    /// Kaydın ait olduğu kitap (`Book.id`); bağ yoksa ya da bilinmiyorsa nil.
    public var bookId: UUID?
    /// Ulaşılan birim ("34. test", "210. sayfa").
    public var reachedUnit: Int
    /// İlgili konu (`Topic.id`); yoksa nil.
    public var topicId: UUID?
    /// İlerlemenin kaydedildiği an (kullanıcı geçmişe dönük girebilir).
    public var recordedAt: Date
    /// Serbest not; yoksa nil.
    public var note: String?
    /// Oluşturulma zamanı (aynı `recordedAt`'li kayıtlarda sıralama için).
    public var createdAt: Date
    /// Soft-delete zamanı; silinmemişse nil.
    public var deletedAt: Date?

    /// Tüm alanlarla oluşturur; isteğe bağlı alanların varsayılanı nil.
    public init(
        id: UUID, bookId: UUID?, reachedUnit: Int, topicId: UUID? = nil, recordedAt: Date,
        note: String? = nil, createdAt: Date, deletedAt: Date? = nil
    ) {
        self.id = id
        self.bookId = bookId
        self.reachedUnit = reachedUnit
        self.topicId = topicId
        self.recordedAt = recordedAt
        self.note = note
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }
}

/// `BookSection`'ın değer tipi karşılığı (web `BookSection`).
public struct BookSectionSnapshot: Sendable, Hashable, Identifiable {
    /// Bölümün kimliği (UUID v4).
    public var id: UUID
    /// Bölümün ait olduğu kitap (`Book.id`); bağ yoksa nil.
    public var bookId: UUID?
    /// Bölüm başlığı.
    public var title: String
    /// Kitap içindeki sıra (artan).
    public var order: Int
    /// Bölümün ilk birimi; bilinmiyorsa nil.
    public var startUnit: Int?
    /// Bölümün son birimi (dahil); bilinmiyorsa nil.
    public var endUnit: Int?
    /// Eşlendiği konu (`Topic.id`); yoksa nil.
    public var topicId: UUID?
    /// Oluşturulma zamanı.
    public var createdAt: Date
    /// Soft-delete zamanı; silinmemişse nil.
    public var deletedAt: Date?

    public init(
        id: UUID, bookId: UUID? = nil, title: String, order: Int, startUnit: Int? = nil,
        endUnit: Int? = nil, topicId: UUID? = nil, createdAt: Date, deletedAt: Date? = nil
    ) {
        self.id = id
        self.bookId = bookId
        self.title = title
        self.order = order
        self.startUnit = startUnit
        self.endUnit = endUnit
        self.topicId = topicId
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }
}
