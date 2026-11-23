import SwiftUI

/// Gece kırmızısı sabitleri.
public enum StandByNightTint {
    /// Gece kırmızısı. Tasarım sisteminde belgelenmiş TEK ham renk istisnası (`Color.black` ile birlikte):
    /// gece modu paletten bağımsız, sabit ve çok koyu bir kırmızı olmalı; palet vurgusu burada kullanılamaz.
    public static let nightRed = Color(red: 0.86, green: 0.10, blue: 0.08)
    /// Gece kırmızısında içeriğin opaklığı (soluk).
    public static let dimming: Double = 0.55
}

/// Gece kırmızısı: içerik saf siyah üstünde, tek renk soluk kırmızı çizilir (StandBy gece modu gibi).
struct StandByNightTintModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            ZStack {
                Color.black.ignoresSafeArea()
                content
                    .environment(\.colorScheme, .dark)
                    .grayscale(1)
                    .colorMultiply(StandByNightTint.nightRed)
                    .opacity(StandByNightTint.dimming)
            }
        } else {
            content
        }
    }
}

extension View {
    /// Etkinse içeriği siyah üstünde soluk kırmızı tek renge çevirir; değilse içeriği değiştirmez.
    public func standByNightTint(_ isActive: Bool) -> some View {
        modifier(StandByNightTintModifier(isActive: isActive))
    }
}
