import SwiftUI

/// Düzenleme modunun alt tepsisi (kilit ekranı benzeri): Sayfalar | Yazı | Renk | Zemin sekmeleri,
/// "Varsayılana dön" ve tek ana eylem "Bitti". Canlı sayfa önizlemesini uygulama tepsinin üstüne koyar.
/// Her değişiklik bağlamaya YENİ bir değer yazar (`StandByPreferences` kopya yöntemleri).
public struct StandByEditorPanel: View {
    @Binding private var preferences: StandByPreferences
    private let appPalette: FokusPalette
    private let isMusicAvailable: Bool
    private let onDone: () -> Void
    private let onReset: () -> Void

    @State private var tab: StandByEditorTab = .pages

    /// Tepsinin iPad'deki en büyük genişliği.
    static let maxWidth: CGFloat = 620

    public init(
        preferences: Binding<StandByPreferences>, appPalette: FokusPalette, isMusicAvailable: Bool,
        onDone: @escaping () -> Void, onReset: @escaping () -> Void
    ) {
        _preferences = preferences
        self.appPalette = appPalette
        self.isMusicAvailable = isMusicAvailable
        self.onDone = onDone
        self.onReset = onReset
    }

    public var body: some View {
        VStack(spacing: FokusSpacing.md) {
            StandByEditorTabBar(selection: $tab)
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            footer
        }
        .padding(.horizontal, FokusSpacing.screenHorizontal)
        .padding(.top, FokusSpacing.lg)
        .padding(.bottom, FokusSpacing.md)
        .frame(maxWidth: Self.maxWidth)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: FokusRadius.xl, topTrailingRadius: FokusRadius.xl)
                .fill(.fkBackground.opacity(0.92))
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: FokusRadius.xl, topTrailingRadius: FokusRadius.xl)
                        .strokeBorder(.fkSeparator, lineWidth: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("immersive.editor")
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .pages:
            StandByEditorPagesTab(preferences: $preferences, isMusicAvailable: isMusicAvailable)
        case .clock:
            StandByEditorClockTab(preferences: $preferences)
        case .color:
            StandByEditorColorTab(preferences: $preferences, appPalette: appPalette)
        case .backdrop:
            StandByEditorBackdropTab(preferences: $preferences)
        }
    }

    private var footer: some View {
        HStack(spacing: FokusSpacing.md) {
            Button("Varsayılana dön", action: onReset)
                .buttonStyle(FokusPlainButtonStyle())
                .accessibilityIdentifier("immersive.editor.reset")
            Spacer(minLength: 0)
            Button("Bitti", action: onDone)
                .buttonStyle(FokusPrimaryButtonStyle())
                .fixedSize()
                .accessibilityIdentifier("immersive.editor.done")
        }
    }

    // MARK: Saf yardımcılar

    /// Sayfalar listesi sırası: önce açık sayfalar (`preferences.pages` sırasıyla), sonra kapalılar (`allCases` sırasıyla).
    nonisolated public static func rowOrder(for preferences: StandByPreferences) -> [StandByPage] {
        preferences.pages + StandByPage.allCases.filter { !preferences.isEnabled($0) }
    }

    /// Listeden sürükle-bırak: yalnızca açık satırlar taşınır; hedef açık satır sayısına sıkıştırılır
    /// (kapalı satırların arasına bırakılamaz). Açık satırlar listenin başında olduğundan indeksler `pages` ile örtüşür.
    nonisolated public static func movingEnabled(
        _ preferences: StandByPreferences, fromOffsets source: IndexSet, toOffset destination: Int
    ) -> StandByPreferences {
        let enabledCount = preferences.pages.count
        let validSource = IndexSet(source.filter { $0 < enabledCount })
        guard !validSource.isEmpty else { return preferences }
        return preferences.moving(fromOffsets: validSource, toOffset: min(max(destination, 0), enabledCount))
    }
}

/// Düzenleyici sekmeleri. Raw değer erişilebilirlik kimliğidir (`immersive.editor.tab.<raw>`).
enum StandByEditorTab: String, CaseIterable, Identifiable {
    case pages, clock, color, backdrop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pages: "Sayfalar"
        case .clock: "Yazı"
        case .color: "Renk"
        case .backdrop: "Zemin"
        }
    }
}

private struct StandByEditorTabBar: View {
    @Binding var selection: StandByEditorTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: FokusSpacing.xs) {
            ForEach(StandByEditorTab.allCases) { tab in
                let isSelected = tab == selection
                Button {
                    if reduceMotion { selection = tab } else { withAnimation(FokusMotion.baseAnimation) { selection = tab } }
                } label: {
                    Text(tab.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .fkAccentContrast : .fkLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: fokusMinTapTarget)
                        .background(Capsule().fill(isSelected ? .fkAccent : .fkFill))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("immersive.editor.tab.\(tab.rawValue)")
            }
        }
    }
}

#Preview("StandByEditorPanel") {
    @Previewable @State var preferences = StandByPreferences.default
    VStack {
        Spacer()
        StandByEditorPanel(
            preferences: $preferences, appPalette: .default, isMusicAvailable: true, onDone: {}, onReset: {})
            .frame(height: 380)
    }
    .background(.fkBackground)
    .fokusTheme()
    .preferredColorScheme(.dark)
}
