import FokusData
import FokusDesign
import FokusDomain
import SwiftData
import SwiftUI

/// Ayarlar modülü (web `features/settings` ile aynı davranış): profil, hesap, eşitleme, görünüm,
/// günlük hedef, hatırlatmalar, veri ve hakkında.
struct SettingsScreen: View {
    private static let repositoryURL = URL(string: "https://github.com/musabustun/fokusla")!
    private static let privacySummary = "Verilerin cihazında kalır; yalnızca iCloud hesabınla eşitlenir."

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.syncService) private var syncService
    @Environment(\.modelContext) private var modelContext
    @AppStorage(FokusThemeKeys.appearance) private var appearanceRaw = FokusAppearance.default.rawValue
    @AppStorage(FokusThemeKeys.palette) private var paletteRaw = FokusPalette.default.rawValue

    @Query(
        filter: #Predicate<UserProfile> { $0.deletedAt == nil },
        sort: \UserProfile.createdAt
    ) private var profiles: [UserProfile]

    @State private var sheet: SettingsSheet?

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                ScreenHeader("Ayarlar", eyebrow: "Fokus")
                profileSection
                SettingsAccountSection(profile: profile, sheet: $sheet)
                syncSection
                appearanceSection
                paletteSection
                SettingsGoalReminderSection(profile: profile)
                dataSection
                aboutSection
                if horizontalSizeClass == .compact { moreSection }
            }
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.vertical, FokusSpacing.lg)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(.fkBackground)
        .accessibilityIdentifier("screen.settings")
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .displayName:
                DisplayNameSheet(initialName: profile?.displayName ?? "") { self.sheet = nil }
            case .field:
                FieldSheet(current: profile?.field ?? .say) { self.sheet = nil }
            case .deleteAccount:
                DangerFlowSheet(flow: .deleteAccount) { self.sheet = nil }
            case .wipeData:
                DangerFlowSheet(flow: .wipeData) { self.sheet = nil }
            }
        }
    }

    // MARK: - Profil

    private var profileSection: some View {
        LineSection("Profil") {
            SettingsButtonRow(
                title: "Görünen ad", value: profile?.displayName ?? "Ekle", showsChevron: true
            ) { sheet = .displayName }
            .accessibilityIdentifier("settings.row.name")
            SettingsButtonRow(
                title: "YKS alanı", value: profile?.field.label ?? "—", showsChevron: true
            ) { sheet = .field }
            .accessibilityIdentifier("settings.row.field")
        }
    }

    // MARK: - Eşitleme

    private var syncSection: some View {
        LineSection("Eşitleme", footer: syncFooter) {
            SettingsToggleRow(
                title: "iCloud eşitleme", subtitle: syncDescription,
                isOn: Binding(
                    get: { syncService?.isEnabled ?? false },
                    set: { syncService?.setEnabled($0) }
                )
            )
            .accessibilityIdentifier("settings.sync")
        }
    }

    private var syncFooter: String {
        if syncService?.isEnabled == true {
            return "Verilerin yalnızca iCloud hesabındaki özel alana gönderilir; Fokus'un sunucusu yoktur. Değişiklik uygulama yeniden açıldığında geçerli olur."
        }
        return "Açarsan verilerin iCloud hesabınla iPhone ve iPad'in arasında eşitlenir. Değişiklik uygulama yeniden açıldığında geçerli olur."
    }

    private var syncDescription: String {
        guard syncService?.isEnabled == true else { return "Kapalı" }
        switch syncService?.status ?? .disabled {
        case .disabled: return "Bu cihazda etkin değil (iCloud hesabı yok ya da yerel mod)"
        case .idle: return "Güncel"
        case .syncing: return "Eşitleniyor…"
        case let .error(message): return "Hata: \(message)"
        }
    }

    // MARK: - Görünüm

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

    // MARK: - Veri

    private var dataSection: some View {
        LineSection(
            "Veri",
            footer: "Tüm verilerini tek bir JSON dosyası olarak paylaşır. Dosya yalnızca cihazında oluşturulur."
        ) {
            ShareLink(
                item: BackupFile(container: modelContext.container),
                preview: SharePreview("Fokus yedeği")
            ) {
                LineRow("Verileri dışa aktar", subtitle: "JSON olarak paylaş", showsChevron: false)
            }
            .buttonStyle(.fokusRow)
            .accessibilityIdentifier("settings.export")
            SettingsButtonRow(title: "Tüm verileri sil", isDestructive: true) { sheet = .wipeData }
                .accessibilityIdentifier("settings.wipe")
        }
    }

    // MARK: - Hakkında

    private var aboutSection: some View {
        LineSection("Hakkında", footer: "Fokus ücretsiz, reklamsız ve açık kaynaktır.") {
            LineRow("Sürüm", value: Self.appVersion)
            LineRow("Lisans", value: "MIT")
            Link(destination: Self.repositoryURL) {
                LineRow("Açık kaynak — GitHub", subtitle: "github.com/musabustun/fokusla", showsChevron: true)
            }
            .buttonStyle(.fokusRow)
            .accessibilityIdentifier("settings.github")
            LineRow("Gizlilik", subtitle: Self.privacySummary)
        }
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    // MARK: - Daha fazla (iPhone)

    private var moreSection: some View {
        LineSection("Daha fazla") {
            moreLink(.books)
            if AppSection.social.isAvailable { moreLink(.social) }
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
}

#Preview {
    NavigationStack { SettingsScreen() }
        .fokusTheme()
        .modelContainer(PreviewSupport.onboardedContainer())
}
