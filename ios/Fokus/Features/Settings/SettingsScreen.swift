import FokusData
import FokusDesign
import FokusDomain
import SwiftData
import SwiftUI

/// Ayarlar modülü — şimdilik salt okunur özet + görünüm seçimi.
struct SettingsScreen: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.syncService) private var syncService
    @AppStorage(FokusThemeKeys.appearance) private var appearanceRaw = FokusAppearance.default.rawValue
    @AppStorage(FokusThemeKeys.palette) private var paletteRaw = FokusPalette.default.rawValue

    @Query(
        filter: #Predicate<UserProfile> { $0.deletedAt == nil },
        sort: \UserProfile.createdAt
    ) private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                ScreenHeader("Ayarlar", eyebrow: "Fokus")
                appearanceSection
                paletteSection
                accountSection
                if horizontalSizeClass == .compact { moreSection }
            }
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.vertical, FokusSpacing.lg)
        }
        .background(.fkBackground)
        .accessibilityIdentifier("screen.settings")
    }

    private var appearanceSection: some View {
        LineSection("Görünüm") {
            LineRow("Görünüm") {
                Picker("Görünüm", selection: $appearanceRaw) {
                    ForEach(FokusAppearance.allCases) { appearance in
                        Text(appearance.displayName).tag(appearance.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings.appearance")
            }
        }
    }

    private var paletteSection: some View {
        LineSection("Renk teması") {
            PalettePicker(
                selection: Binding(
                    get: { FokusPalette(rawValue: paletteRaw) ?? .default },
                    set: { paletteRaw = $0.rawValue }
                )
            )
            .padding(.vertical, FokusSpacing.md)
        }
    }

    private var accountSection: some View {
        LineSection("Hesap ve eşitleme") {
            LineRow("YKS alanı", value: profile?.field.label ?? "—")
            LineRow("Apple ile Giriş", value: profile?.appleUserId == nil ? "Bağlı değil" : "Bağlı")
            LineRow("iCloud eşitleme", value: syncDescription)
        }
    }

    private var moreSection: some View {
        LineSection("Daha fazla") {
            moreLink(.books)
            moreLink(.social)
        }
    }

    private func moreLink(_ section: AppSection) -> some View {
        NavigationLink(value: section) {
            LineRow(section.title) {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.fkTertiaryLabel)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.link.\(section.rawValue)")
    }

    private var syncDescription: String {
        switch syncService?.status ?? .disabled {
        case .disabled: "Kapalı"
        case .idle: "Güncel"
        case .syncing: "Eşitleniyor"
        case .error: "Hata"
        }
    }
}

#Preview {
    NavigationStack { SettingsScreen() }
        .fokusTheme()
        .modelContainer(PreviewSupport.onboardedContainer())
}
