import FokusDesign
import Foundation
import OSLog
import SwiftUI
import UIKit

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "app-icon")

/// Uygulama ikonunu seçili palete eşitler: palet değişince ve sahne her etkinleştiğinde (soğuk açılış
/// dahil). Kurallar saf `FokusAppIcon`'dadır; ikon zaten temaya uygunsa sistem çağrılmaz.
/// Sistem değişiklikte kısa bir "ikon değiştirildi" uyarısı gösterir (iOS davranışı).
private struct AppIconSyncModifier: ViewModifier {
    @AppStorage(FokusThemeKeys.palette) private var paletteRaw = FokusPalette.default.rawValue
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: paletteRaw) { _, raw in
                AppIconSynchronizer.shared.request(paletteRaw: raw)
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                guard phase == .active else { return }
                AppIconSynchronizer.shared.request(paletteRaw: paletteRaw)
            }
    }
}

/// `setAlternateIconName` çağrılarını sıraya koyar: art arda palet seçiminde yalnızca en son istek
/// uygulanır, eşzamanlı çağrı (sistem reddeder) olmaz.
@MainActor
final class AppIconSynchronizer {
    static let shared = AppIconSynchronizer()

    /// UI testlerinde kapalı: sistem uyarısı XCUITest dokunuşlarını engellemesin.
    private let isEnabled = !ProcessInfo.processInfo.arguments.contains(AppEnvironment.uiTestLaunchArgument)
    private var pendingPalette: FokusPalette?
    private var isApplying = false

    func request(paletteRaw: String) {
        guard isEnabled else { return }
        pendingPalette = FokusPalette(rawValue: paletteRaw) ?? .default
        guard !isApplying else { return }
        isApplying = true
        Task { await drain() }
    }

    private func drain() async {
        defer { isApplying = false }
        let app = UIApplication.shared
        while let palette = pendingPalette {
            pendingPalette = nil
            // Sistem, uygulama etkin değilken ikonu değiştirmez; sonraki etkinleşmede yeniden denenir.
            guard app.supportsAlternateIcons, app.applicationState == .active,
                  FokusAppIcon.needsUpdate(current: app.alternateIconName, palette: palette)
            else { continue }
            let name = FokusAppIcon.alternateName(for: palette)
            do {
                try await app.setAlternateIconName(name)
            } catch {
                logger.error("Uygulama ikonu değiştirilemedi (\(name ?? "AppIcon", privacy: .public)): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

extension View {
    /// Uygulama ikonunu palete eşitler (uygulama kökünde bir kez).
    func appIconFollowsPalette() -> some View {
        modifier(AppIconSyncModifier())
    }
}
