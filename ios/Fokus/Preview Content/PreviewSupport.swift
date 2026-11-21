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
}
