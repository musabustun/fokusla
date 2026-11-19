import SwiftUI

extension FokusMotion {
    /// Basınca küçülme geri bildirimi (120ms).
    public static var pressAnimation: Animation { .easeOut(duration: press) }

    /// Renk/arka plan geçişleri (200ms, web `ease-standard`).
    public static var baseAnimation: Animation { .timingCurve(0.2, 0, 0, 1, duration: base) }

    /// İlerleme halkası/çubuğu akışı (700ms, web `ease-emphasized`).
    public static var progressAnimation: Animation { .timingCurve(0.16, 1, 0.3, 1, duration: progress) }

    /// Basılı eylemlerin ölçeği (web `PRESS_SCALE`).
    public static let pressScale: CGFloat = 0.97
}
