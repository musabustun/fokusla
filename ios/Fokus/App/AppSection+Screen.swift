import SwiftUI

extension AppSection {
    /// Bölümün ekranı.
    @MainActor @ViewBuilder
    var screen: some View {
        switch self {
        case .today: TodayScreen()
        case .focus: FocusScreen()
        case .analysis: AnalysisScreen()
        case .books: BooksScreen()
        case .tasks: TasksScreen()
        case .social: SocialScreen()
        case .settings: SettingsScreen()
        }
    }
}
