import FokusData
import FokusDomain
import SwiftData

/// `#Preview`'lar için bellek içi container'lar.
@MainActor
enum PreviewSupport {
    static func emptyContainer() -> ModelContainer {
        do {
            return try FokusStore.makeInMemoryContainer()
        } catch {
            preconditionFailure("Önizleme container'ı kurulamadı: \(error)")
        }
    }

    /// Onboarding'i tamamlanmış profilli container.
    static func onboardedContainer(field: YksField = .say) -> ModelContainer {
        let container = emptyContainer()
        do {
            try ProfileRepository(context: container.mainContext)
                .completeOnboarding(field: field, appleUserId: nil, displayName: nil)
        } catch {
            preconditionFailure("Önizleme profili oluşturulamadı: \(error)")
        }
        return container
    }

    /// Sosyal önizlemeleri: sahte servis, bellek içi depo, gecikmesiz. `signedIn` ise kullanıcı adı alınmış gelir.
    static func socialService(signedIn: Bool) -> MockSocialService {
        let service = MockSocialService(
            sessionProvider: { signedIn ? "onizleme-kullanici" : nil }, storage: InMemorySocialStorage(),
            delayMs: 0, tickMs: 0, responseDelayMs: 0)
        Task {
            await service.refresh()
            if signedIn { _ = try? await service.claimUsername("onizleme") }
        }
        return service
    }
}
