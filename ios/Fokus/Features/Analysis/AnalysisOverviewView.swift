import FokusData
import FokusDesign
import FokusDomain
import SwiftUI

/// Genel bakış: özet, net trendi, en zayıf konular; iPhone'da ayrıca ders listesi.
struct AnalysisOverviewView: View {
    let data: AnalysisData
    /// iPhone'da ders listesi burada; iPad'de sol bölmede.
    let showsSubjectList: Bool

    @Environment(\.analysisActions) private var actions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                ScreenHeader("Analiz", eyebrow: "Testler", subtitle: "Deneme ve test sonuçların") {
                    Button("Test ekle") { actions.addTest(nil, nil) }
                        .buttonStyle(.fokusSecondary)
                        .fixedSize()
                        .accessibilityIdentifier("analysis.addTest")
                }
                if data.results.isEmpty {
                    EmptyStateView(
                        "Henüz test kaydın yok", systemImage: "chart.bar",
                        message:
                            "Çözdüğün testleri ders ve konu bazında kaydet: doğru, yanlış ve boş sayılarını gir; netin (D − Y/4) otomatik hesaplanır."
                    ) {
                        Button("İlk testini ekle") { actions.addTest(nil, nil) }
                            .buttonStyle(.fokusSecondary)
                            .accessibilityIdentifier("analysis.addFirstTest")
                    }
                } else {
                    SummarySection(
                        title: "GENEL DURUM", summary: TestsCalc.summarize(data.results.map(\.snapshot)))
                    NetTrendSection(results: data.results.map(\.snapshot))
                    WeakestTopicsSection(data: data)
                }
                if showsSubjectList {
                    SubjectListSection(data: data)
                    Button("Ders ekle") { actions.addSubject() }
                        .buttonStyle(.fokusSecondary)
                        .accessibilityIdentifier("analysis.addSubject")
                }
            }
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.vertical, FokusSpacing.lg)
        }
        .background(.fkBackground)
    }
}

/// "En zayıf konular" (web `WeakestTopics`): yeterli veri (≥ 20 soru) olan konular, başarıya göre.
private struct WeakestTopicsSection: View {
    let data: AnalysisData

    var body: some View {
        let weakest = TestsCalc.findWeakestTopics(data.topicSummaries)
        LineSection(
            "En zayıf konular",
            footer:
                "En az \(AnalysisFormat.formatCount(TestsCalc.minQuestionsForWeakness)) soru çözülen konular gösterilir."
        ) {
            if weakest.isEmpty { LineRow("Yeterli veri yok") }
            ForEach(weakest, id: \.topicId) { weak in
                if let topic = data.topicsById[weak.topicId], let subjectId = topic.subjectId {
                    NavigationLink(value: AnalysisRoute.topic(subjectId: subjectId, topicId: topic.id)) {
                        LineRow(
                            topic.name,
                            subtitle:
                                "\(data.subjectsById[subjectId]?.name ?? "") · \(AnalysisFormat.formatQuestionCount(weak.summary.totalQuestions))",
                            value: AnalysisFormat.topicStatText(weak.summary), showsChevron: true)
                    }
                    .buttonStyle(.fokusRow)
                    .accessibilityIdentifier("analysis.weak.\(topic.id.uuidString)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analysis.weakest")
    }
}
