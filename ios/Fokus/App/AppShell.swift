import FokusDesign
import SwiftUI

/// Uyarlanır kabuk: iPhone (compact) → alt tab bar; iPad (regular) → kenar çubuğu.
struct AppShell: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// Seçili bölüm kabukta tutulur (kabuğa değil): iPhone yan çevrilince boyut sınıfı değişip kabuk
    /// yeniden kurulsa bile (ör. Odak tam ekranından yatayda çıkış) kullanıcı Bugün'e düşmez.
    /// Ekranlar (Bugün'ün "Odak başlat" düğmesi) bölüm değiştirmek için `AppNavigation`'ı ortamdan okur.
    @State private var navigation = AppNavigation()

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                CompactShell()
            } else {
                RegularShell()
            }
        }
        .environment(navigation)
    }
}

private extension View {
    /// Bugün/Ayarlar'dan açılan ikincil bölümler (Kitaplar, Sosyal) için hedef.
    func appSectionDestinations() -> some View {
        navigationDestination(for: AppSection.self) { section in
            section.screen.navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct CompactShell: View {
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selection) {
            ForEach(AppSection.tabBarSections) { section in
                Tab(section.title, systemImage: section.systemImage, value: section) {
                    NavigationStack {
                        // Kök ekranlar kendi başlığını çizer; gezinme çubuğu gizlenir.
                        section.screen
                            .toolbarVisibility(.hidden, for: .navigationBar)
                            .appSectionDestinations()
                    }
                }
            }
        }
    }
}

private struct RegularShell: View {
    @Environment(\.fokusPalette) private var palette
    @Environment(AppNavigation.self) private var navigation
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    /// Kenar çubuğu seçimi (isteğe bağlı) ↔ paylaşılan gezinme durumu.
    private var selectionBinding: Binding<AppSection?> {
        Binding(
            get: { navigation.selection },
            set: { if let section = $0 { navigation.selection = section } })
    }

    var body: some View {
        let selection = navigation.selection
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(AppSection.availableSections, selection: selectionBinding) { section in
                // Seçili satır: vurgu dolgusu üzerinde `accentContrast` metin (AA); diğerleri `label`.
                Label(section.title, systemImage: section.systemImage)
                    .foregroundStyle(selection == section ? FokusColor(.accentContrast) : FokusColor(.label))
                    .tag(section)
                    .frame(minHeight: fokusMinTapTarget)
            }
            .tint(FokusColor.color(.accent, palette: palette))
            .accessibilityIdentifier("sidebar")
            .navigationTitle("Fokus")
        } detail: {
            NavigationStack {
                selection.screen
                    .toolbarVisibility(.hidden, for: .navigationBar)
            }
            .id(selection)
        }
    }
}
