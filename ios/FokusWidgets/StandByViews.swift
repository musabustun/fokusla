import FokusDesign
import FokusDomain
import SwiftUI
import WidgetKit

// StandBy (şarjda, yatay, kilitli iPhone) görünümleri. Sistem systemSmall widget'ı ekran boyuna büyütür ve
// konteyner arka planını kaldırır (`showsWidgetContainerBackground == false`). Gece modunda sistem içeriği tek
// (kırmızı) tona çevirir: renk anlam taşımaz; hiyerarşi parlaklık (opaklık) ve metinle kurulur.

/// Render moduna göre renk seçimi: tam renkte tokenlar, tek tonda (`.accented`/`.vibrant`) `primary`/`secondary`.
struct StandByTone {
    let mode: WidgetRenderingMode

    private var isFullColor: Bool { mode == .fullColor }

    var primary: AnyShapeStyle { isFullColor ? AnyShapeStyle(.fkLabel) : AnyShapeStyle(.primary) }
    var secondary: AnyShapeStyle { isFullColor ? AnyShapeStyle(.fkSecondaryLabel) : AnyShapeStyle(.secondary) }
    var track: AnyShapeStyle {
        isFullColor ? AnyShapeStyle(.fkSeparatorStrong) : AnyShapeStyle(.primary.opacity(0.28))
    }
    var accent: AnyShapeStyle { isFullColor ? AnyShapeStyle(.fkAccentInk) : AnyShapeStyle(.primary) }
    var success: AnyShapeStyle { isFullColor ? AnyShapeStyle(.fkSuccess) : AnyShapeStyle(.primary) }
}

/// Odak/hedef widget'ının StandBy düzeni: halka + ortada büyük mono sayaç + ders adı / hedef satırı.
struct StandByFocusView: View {
    let display: WidgetCalc.StandByDisplay
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var tone: StandByTone { StandByTone(mode: renderingMode) }
    private let lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            ring
            VStack(spacing: 3) {
                Text(display.statusText)
                    .fokusTextStyle(.eyebrow).foregroundStyle(tone.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                StandByTotalText(display: display, tone: tone)
                detail
            }
            .padding(.horizontal, lineWidth + 16)
        }
        .padding(2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(display.accessibilityText)
    }

    private var ring: some View {
        ZStack {
            Circle().inset(by: lineWidth / 2).stroke(tone.track, lineWidth: lineWidth)
            Circle().inset(by: lineWidth / 2).trim(from: 0, to: display.ratio)
                .stroke(
                    display.isGoalReached ? tone.success : tone.accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
        }
    }

    @ViewBuilder private var detail: some View {
        if let title = display.titleText {
            Text(title).fokusTextStyle(.subheadline).foregroundStyle(tone.primary)
                .lineLimit(1).minimumScaleFactor(0.7)
        } else if let goal = display.goalText {
            HStack(spacing: 3) {
                if display.isGoalReached { Image(systemName: "checkmark") }
                Text(goal)
            }
            .fokusTextStyle(.caption).foregroundStyle(display.isGoalReached ? tone.success : tone.secondary)
            .lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

/// Büyük süre: akarken sistemin saydığı sayaç, durağanken "2 sa 15 dk" (rakam büyük, birim küçük).
struct StandByTotalText: View {
    let display: WidgetCalc.StandByDisplay
    let tone: StandByTone

    var body: some View {
        Group {
            if let start = display.timerStart {
                Text(timerInterval: start...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
                    .fokusTextStyle(.numeralLG)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    ForEach(Array(FocusFormat.durationParts(display.focusMs).enumerated()), id: \.offset) { _, part in
                        Text("\(part.value)").fokusTextStyle(.numeralLG)
                        Text(part.unit).fokusTextStyle(.footnote).foregroundStyle(tone.secondary)
                            .padding(.trailing, 2)
                    }
                }
            }
        }
        .foregroundStyle(tone.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.4)
    }
}

/// "Odak saati": büyük saat + tarih + bugünkü toplam. Entry tarihi dakika başlarındadır (`clockTimelinePlan`).
struct FocusClockView: View {
    let date: Date
    let display: WidgetCalc.StandByDisplay
    var calendar: Calendar = .current
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var tone: StandByTone { StandByTone(mode: renderingMode) }

    private var timeText: String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WidgetCalc.standByDateLine(date, calendar: calendar))
                .fokusTextStyle(.eyebrow).foregroundStyle(tone.secondary)
                .lineLimit(1).minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            Text(timeText)
                .font(.custom(FokusFonts.monoRegular, size: 56))
                .tracking(-2.5)
                .foregroundStyle(tone.primary)
                .lineLimit(1).minimumScaleFactor(0.4)
                .widgetAccentable()
            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(timeText), \(display.accessibilityText)")
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Rectangle().fill(display.isRunning ? tone.accent : tone.track).frame(width: 3, height: 14)
                .widgetAccentable(display.isRunning)
            if let start = display.timerStart {
                Text(timerInterval: start...Date.distantFuture, countsDown: false).monospacedDigit()
            } else {
                Text(FocusFormat.durationText(display.focusMs))
            }
        }
        .fokusTextStyle(.numeralSM).foregroundStyle(tone.primary)
        .lineLimit(1).minimumScaleFactor(0.6)
    }
}
