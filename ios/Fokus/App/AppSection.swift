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

    /// Bu derlemede kullanıcıya gösterilir mi? Bugün hepsi açık; yarım bir bölümü gizlemek için tek nokta.
    var isAvailable: Bool { true }

    /// Kenar çubuğu, "Diğer" listeleri ve tab bar için kullanılacak bölümler (`isAvailable` süzgeci).
    static var availableSections: [AppSection] { allCases.filter(\.isAvailable) }

    static var tabBarSections: [AppSection] { availableSections.filter(\.inTabBar) }
}
