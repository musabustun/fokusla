import Foundation

/// Onboarding adımları (web `onboardingFlow.ts`): Hoş geldin → YKS alanı → Temanı seç → Apple ile Giriş.
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case field
    case theme
    case account

    /// Akışta gösterilen adımlar, sırayla.
    static let flow: [OnboardingStep] = allCases

    func next() -> OnboardingStep? {
        guard let index = Self.flow.firstIndex(of: self), index + 1 < Self.flow.count else { return nil }
        return Self.flow[index + 1]
    }

    func previous() -> OnboardingStep? {
        guard let index = Self.flow.firstIndex(of: self), index > 0 else { return nil }
        return Self.flow[index - 1]
    }
}
