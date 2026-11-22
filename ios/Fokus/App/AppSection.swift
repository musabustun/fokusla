import SwiftUI

/// Uygulama bölümleri (web `NAV_ITEMS` ile aynı sıra ve etiketler).
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case today, focus, analysis, books, tasks, social, settings

    var id: String { rawValue }

    /// Kullanıcıya görünen Türkçe etiket.
    var title: String {
        switch self {
        case .today: "Bugün"
        case .focus: "Odak"
        case .analysis: "Analiz"
        case .books: "Kitaplar"
        case .tasks: "Görevler"
        case .social: "Sosyal"
        case .settings: "Ayarlar"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .focus: "timer"
        case .analysis: "chart.bar"
        case .books: "books.vertical"
        case .tasks: "checklist"
        case .social: "person.2"
        case .settings: "gearshape"
        }
    }

    /// iPhone alt tab bar'ında görünür mü? (Kitaplar ve Sosyal Bugün/Ayarlar'dan açılır.)
    var inTabBar: Bool {
        switch self {
        case .books, .social: false
        default: true
        }
    }

    /// Bu derlemede kullanıcıya gösterilir mi? Sosyal henüz sahte (mock) arkadaş verisiyle çalıştığı için
    /// yalnızca DEBUG derlemelerinde (ve UI testlerinde) görünür; Release'te giriş noktaları gizlenir.
    var isAvailable: Bool {
        #if DEBUG
        // Mağaza ekran görüntüleri (`-FokusDemoData`) Release görünümüyle aynı olsun: Sosyal gizli.
        self != .social || !ProcessInfo.processInfo.arguments.contains("-FokusDemoData")
        #else
        self != .social
        #endif
    }

    /// Kenar çubuğu, "Diğer" listeleri ve tab bar için kullanılacak bölümler (`isAvailable` süzgeci).
    static var availableSections: [AppSection] { allCases.filter(\.isAvailable) }

    static var tabBarSections: [AppSection] { availableSections.filter(\.inTabBar) }
}
