import SwiftUI

/// "Sayfalar" sekmesi: tüm sayfalar (açıklar önce, sürüklenebilir), açma/kapama düğmeleri ve
/// köşe çipi anahtarı.
struct StandByEditorPagesTab: View {
    @Binding var preferences: StandByPreferences
    let isMusicAvailable: Bool

    var body: some View {
        let order = StandByEditorPanel.rowOrder(for: preferences)
        List {
            ForEach(order) { page in
                row(page)
                    .moveDisabled(!preferences.isEnabled(page))
                    .listRowBackground(Color.clear)
                    #if !os(watchOS)
                    .listRowSeparatorTint(Color.clear)
                    #endif
            }
            .onMove { source, destination in
                preferences = StandByEditorPanel.movingEnabled(
                    preferences, fromOffsets: source, toOffset: destination)
            }
            if isMusicAvailable { chipToggle }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        #if os(iOS)
        .environment(\.editMode, .constant(.active))
        #endif
    }

    private func row(_ page: StandByPage) -> some View {
        let isEnabled = preferences.isEnabled(page)
        return HStack(spacing: FokusSpacing.md) {
            Image(systemName: page.symbolName)
                .foregroundStyle(isEnabled ? .fkAccentInk : .fkTertiaryLabel)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(page.title).font(.body).foregroundStyle(isEnabled ? .fkLabel : .fkSecondaryLabel)
                if page.requiresMusic {
                    Text("Spotify bağlıyken görünür").font(.caption).foregroundStyle(.fkSecondaryLabel)
                }
            }
            Spacer(minLength: FokusSpacing.sm)
            toggleButton(page, isEnabled: isEnabled)
        }
        .frame(minHeight: fokusMinTapTarget)
        .accessibilityAction(named: "Yukarı taşı") { preferences = preferences.moving(page, by: -1) }
        .accessibilityAction(named: "Aşağı taşı") { preferences = preferences.moving(page, by: 1) }
    }

    private func toggleButton(_ page: StandByPage, isEnabled: Bool) -> some View {
        let isLocked = isEnabled && !preferences.canDisable(page)
        return Button {
            preferences = preferences.toggling(page)
        } label: {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isEnabled ? .fkAccent : .fkTertiaryLabel)
                .frame(width: fokusMinTapTarget, height: fokusMinTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityLabel(page.title)
        .accessibilityValue(isEnabled ? "Açık" : "Kapalı")
        .accessibilityIdentifier("immersive.editor.page.\(page.rawValue)")
    }

    private var chipToggle: some View {
        Toggle(
            "Köşede şimdi çalıyor",
            isOn: Binding(
                get: { preferences.showsNowPlayingChip },
                set: { preferences = preferences.with(\.showsNowPlayingChip, $0) })
        )
        .tint(FokusColor(.accent))
        .frame(minHeight: fokusMinTapTarget)
        .listRowBackground(Color.clear)
        .accessibilityIdentifier("immersive.editor.nowPlayingChip")
    }
}
