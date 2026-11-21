import FokusData
import FokusDesign
import FokusDomain
import SwiftUI

/// Test sonuçları (en yeni üstte); satıra dokununca düzenleme sayfası açılır.
struct ResultRows: View {
    let results: [TestResult]
    let booksById: [UUID: Book]

    @Environment(\.analysisActions) private var actions

    var body: some View {
        ForEach(results.sorted { $0.takenAt > $1.takenAt }) { result in
            Button {
                actions.editResult(result)
            } label: {
                LineRow(
                    AnalysisFormat.resultTitle(
                        bookTitle: result.bookId.flatMap { booksById[$0]?.title },
                        sourceName: result.sourceName, label: result.label),
                    subtitle: AnalysisFormat.resultSubtitle(
                        takenAt: result.takenAt, correct: result.correct, wrong: result.wrong,
                        blank: result.blank),
                    value: AnalysisFormat.formatNetValue(
                        TestsCalc.computeNet(correct: result.correct, wrong: result.wrong)))
            }
            .buttonStyle(.fokusRow)
            .accessibilityIdentifier("analysis.result.\(result.id.uuidString)")
        }
    }
}
