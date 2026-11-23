import FokusDesign
import SwiftUI

/// Tam ekran alt/üst katman ölçüleri.
enum ImmersiveLayout {
    /// Sayfa göstergesi + boşluk için sayfaların altta ayırdığı yükseklik.
    static let indicatorReserve: CGFloat = 40
    /// Sabitlenmiş (uzun mola / VoiceOver) kontrol çubuğu ve uyarı rozeti için ek yükseklik.
    static let pinnedControlsReserve: CGFloat = 130
    static let controlsMaxWidth: CGFloat = 520
}

/// Gece sayfasında katman da koyu şemada çözülsün diye: açık temada siyah üstünde parlak panel olmasın.
struct ImmersiveNightScheme: ViewModifier {
    let isNight: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.environment(\.colorScheme, isNight ? .dark : colorScheme)
    }
}

/// Mola ver / Devam et / Bitir çubuğu. Düğme görünümü `FocusActionButtons` ile aynıdır (kehribar birincil
/// yalnızca "Devam et"); kimlikler `immersive.*`.
struct ImmersiveControlsBar: View {
    let phase: FocusTimerPhase
    let isLongBreak: Bool
    let actions: FocusTimerActions

    var body: some View {
        FocusActionButtons(
            phase: phase, isLongBreak: isLongBreak, isStacked: false, actions: actions,
            idPrefix: "immersive"
        )
        .padding(FokusSpacing.md)
        .frame(maxWidth: ImmersiveLayout.controlsMaxWidth)
        .background(.fkBackground.opacity(0.94), in: RoundedRectangle(cornerRadius: FokusRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: FokusRadius.xl).strokeBorder(.fkSeparator, lineWidth: 1))
    }
}

/// "Küçült": tam ekrandan çıkar, normal Odak ekranına döner (oturum sürer).
struct ImmersiveMinimizeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.headline)
                .foregroundStyle(.fkLabel)
                .frame(width: fokusMinTapTarget, height: fokusMinTapTarget)
                .background(.fkBackground.opacity(0.94), in: Circle())
                .overlay(Circle().strokeBorder(.fkSeparatorStrong, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Küçült")
        .accessibilityHint("Tam ekrandan çıkar, oturum sürer")
        .accessibilityIdentifier("immersive.minimize")
    }
}

/// "Özelleştir": düzenleme modunu açar (VoiceOver yolu; uzun basma bunun dokunma karşılığı).
struct ImmersiveCustomizeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(.fkLabel)
                .frame(width: fokusMinTapTarget, height: fokusMinTapTarget)
                .background(.fkBackground.opacity(0.94), in: Circle())
                .overlay(Circle().strokeBorder(.fkSeparatorStrong, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Özelleştir")
        .accessibilityHint("Sayfaları, yazı stilini, rengi ve zemini değiştirir")
        .accessibilityIdentifier("immersive.customize")
    }
}

/// "Molan uzadı" rozeti: uzun mola uyarısı her sayfada görünür (gece sayfasında soluk ama okunur).
struct ImmersiveLongBreakBadge: View {
    var isDimmed = false

    var body: some View {
        HStack(spacing: FokusSpacing.sm) {
            Image(systemName: "alarm").foregroundStyle(.fkWarning).accessibilityHidden(true)
            Text("Molan uzadı").fokusTextStyle(.headline).foregroundStyle(.fkLabel)
        }
        .padding(.horizontal, FokusSpacing.lg)
        .padding(.vertical, FokusSpacing.sm)
        .background(.fkBackground.opacity(0.94), in: Capsule())
        .overlay(Capsule().strokeBorder(.fkWarning, lineWidth: 1))
        .opacity(isDimmed ? 0.7 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Hazırsan odağa dön ya da oturumu bitir")
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("immersive.longBreak")
    }
}

/// Sayfa göstergesi (noktalar), yalnızca görünür sayfalar için. Sistem göstergesi yerine kendi çizimimiz:
/// konumu kontrol çubuğuyla çakışmaz ve gece sayfasında soluklaşabilir. VoiceOver'da ayarlanabilir öğedir.
struct ImmersivePageIndicator: View {
    let pages: [StandByPage]
    @Binding var page: StandByPage
    let tone: FokusColor
    var isDimmed = false

    private static let dotSize: CGFloat = 7

    var body: some View {
        HStack(spacing: FokusSpacing.sm) {
            ForEach(pages) { item in
                Circle()
                    .fill(item == page ? tone : FokusColor(.separatorStrong))
                    .frame(width: Self.dotSize, height: Self.dotSize)
            }
        }
        .frame(minHeight: FokusSpacing.xl)
        .opacity(isDimmed ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sayfa")
        .accessibilityValue("\(page.title), \(pages.position(of: page) + 1) / \(pages.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: page = pages.advanced(from: page, by: 1)
            case .decrement: page = pages.advanced(from: page, by: -1)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("immersive.pageIndicator")
    }
}
