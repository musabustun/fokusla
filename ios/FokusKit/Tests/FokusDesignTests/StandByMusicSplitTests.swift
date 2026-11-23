import CoreGraphics
import Testing

@testable import FokusDesign

@Suite("StandByMusicSplit")
struct StandByMusicSplitTests {
    struct ArrangementCase: Sendable {
        let name: String
        let width: CGFloat
        let height: CGFloat
        let expected: StandByMusicSplit.Arrangement
    }

    static let arrangementCases: [ArrangementCase] = [
        .init(name: "iPhone dikey", width: 402, height: 874, expected: .stacked),
        .init(name: "iPhone yatay", width: 874, height: 402, expected: .sideBySide),
        .init(name: "iPad dikey", width: 820, height: 1180, expected: .stacked),
        .init(name: "iPad yatay", width: 1180, height: 820, expected: .sideBySide),
        .init(name: "kareye yakın", width: 500, height: 450, expected: .stacked),
        .init(name: "eşik", width: 1.15 * 400, height: 400, expected: .stacked),
        .init(name: "eşik üstü", width: 1.16 * 400, height: 400, expected: .sideBySide),
    ]

    @Test(arguments: arrangementCases)
    func arrangement(_ item: ArrangementCase) {
        #expect(StandByMusicSplit.arrangement(width: item.width, height: item.height) == item.expected)
    }

    @Test func sideColumnWidthIsClamped() {
        // Küçük genişlik: alt sınır, ama toplamın %60'ını aşmaz.
        #expect(StandByMusicSplit.sideColumnWidth(totalWidth: 600) == 280)
        #expect(StandByMusicSplit.sideColumnWidth(totalWidth: 874) == 874 * 0.40)
        // Büyük genişlik: üst sınır.
        #expect(StandByMusicSplit.sideColumnWidth(totalWidth: 2000) == 460)
        // Çok dar: %60 tavanı.
        #expect(StandByMusicSplit.sideColumnWidth(totalWidth: 300) == 180)
    }
}
