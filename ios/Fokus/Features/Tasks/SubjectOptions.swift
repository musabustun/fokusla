import FokusData
import FokusDomain
import Foundation

/// "Ders" seçicisinin bir sınav grubu (TYT/AYT/YDT).
struct SubjectGroup: Identifiable, Equatable {
    var exam: ExamType
    var subjects: [SubjectOption]
    var id: String { exam.rawValue }
}

struct SubjectOption: Identifiable, Equatable {
    var id: UUID
    var name: String
}

enum SubjectOptions {
    private static let examOrder: [ExamType] = [.tyt, .ayt, .ydt]

    /// Yalnızca profil alanının gördüğü dersler (alan yoksa hepsi), TYT/AYT/YDT sırasıyla ve `order`'a
    /// göre. `keepId` (düzenlenen görevin mevcut dersi) alan dışında kalsa bile listede tutulur.
    static func groups(subjects: [Subject], field: YksField?, keepId: UUID?) -> [SubjectGroup] {
        let visible = subjects.filter { subject in
            subject.deletedAt == nil
                && (field == nil || subject.fields.contains(field!) || subject.id == keepId)
        }
        return examOrder.compactMap { exam in
            let options = visible.filter { $0.exam == exam }
                .sorted {
                    $0.order != $1.order
                        ? $0.order < $1.order
                        : $0.name.compare($1.name, locale: Locale(identifier: "tr_TR")) == .orderedAscending
                }
                .map { SubjectOption(id: $0.id, name: $0.name) }
            return options.isEmpty ? nil : SubjectGroup(exam: exam, subjects: options)
        }
    }
}
