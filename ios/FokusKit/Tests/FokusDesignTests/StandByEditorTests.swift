import Foundation
import SwiftUI
import Testing

@testable import FokusDesign

@Suite("StandByEditorPanel yardımcıları")
struct StandByEditorTests {
    private func prefs(_ pages: [StandByPage]) -> StandByPreferences {
        StandByPreferences.default.with(\.pages, pages)
    }

    @Test("rowOrder: açık sayfalar kendi sırasıyla, sonra kapalılar")
    func rowOrderEnabledThenDisabled() {
        let order = StandByEditorPanel.rowOrder(for: prefs([.night, .stopwatch]))
        #expect(Array(order.prefix(2)) == [.night, .stopwatch])
        #expect(order.count == StandByPage.allCases.count)
        #expect(Set(order) == Set(StandByPage.allCases))
    }

    @Test("rowOrder: varsayılan tercihte subject sona düşer")
    func rowOrderDefault() {
        let order = StandByEditorPanel.rowOrder(for: .default)
        #expect(Array(order.prefix(StandByPreferences.defaultPages.count)) == StandByPreferences.defaultPages)
        #expect(order.last == .subject)
    }

    @Test("movingEnabled: açık satırlar arasında taşır")
    func movesAmongEnabled() {
        let result = StandByEditorPanel.movingEnabled(
            prefs([.stopwatch, .clock, .ring]), fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(result.pages == [.clock, .ring, .stopwatch])
    }

    @Test("movingEnabled: hedef kapalı satırlara taşarsa açık sayısına sıkıştırılır")
    func clampsDestination() {
        let result = StandByEditorPanel.movingEnabled(
            prefs([.stopwatch, .clock]), fromOffsets: IndexSet(integer: 0), toOffset: 7)
        #expect(result.pages == [.clock, .stopwatch])
    }

    @Test("movingEnabled: kapalı satır taşınamaz")
    func ignoresDisabledSource() {
        let start = prefs([.stopwatch, .clock])
        let result = StandByEditorPanel.movingEnabled(start, fromOffsets: IndexSet(integer: 5), toOffset: 0)
        #expect(result == start)
    }

    @Test("NowPlayingCard.isWide eşiği 1.15")
    func wideThreshold() {
        #expect(NowPlayingCard.isWide(width: 1200, height: 800))
        #expect(!NowPlayingCard.isWide(width: 390, height: 800))
        #expect(!NowPlayingCard.isWide(width: 114, height: 100))
    }
}
