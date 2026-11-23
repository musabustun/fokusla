import FokusDesign
import SwiftUI

/// Saat ekranı için küçük tipografi/düğme yardımcıları ("Gece mesaisi": koyu zemin, tek kehribar vurgu,
/// mono rakamlar). Renkler yalnızca `FokusDesign` token'larından gelir.
enum WatchFont {
    /// Büyük sayaç/rakam: JetBrains Mono (eş genişlikli).
    static func numeral(_ size: CGFloat) -> Font { .custom(FokusFonts.monoRegular, size: size) }
}

/// Ekranın ANA eylemi: kehribar hap (ekranda bir tane).
struct WatchPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.fkAccentContrast)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Capsule().fill(.fkAccent))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// İkincil yuvarlak düğme (çizgili); `filled` kehribar dolgu (duraklat/devam).
struct WatchCircleButtonStyle: ButtonStyle {
    var filled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .foregroundStyle(filled ? .fkAccentContrast : .fkLabel)
            .frame(width: 56, height: 56)
            .background { if filled { Circle().fill(.fkAccent) } }
            .overlay { if !filled { Circle().stroke(.fkSeparatorStrong, lineWidth: 1.5) } }
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension View {
    /// Bölüm etiketi: küçük, mono, BÜYÜK HARF, ikincil renk.
    func watchEyebrow() -> some View {
        fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
    }
}
