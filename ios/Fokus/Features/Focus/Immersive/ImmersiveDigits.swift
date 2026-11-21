import FokusDesign
import SwiftUI

/// Verilen alana sığacak şekilde ölçeklenen büyük, eş genişlikli (JetBrains Mono) rakamlar.
/// Punto boyutu alandan hesaplandığı için `FokusTextStyle` yerine `FokusFonts.monoRegular` doğrudan
/// kullanılır (tasarım sisteminde "ekranı dolduran rakam" stili yok). Renk dışarıdan `foregroundStyle`.
struct ImmersiveDigits: View {
    let text: String

    /// JetBrains Mono ilerleme genişliği (em) ve uyguladığımız harf aralığı (em).
    private static let advanceEm: CGFloat = 0.6
    private static let trackingEm: CGFloat = -0.02
    /// Satır kutusu yüksekliği için pay (em): glifler kutudan küçüktür, yalnızca hafif taşmaya izin verir.
    private static let lineBoxEm: CGFloat = 1.15
    private static let fitMargin: CGFloat = 0.96
    private static let sizeRange: ClosedRange<CGFloat> = 12...640

    /// Alana sığan en büyük punto (saf; testlerde doğrulanabilir).
    static func fontSize(characterCount: Int, in size: CGSize) -> CGFloat {
        let count = CGFloat(max(characterCount, 1))
        let byWidth = size.width / (count * (advanceEm + trackingEm))
        let byHeight = size.height / lineBoxEm
        let fitted = min(byWidth, byHeight) * fitMargin
        return min(max(fitted, sizeRange.lowerBound), sizeRange.upperBound)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = Self.fontSize(characterCount: text.count, in: proxy.size)
            Text(text)
                .font(.custom(FokusFonts.monoRegular, fixedSize: size))
                .tracking(Self.trackingEm * size)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }
}
