import FokusData
import SwiftData
import SwiftUI

/// Sistem entegrasyonlarını güncel tutar: uygulama öne gelince ve veri kaydedilince Live Activity'yi
/// açık oturumla eşitler (oturum başlayınca başlar, mola/devam'da güncellenir, bitince kapanır) ve
/// widget zaman çizelgelerini yeniler. Kayıt dalgalarını tek çağrıya indirmek için kısa süre bekler.
/// Odak filtresi ayarları da öne gelince okunur (bkz. `FocusFilterStore`).
struct FocusSystemCoordinator: ViewModifier {
    private static let debounce: Duration = .milliseconds(600)

    @Environment(\.scenePhase) private var scenePhase
    @State private var pending: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .task { schedule(after: .zero) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    schedule(after: .zero)
                    Task { await FocusFilterStore.refreshFromSystem() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                schedule(after: Self.debounce)
            }
    }

    private func schedule(after delay: Duration) {
        pending?.cancel()
        let canStart = scenePhase == .active
        pending = Task { @MainActor in
            if delay > .zero { try? await Task.sleep(for: delay) }
            guard !Task.isCancelled else { return }
            await FocusLiveActivitySync.sync(canStart: canStart)
            FokusSystem.reloadWidgets()
            FocusLinkCoordinator.shared.publish()
        }
    }
}

extension View {
    /// Kök görünüme uygulanır (`FokusApp`).
    func fokusSystemIntegration() -> some View { modifier(FocusSystemCoordinator()) }
}
