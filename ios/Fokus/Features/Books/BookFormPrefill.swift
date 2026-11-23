import FokusData
import FokusDomain
import Foundation

/// Barkod akışından gelen, `BookFormView`'u önceden dolduran değerler.
struct BookFormPrefill: Identifiable {
    let id = UUID()
    var title = ""
    var publisher = ""
    var subjectId: UUID?
    var kind: BookKind = .questionBank
    var unit: BookUnit = .test
    var totalUnits: Int?
    var barcode: String?
    var libraryKey: String?
    var sections: [BookSectionInput] = []
    /// Formun üstünde gösterilen bilgi satırı.
    var notice: String?

    static let notFoundNotice = "Bu kitap kütüphanede yok. Bilgileri elle gir."

    /// Katalogda bulunan kitap.
    init(resolved: ResolvedLibraryBook) {
        title = resolved.title
        publisher = resolved.publisher ?? ""
        subjectId = resolved.subjectId
        kind = resolved.kind
        unit = resolved.unit
        totalUnits = resolved.totalUnits
        barcode = resolved.barcode
        libraryKey = resolved.libraryKey
        sections = resolved.sections.map {
            BookSectionInput(
                title: $0.title, order: $0.order, startUnit: $0.startUnit, endUnit: $0.endUnit,
                topicId: $0.topicId)
        }
    }

    /// Katalogda olmayan kitap: yalnızca barkod dolu.
    init(notFoundBarcode barcode: String) {
        self.barcode = barcode
        notice = Self.notFoundNotice
    }
}
