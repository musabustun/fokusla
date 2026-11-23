import FokusAudio
import FokusDesign
import FokusDomain
import SwiftUI

// MARK: - Bugünün özeti

/// StandBy widget ızgarası: 2×2 hücre, hairline ile ayrılmış (toplam, oturum, ortalama odak, ortalama mola).
struct ImmersiveSummaryPage: View {
    let context: ImmersivePageContext

    var body: some View {
        let snap = context.snapshot
        VStack(alignment: .leading, spacing: FokusSpacing.lg) {
            Text("Bugünün özeti")
                .fokusTextStyle(.eyebrow)
                .foregroundStyle(.fkSecondaryLabel)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    cell(
                        "Bugün toplam odak", id: "immersive.summary.today",
                        spoken: FocusFormat.durationText(snap.todayTotalMs)
                    ) { FocusDurationValue(ms: snap.todayTotalMs, style: .numeralXL) }
                    Rectangle().fill(.fkSeparator).frame(width: 1)
                    cell("Bugünkü oturum", id: "immersive.summary.count", spoken: "\(snap.todaySessionCount)") {
                        Text(snap.todaySessionCount.formatted(.number.locale(Locale(identifier: "tr_TR"))))
                            .fokusTextStyle(.numeralXL).foregroundStyle(.fkLabel)
                    }
                }
                Rectangle().fill(.fkSeparator).frame(height: 1)
                HStack(spacing: 0) {
                    cell(
                        "Ortalama kesintisiz odak", id: "immersive.summary.averageFocus",
                        spoken: FocusFormat.durationText(snap.averageFocusMs)
                    ) { FocusDurationValue(ms: snap.averageFocusMs, style: .numeralXL) }
                    Rectangle().fill(.fkSeparator).frame(width: 1)
                    cell(
                        "Ortalama mola", id: "immersive.summary.averageBreak",
                        spoken: FocusFormat.durationText(snap.averageBreakMs)
                    ) { FocusDurationValue(ms: snap.averageBreakMs, style: .numeralXL) }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(context.contentPadding)
        .immersivePageContainer(.summary)
    }

    private func cell<Value: View>(
        _ title: String, id: String, spoken: String, @ViewBuilder value: () -> Value
    ) -> some View {
        VStack(alignment: .leading, spacing: FokusSpacing.xs) {
            Text(title).fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel).lineLimit(2)
            value()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(FokusSpacing.lg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(spoken)
        .accessibilityIdentifier(id)
    }
}

// MARK: - Ses ve müzik

/// Dikey kaydırılabilir sayfa: üstte odak sesleri, altında müzik. Ortam yoksa (önizleme) bölüm çizilmez.
/// İçeriği kardeş görünümler çizer (`FocusSoundSection`, `FocusMusicSection`); burada yalnızca yerleşir.
struct ImmersiveSoundPage: View {
    let context: ImmersivePageContext

    @Environment(\.focusSound) private var focusSound
    @Environment(\.musicRegistry) private var musicRegistry

    /// Kontrol çubuğunun (sabitlenmemişken de) üstüne binen alt boşluk.
    private static let controlsClearance: CGFloat = 120
    private static let maxContentWidth: CGFloat = 560

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xxl) {
                if let focusSound { FocusSoundSection(sound: focusSound) }
                if let musicRegistry { FocusMusicSection(registry: musicRegistry) }
                if focusSound == nil && musicRegistry == nil {
                    Text("Ses ve müzik bu cihazda kullanılamıyor.")
                        .fokusTextStyle(.subheadline)
                        .foregroundStyle(.fkSecondaryLabel)
                }
            }
            .frame(maxWidth: Self.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.top, fokusMinTapTarget + FokusSpacing.md)
            .padding(.bottom, Self.controlsClearance)
            .padding(context.contentPadding)
        }
        .scrollIndicators(.hidden)
        .immersivePageContainer(.sound)
    }
}
