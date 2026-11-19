import FokusData
import FokusDesign
import SwiftData
import SwiftUI

// GEÇİCİ iskelet — kabuk alt ajanı (AppEnvironment, AppRootView, onboarding) ile değiştirilecek.
@main
struct FokusApp: App {
    private let container: ModelContainer

    init() {
        FokusFonts.registerAll()
        do {
            container = try FokusStore.makeContainer(mode: .local)
        } catch {
            fatalError("ModelContainer kurulamadı: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ScreenHeader("Bugün", eyebrow: "Fokus")
                .padding()
                .fokusTheme()
        }
        .modelContainer(container)
    }
}
