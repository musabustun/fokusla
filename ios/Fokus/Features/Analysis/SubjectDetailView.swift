import FokusData
import FokusDesign
import FokusDomain
import SwiftUI

/// Ders ayrıntısı: özet, trend, tüm konular (hiç çalışılmamışlar dahil), konusuz testler.
struct SubjectDetailView: View {
    let data: AnalysisData
    let subject: Subject

    @Environment(\.analysisActions) private var actions

    var body: some View {
        let results = data.results(forSubject: subject.id)
        let snapshots = results.map(\.snapshot)
        let topics = data.topicsBySubject[subject.id] ?? []
        let untopiced = data.untopicedResults(forSubject: subject.id)
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                ScreenHeader(subject.name, eyebrow: subject.exam.rawValue) {
                    Button("Test ekle") { actions.addTest(subject.id, nil) }
                        .buttonStyle(.fokusSecondary)
                        .fixedSize()
                        .accessibilityIdentifier("analysis.addTest")
                }
                SummarySection(
                    title: "DERS ÖZETİ", summary: TestsCalc.summarize(snapshots), showsLastTaken: true)
                NetTrendSection(results: snapshots)
                LineSection("Konular") {
                    if topics.isEmpty { LineRow("Henüz konu yok") }
                    ForEach(topics) { topic in
                        let summary = data.topicSummaries[topic.id]
                        NavigationLink(
                            value: AnalysisRoute.topic(subjectId: subject.id, topicId: topic.id)
                        ) {
                            LineRow(
                                topic.name, subtitle: AnalysisFormat.topicDetailText(summary),
                                value: AnalysisFormat.topicStatText(summary), showsChevron: true)
                        }
                        .buttonStyle(.fokusRow)
                        .accessibilityIdentifier("analysis.topic.\(topic.id.uuidString)")
                    }
                }
                if !untopiced.isEmpty {
                    LineSection(
                        "Konu seçilmedi",
                        footer: "Bu testler bir konuya bağlanmadığı için konu listesinde sayılmaz."
                    ) {
                        ResultRows(results: untopiced, booksById: data.booksById)
                    }
                }
                HStack(spacing: FokusSpacing.md) {
                    Button("Konu ekle") { actions.addTopic(subject) }
                        .buttonStyle(.fokusSecondary)
                        .accessibilityIdentifier("analysis.addTopic")
                    if !subject.isCatalogEntry {
                        Button("Dersi düzenle") { actions.editSubject(subject) }
                            .buttonStyle(.fokusPlain)
                            .accessibilityIdentifier("analysis.editSubject")
                    }
                }
            }
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.vertical, FokusSpacing.lg)
        }
        .background(.fkBackground)
        .accessibilityIdentifier("analysis.subjectDetail")
    }
}
