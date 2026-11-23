import SwiftUI

/// Ders seçimi (opsiyonel): "Seçilmedi" serbest çalışmadır. Seçim saatte hatırlanır.
struct SubjectPickerView: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            row(title: "Seçilmedi", id: nil)
            ForEach(model.subjects) { subject in
                row(title: subject.name, id: subject.id)
            }
        }
        .navigationTitle("Ders")
        .containerBackground(.fkBackground, for: .navigation)
    }

    private func row(title: String, id: UUID?) -> some View {
        Button {
            model.selectedSubjectId = id
            dismiss()
        } label: {
            HStack {
                Text(title).lineLimit(2)
                Spacer(minLength: 0)
                if model.selectedSubjectId == id {
                    Image(systemName: "checkmark").foregroundStyle(.fkAccentInk).accessibilityLabel("Seçili")
                }
            }
        }
    }
}
