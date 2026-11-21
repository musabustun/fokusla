import FokusData
import FokusDesign
import FokusDomain
import SwiftUI

/// Konu ayrıntısı: özet, trend ve konunun tüm testleri (dokununca düzenlenir).
struct TopicDetailView: View {
    let data: AnalysisData
    let subject: Subject
    let topic: Topic

    @Environment(\.analysisActions) private var actions

    var body: some View {
        let results = data.results(forTopic: topic.id)
        let snapshots = results.map(\.snapshot)
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                ScreenHeader(topic.name, eyebrow: subject.name) {
                    Button("Test ekle") { actions.addTest(subject.id, topic.id) }
                        .buttonStyle(.fokusSecondary)
                        .fixedSize()
                        .accessibilityIdentifier("analysis.addTest")
                }
                if results.isEmpty {
                    EmptyStateView(
                        "Bu konuda henüz test yok", systemImage: "square.and.pencil",
                        message:
                            "Çözdüğün testin doğru, yanlış ve boş sayılarını gir; netin ve gelişimin burada görünür."
                    ) {
                        Button("İlk testini ekle") { actions.addTest(subject.id, topic.id) }
                            .buttonStyle(.fokusSecondary)
                            .accessibilityIdentifier("analysis.addFirstTest")
                    }
                } else {
                    SummarySection(
                        title: "KONU ÖZETİ", summary: TestsCalc.summarize(snapshots), showsLastTaken: true)
                    NetTrendSection(results: snapshots)
                    LineSection("Testler") {
                        ResultRows(results: results, booksById: data.booksById)
                    }
                }
                if !topic.isCatalogEntry {
                    Button("Konuyu düzenle") { actions.editTopic(topic) }
                        .buttonStyle(.fokusPlain)
                        .accessibilityIdentifier("analysis.editTopic")
                }
            }
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.vertical, FokusSpacing.lg)
        }
        .background(.fkBackground)
        .accessibilityIdentifier("analysis.topicDetail")
    }
}
