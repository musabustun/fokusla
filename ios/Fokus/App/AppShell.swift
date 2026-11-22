import FokusDesign
import SwiftUI

/// Uyarlanır kabuk: iPhone (compact) → alt tab bar; iPad (regular) → kenar çubuğu.
struct AppShell: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// Seçili bölüm kabukta tutulur (kabuğa değil): iPhone yan çevrilince boyut sınıfı değişip kabuk
    /// yeniden kurulsa bile (ör. Odak tam ekranından yatayda çıkış) kullanıcı Bugün'e düşmez.
    @State private var selection: AppSection = .today

    var body: some View {
        if horizontalSizeClass == .compact {
            CompactShell(selection: $selection)
        } else {
            RegularShell(
                selection: Binding(
                    get: { selection },
                    set: { if let newValue = $0 { selection = newValue } }))
        }
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
    @Binding var selection: AppSection

    var body: some View {
        TabView(selection: $selection) {
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
    @Binding var selection: AppSection?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(AppSection.allCases, selection: $selection) { section in
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
                (selection ?? .today).screen
                    .toolbarVisibility(.hidden, for: .navigationBar)
            }
            .id(selection)
        }
    }
}
