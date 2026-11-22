import FokusDesign
import FokusDomain
import SwiftUI

/// Kendi durumum — odak verisinden yalnızca okunur; kronometre Odak ekranındadır.
struct SocialOwnStatusSection: View {
    let presence: SocialPresence
    let now: Date
    let isDiscoverable: Bool

    @Environment(AppNavigation.self) private var navigation: AppNavigation?

    var body: some View {
        let state = presence.state
        let line = SocialFormat.formatPresenceLine(state, SocialCalc.liveStateMs(presence, now: now))
        let todayMs = SocialCalc.liveTodayFocusMs(presence, now: now)
        let isFocusing = SocialCalc.effectivePresenceState(presence, now: now) == .focusing
        VStack(alignment: .leading, spacing: FokusSpacing.md) {
            Text("Senin durumun").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                .accessibilityAddTraits(.isHeader)
            if isFocusing {
                Metric(
                    label: "Oturum", value: SocialFormat.formatClock(SocialCalc.liveSessionMs(presence, now: now)),
                    caption: "Bugün \(SocialFormat.formatDurationShort(todayMs))", size: .xl, tone: .success)
            } else {
                Metric(label: "Bugün", value: SocialFormat.formatDurationShort(todayMs), size: .lg, isNumeric: false)
            }
            VStack(spacing: 0) {
                Divider().overlay(.fkSeparator)
                Button { navigation?.open(.focus) } label: {
                    VStack(spacing: 0) {
                        HStack(spacing: FokusSpacing.md) {
                            PresenceDot(state: SocialCalc.effectivePresenceState(presence, now: now))
                            Text(line).fokusTextStyle(.body).foregroundStyle(.fkLabel)
                            Spacer(minLength: FokusSpacing.sm)
                            Text("Odak'a git").font(.body).foregroundStyle(.fkSecondaryLabel).lineLimit(1).fixedSize()
                            LineChevron()
                        }
                        .frame(minHeight: fokusMinTapTarget)
                        .padding(.vertical, FokusSpacing.md)
                        Divider().overlay(.fkSeparator)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.fokusRow)
                .accessibilityLabel("\(line). Odak ekranına git")
                .accessibilityIdentifier("social.own.goFocus")
            }
            Text(isDiscoverable
                ? "Kronometreni Odak ekranından başlat; durumun arkadaşlarına otomatik yansır."
                : "Gizli olduğun için durumun kimseyle paylaşılmıyor.")
                .fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
        }
        .socialContainer("social.own")
    }
}
