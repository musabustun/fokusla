import SwiftUI

/// Ortak buton gövdesi: basınca 0.97 ölçek (hareket azaltmada yok), devre dışıyken %40 opaklık.
private struct FokusButtonBody<Label: View>: View {
    enum Kind { case primary, secondary, plain, destructive }

    let kind: Kind
    let label: Label
    let isPressed: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        label
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: kind == .plain ? nil : .infinity, minHeight: minHeight)
            .padding(.horizontal, FokusSpacing.xl)
            .background { if kind == .primary { Capsule().fill(.fkAccent) } }
            .overlay { border }
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(isPressed && isEnabled && !reduceMotion ? FokusMotion.pressScale : 1)
            .animation(reduceMotion ? nil : FokusMotion.pressAnimation, value: isPressed)
    }

    private var minHeight: CGFloat {
        kind == .plain ? fokusMinTapTarget : fokusMinTapTarget + 8
    }

    private var foreground: FokusColor {
        switch kind {
        case .primary: .fkAccentContrast
        case .secondary, .plain: .fkLabel
        case .destructive: .fkDanger
        }
    }

    @ViewBuilder private var border: some View {
        switch kind {
        case .secondary: Capsule().strokeBorder(.fkSeparatorStrong, lineWidth: 1)
        case .destructive: Capsule().strokeBorder(.fkDanger, lineWidth: 1)
        case .primary, .plain: EmptyView()
        }
    }
}

/// Ana eylem: kehribar dolgulu hap (web `Button` filled). Ekranda bir tane.
public struct FokusPrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        FokusButtonBody(kind: .primary, label: configuration.label, isPressed: configuration.isPressed)
    }
}

/// İkincil eylem: çizgili hap (web `Button` tinted).
public struct FokusSecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        FokusButtonBody(kind: .secondary, label: configuration.label, isPressed: configuration.isPressed)
    }
}

/// Sessiz, nötr metin eylemi (web `Button` plain): araç çubuğu, "Tümü".
public struct FokusPlainButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        FokusButtonBody(kind: .plain, label: configuration.label, isPressed: configuration.isPressed)
    }
}

/// Yıkıcı eylem: kırmızı çizgili hap (web `Button` destructive).
public struct FokusDestructiveButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        FokusButtonBody(kind: .destructive, label: configuration.label, isPressed: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FokusPrimaryButtonStyle {
    public static var fokusPrimary: FokusPrimaryButtonStyle { FokusPrimaryButtonStyle() }
}

extension ButtonStyle where Self == FokusSecondaryButtonStyle {
    public static var fokusSecondary: FokusSecondaryButtonStyle { FokusSecondaryButtonStyle() }
}

extension ButtonStyle where Self == FokusPlainButtonStyle {
    public static var fokusPlain: FokusPlainButtonStyle { FokusPlainButtonStyle() }
}

extension ButtonStyle where Self == FokusDestructiveButtonStyle {
    public static var fokusDestructive: FokusDestructiveButtonStyle { FokusDestructiveButtonStyle() }
}

#Preview("Butonlar — koyu") {
    FokusPreviewCanvas(.dark) { ButtonsPreviewContent() }
}

#Preview("Butonlar — açık") {
    FokusPreviewCanvas(.light) { ButtonsPreviewContent() }
}

private struct ButtonsPreviewContent: View {
    var body: some View {
        VStack(spacing: FokusSpacing.md) {
            Button("Başlat") {}.buttonStyle(.fokusPrimary)
            Button("Başlat (devre dışı)") {}.buttonStyle(.fokusPrimary).disabled(true)
            Button("Ders seç") {}.buttonStyle(.fokusSecondary)
            Button("Sil") {}.buttonStyle(.fokusDestructive)
            Button("Tümü") {}.buttonStyle(.fokusPlain)
        }
    }
}
