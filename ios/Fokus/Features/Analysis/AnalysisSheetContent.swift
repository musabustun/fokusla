import FokusData
import FokusDesign
import FokusDomain
import SwiftUI

/// `AnalysisSheet` → ilgili sayfa.
struct AnalysisSheetContent: View {
    let sheet: AnalysisSheet
    let data: AnalysisData
    let onSubjectSaved: (Subject) -> Void
    let onClose: () -> Void

    var body: some View {
        switch sheet {
        case .test(let editing, let subjectId, let topicId):
            TestResultSheet(
                data: data, editing: editing, defaultSubjectId: subjectId, defaultTopicId: topicId,
                onClose: onClose)
        case .subject(let editing):
            SubjectSheet(
                field: data.field, editing: editing,
                existingCount: data.subjects.filter { !$0.isCatalogEntry }.count,
                onSaved: onSubjectSaved, onClose: onClose)
        case .topic(let subjectId, let editing):
            TopicSheet(
                subjectId: subjectId, editing: editing,
                existingCount: (data.topicsBySubject[subjectId] ?? []).filter { !$0.isCatalogEntry }.count,
                onClose: onClose)
        }
    }
}

/// Sheet'lerde ortak: kaydetme hatası, hata metni ve silme onayı için yardımcılar.
enum AnalysisSheetText {
    static let saveFailed = "Kaydedilemedi. Tekrar dene."
    static let deleteConfirmTitle = "Silmek istediğine emin misin?"
    static let subjectDeleteMessage =
        "Bu ders, konuları ve test sonuçları silinecek. Silmek istediğine emin misin?"
    static let topicDeleteMessage =
        "Konu silinecek; test sonuçları derste \"Konu seçilmedi\" olarak kalır. Silmek istediğine emin misin?"
}

/// Form alanının altındaki hata metni.
struct FieldErrorText: View {
    let text: String?

    var body: some View {
        if let text {
            Text(text)
                .fokusTextStyle(.footnote)
                .foregroundStyle(.fkDanger)
                .accessibilityIdentifier("analysis.fieldError")
        }
    }
}

/// Sheet gövdesi için ortak Form görünümü (Gece mesaisi: düz zemin, kart yok, çizgili satırlar).
extension View {
    func analysisFormStyle() -> some View {
        listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(.fkBackground)
            .scrollDismissesKeyboard(.interactively)
    }

    /// Form bölümü satırları: şeffaf zemin, `separator` renkli çizgi.
    func analysisRows() -> some View {
        modifier(AnalysisRowsModifier())
    }
}

private struct AnalysisRowsModifier: ViewModifier {
    @Environment(\.fokusPalette) private var palette

    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(FokusColor.color(.separator, palette: palette))
    }
}
