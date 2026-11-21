import FokusData
import FokusDesign
import SwiftUI

/// Opsiyonel ders ve konu seçimi; konu yalnızca ders seçildikten sonra etkinleşir (web `SubjectPicker`).
struct FocusSubjectPicker: View {
    let subjects: [Subject]
    let topics: [Topic]
    @Binding var selection: FocusSelection

    var body: some View {
        VStack(spacing: FokusSpacing.md) {
            field(
                title: "Ders (isteğe bağlı)",
                value: subjects.first { $0.id == selection.subjectId }?.name ?? "Ders seçilmedi",
                isEmpty: selection.subjectId == nil,
                id: "focus.subjectPicker"
            ) {
                Picker("Ders", selection: subjectBinding) {
                    Text("Ders seçilmedi").tag(UUID?.none)
                    ForEach(FocusSubjects.groupedByExam(subjects), id: \.exam) { group in
                        Section(group.exam.rawValue) {
                            ForEach(group.subjects) { subject in
                                Text(subject.name).tag(UUID?.some(subject.id))
                            }
                        }
                    }
                }
            }
            field(
                title: "Konu (isteğe bağlı)",
                value: topics.first { $0.id == selection.topicId }?.name ?? "Konu seçilmedi",
                isEmpty: selection.topicId == nil,
                id: "focus.topicPicker"
            ) {
                Picker("Konu", selection: topicBinding) {
                    Text("Konu seçilmedi").tag(UUID?.none)
                    ForEach(topics) { topic in
                        Text(topic.name).tag(UUID?.some(topic.id))
                    }
                }
            }
            .disabled(selection.subjectId == nil)
        }
    }

    private var subjectBinding: Binding<UUID?> {
        Binding(
            get: { selection.subjectId },
            set: { selection = FocusSelection(subjectId: $0, topicId: nil) }
        )
    }

    private var topicBinding: Binding<UUID?> {
        Binding(
            get: { selection.topicId },
            set: { selection = FocusSelection(subjectId: selection.subjectId, topicId: $0) }
        )
    }

    private func field(
        title: String, value: String, isEmpty: Bool, id: String,
        @ViewBuilder options: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: FokusSpacing.sm) {
            Text(title).fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
            Menu {
                options()
            } label: {
                HStack(spacing: FokusSpacing.md) {
                    Text(value)
                        .fokusTextStyle(.body)
                        .foregroundStyle(isEmpty ? FokusColor(.secondaryLabel) : FokusColor(.label))
                        .lineLimit(1)
                    Spacer(minLength: FokusSpacing.sm)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.fkTertiaryLabel)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, FokusSpacing.lg)
                .frame(minHeight: fokusMinTapTarget + 4)
                .overlay(
                    RoundedRectangle(cornerRadius: FokusRadius.md).strokeBorder(.fkSeparatorStrong, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .accessibilityLabel(title)
            .accessibilityValue(value)
            .accessibilityIdentifier(id)
        }
    }
}
