import FokusData
import FokusDesign
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "root")

/// Kök kapı: profil yok ya da onboarding bitmediyse onboarding, aksi halde kabuk.
struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.authService) private var authService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(
        filter: #Predicate<UserProfile> { $0.deletedAt == nil },
        sort: \UserProfile.createdAt
    ) private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }
    private var isOnboarded: Bool { profile?.onboardingCompletedAt != nil }

    var body: some View {
        Group {
            if isOnboarded {
                AppShell().transition(.opacity).socialInviteHost()
            } else {
                OnboardingView().transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: FokusMotion.enter), value: isOnboarded)
        .background(.fkBackground)
        .task(id: profile?.appleUserId) { await validateAppleCredential() }
        .modifier(ReminderCoordinator())
    }

    /// Apple kimliği iptal edilmiş/bulunamıyorsa bağı kaldırır; veri silinmez.
    private func validateAppleCredential() async {
        guard let appleUserId = profile?.appleUserId else { return }
        let status = await authService?.credentialStatus(for: appleUserId)
        guard let status, status == .revoked || status == .notFound else { return }
        do {
            try ProfileRepository(context: modelContext).setAppleUserId(nil)
        } catch {
            logger.error("Apple bağı kaldırılamadı: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#Preview("Onboarding") {
    AppRootView()
        .fokusTheme()
        .modelContainer(PreviewSupport.emptyContainer())
}

#Preview("Kabuk") {
    AppRootView()
        .fokusTheme()
        .modelContainer(PreviewSupport.onboardedContainer())
}
