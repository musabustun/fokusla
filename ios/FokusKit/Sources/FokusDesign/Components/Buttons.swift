import SwiftUI

/// Ana eylem: kehribar dolgulu hap (web `Button` filled).
public struct FokusPrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.fkAccentContrast)
            .frame(maxWidth: .infinity, minHeight: fokusMinTapTarget + 8)
            .padding(.horizontal, FokusSpacing.xl)
            .background(.fkAccent, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// İkincil eylem: çizgili hap (web `Button` tinted).
public struct FokusSecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.fkLabel)
            .frame(maxWidth: .infinity, minHeight: fokusMinTapTarget + 8)
            .padding(.horizontal, FokusSpacing.xl)
            .overlay(Capsule().strokeBorder(.fkSeparatorStrong, lineWidth: 1))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

extension ButtonStyle where Self == FokusPrimaryButtonStyle {
    public static var fokusPrimary: FokusPrimaryButtonStyle { FokusPrimaryButtonStyle() }
}

extension ButtonStyle where Self == FokusSecondaryButtonStyle {
    public static var fokusSecondary: FokusSecondaryButtonStyle { FokusSecondaryButtonStyle() }
}
