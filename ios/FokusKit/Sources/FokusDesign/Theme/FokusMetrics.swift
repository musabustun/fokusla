import SwiftUI

/// 4pt boşluk ızgarası (web `SPACING_UNIT`).
public enum FokusSpacing {
    public static let unit: CGFloat = 4
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    /// Ekran yatay kenar boşluğu.
    public static let screenHorizontal: CGFloat = 20
}

/// Köşe yarıçapları (web `RADII`).
public enum FokusRadius {
    public static let sm: CGFloat = 6
    public static let md: CGFloat = 10
    public static let lg: CGFloat = 14
    public static let xl: CGFloat = 20
}

/// Hareket süreleri (saniye; web `MOTION`). Hareket azaltma açıkken animasyon kullanma.
public enum FokusMotion {
    public static let press: Double = 0.12
    public static let base: Double = 0.2
    public static let enter: Double = 0.24
    public static let sheet: Double = 0.28
    public static let progress: Double = 0.7
}

/// En küçük dokunma hedefi (pt).
public let fokusMinTapTarget: CGFloat = 44
