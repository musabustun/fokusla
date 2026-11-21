import FokusData
import FokusDesign
import FokusDomain
import SwiftUI

/// Sınava göre gruplanmış ders listesi (iPhone genel bakışı ve iPad sol bölmesi).
/// `selection` verilirse (iPad) satırlar seçim yapar; verilmezse (iPhone) ayrıntıya gider.
struct SubjectListSection: View {
    let data: AnalysisData
    var selection: Binding<UUID?>?
    var isCompact = false

    private static let exams: [ExamType] = [.tyt, .ayt, .ydt]

    var body: some View {
        let groups = Self.exams
            .map { exam in (exam: exam, subjects: data.subjects.filter { $0.exam == exam }) }
            .filter { !$0.subjects.isEmpty }
        VStack(alignment: .leading, spacing: FokusSpacing.xl) {
            ForEach(groups, id: \.exam) { group in
                LineSection(group.exam.rawValue) {
                    ForEach(group.subjects) { subject in row(subject) }
                }
            }
            if groups.isEmpty {
                Text("Henüz ders yok.")
                    .fokusTextStyle(.subheadline)
                    .foregroundStyle(.fkSecondaryLabel)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analysis.subjects")
    }

    @ViewBuilder
    private func row(_ subject: Subject) -> some View {
        let stat = AnalysisFormat.subjectStatText(data.subjectSummaries[subject.id])
        if let selection {
            Button {
                selection.wrappedValue = subject.id
            } label: {
                LineRow(subject.name, subtitle: stat)
                    .background {
                        if selection.wrappedValue == subject.id { Rectangle().fill(.fkFill) }
                    }
            }
            .buttonStyle(.fokusRow)
            .accessibilityAddTraits(selection.wrappedValue == subject.id ? .isSelected : [])
            .accessibilityIdentifier("analysis.subject.\(subject.id.uuidString)")
        } else {
            NavigationLink(value: AnalysisRoute.subject(subject.id)) {
                LineRow(subject.name, value: stat, showsChevron: true)
            }
            .buttonStyle(.fokusRow)
            .accessibilityIdentifier("analysis.subject.\(subject.id.uuidString)")
        }
    }
}
