import Foundation

/// Opsiyonel ders/konu seçimi (web `SubjectSelection`).
struct FocusSelection: Equatable {
    var subjectId: UUID?
    var topicId: UUID?

    static let none = FocusSelection(subjectId: nil, topicId: nil)
}
