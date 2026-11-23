import SwiftUI
import Testing

@testable import FokusDesign

@Suite("StandByDigits")
struct StandByDigitsTests {
    private struct FitCase: Sendable {
        let name: String
        let style: StandByClockStyle
    }

    private static let cases: [FitCase] = StandByClockStyle.allCases.map { FitCase(name: $0.rawValue, style: $0) }

    @Test(arguments: cases)
    private func largerBoxGivesLargerSize(_ testCase: FitCase) {
        let small = StandByDigits.fontSize(text: "12:34", style: testCase.style, in: CGSize(width: 200, height: 100))
        let large = StandByDigits.fontSize(text: "12:34", style: testCase.style, in: CGSize(width: 400, height: 200))
        #expect(large > small)
    }

    @Test(arguments: cases)
    private func widthLimitedIgnoresHeight(_ testCase: FitCase) {
        let short = StandByDigits.fontSize(text: "12:34", style: testCase.style, in: CGSize(width: 200, height: 400))
        let tall = StandByDigits.fontSize(text: "12:34", style: testCase.style, in: CGSize(width: 200, height: 600))
        #expect(short == tall)
    }

    @Test(arguments: cases)
    private func heightLimitedIgnoresWidth(_ testCase: FitCase) {
        let narrow = StandByDigits.fontSize(text: "12:34", style: testCase.style, in: CGSize(width: 1_000, height: 100))
        let wide = StandByDigits.fontSize(text: "12:34", style: testCase.style, in: CGSize(width: 2_000, height: 100))
        #expect(narrow == wide)
    }

    @Test(arguments: cases)
    private func longerTextGivesSmallerSize(_ testCase: FitCase) {
        let box = CGSize(width: 300, height: 400)
        let short = StandByDigits.fontSize(text: "12:34", style: testCase.style, in: box)
        let long = StandByDigits.fontSize(text: "1:12:34", style: testCase.style, in: box)
        #expect(long < short)
    }

    @Test(arguments: cases)
    private func sizeIsFiniteAndClamped(_ testCase: FitCase) {
        let sizes = [CGSize.zero, CGSize(width: 1, height: 1), CGSize(width: 390, height: 200),
            CGSize(width: 100_000, height: 100_000)]
        for box in sizes {
            let value = StandByDigits.fontSize(text: "00:00", style: testCase.style, in: box)
            #expect(value.isFinite)
            #expect(StandByDigits.sizeRange.contains(value))
        }
        #expect(StandByDigits.fontSize(text: "", style: testCase.style, in: CGSize(width: 300, height: 100)) > 0)
    }

    @Test(arguments: cases)
    private func digitsShareOneCellWidth(_ testCase: FitCase) {
        let widths = StandByDigits.cellWidths(text: "01:29", style: testCase.style)
        #expect(widths.count == 5)
        #expect(Set([widths[0], widths[1], widths[3], widths[4]]).count == 1)
        #expect(widths[2] < widths[0])
    }
}
