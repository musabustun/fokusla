import FokusDesign
import SwiftUI

/// Uyarlanır kabuk: iPhone (compact) → alt tab bar; iPad (regular) → kenar çubuğu.
struct AppShell: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .compact {
            CompactShell()
        } else {
            RegularShell()
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
    @State private var selection: AppSection = .today

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
    @State private var selection: AppSection? = .today
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
                    .frame(minHeight: fokusMinTapTarget)
            }
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
