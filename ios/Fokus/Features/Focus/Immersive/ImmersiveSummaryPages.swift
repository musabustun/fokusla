import FokusAudio
import FokusDesign
import FokusDomain
import SwiftUI

// MARK: - (d) Bugünün özeti

/// Bugünkü toplam odak, oturum sayısı, ortalama kesintisiz odak ve ortalama mola.
struct ImmersiveSummaryPage: View {
    let context: ImmersivePageContext

    var body: some View {
        let snap = context.snapshot
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height * 1.15
            ScrollView {
                Group {
                    if isWide {
                        HStack(alignment: .center, spacing: FokusSpacing.xxl) {
                            hero(snap).frame(maxWidth: .infinity, alignment: .leading)
                            stats(snap).frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                            hero(snap)
                            stats(snap)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
        .padding(context.contentPadding)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ImmersivePage.summary.accessibilityIdentifier)
    }

    private func hero(_ snap: ImmersiveSnapshot) -> some View {
        VStack(alignment: .leading, spacing: FokusSpacing.sm) {
            Text("Bugünün özeti")
                .fokusTextStyle(.eyebrow)
                .foregroundStyle(.fkSecondaryLabel)
                .accessibilityAddTraits(.isHeader)
            Text("Bugün toplam odak").fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
            FocusDurationValue(ms: snap.todayTotalMs, style: .numeralHero)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bugün toplam odak")
        .accessibilityValue(FocusFormat.durationText(snap.todayTotalMs))
        .accessibilityIdentifier("immersive.summary.today")
    }

    private func stats(_ snap: ImmersiveSnapshot) -> some View {
        VStack(spacing: 0) {
            Divider().overlay(.fkSeparator)
            stat("Bugünkü oturum", id: "immersive.summary.count", spoken: "\(snap.todaySessionCount)") {
                Text(snap.todaySessionCount.formatted(.number.locale(Locale(identifier: "tr_TR"))))
                    .fokusTextStyle(.numeralLG).foregroundStyle(.fkLabel)
            }
            Divider().overlay(.fkSeparator)
            stat(
                "Ortalama kesintisiz odak", id: "immersive.summary.averageFocus",
                spoken: FocusFormat.durationText(snap.averageFocusMs)
            ) { FocusDurationValue(ms: snap.averageFocusMs, style: .numeralLG) }
            Divider().overlay(.fkSeparator)
            stat(
                "Ortalama mola", id: "immersive.summary.averageBreak",
                spoken: FocusFormat.durationText(snap.averageBreakMs)
            ) { FocusDurationValue(ms: snap.averageBreakMs, style: .numeralLG) }
            Divider().overlay(.fkSeparator)
        }
    }

    private func stat<Value: View>(
        _ title: String, id: String, spoken: String, @ViewBuilder value: () -> Value
    ) -> some View {
        VStack(alignment: .leading, spacing: FokusSpacing.xs) {
            Text(title).fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
            value()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, FokusSpacing.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(spoken)
        .accessibilityIdentifier(id)
    }
}

// MARK: - (e) Ses ve müzik

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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ImmersivePage.sound.accessibilityIdentifier)
    }
}
