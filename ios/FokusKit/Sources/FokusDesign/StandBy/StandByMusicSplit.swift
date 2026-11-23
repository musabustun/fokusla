import CoreGraphics

/// Müzik widget'lı sayfaların iki bölgeli düzeni (saf; birim testli). Yatayda solda sayfa içeriği + sağda müzik
/// kontrolleri, dikeyde üstte içerik + altta kontroller.
public enum StandByMusicSplit {
    public enum Arrangement: Equatable, Sendable {
        /// Yatay: içerik solda, müzik sütunu sağda.
        case sideBySide
        /// Dikey: içerik üstte, müzik şeridi altta.
        case stacked
    }

    /// Genişlik > yükseklik × bu oran ise yatay düzen.
    public static let wideAspectThreshold: CGFloat = 1.15
    /// Müzik sütununun toplam genişlikteki payı ve sınırları.
    public static let sideColumnFraction: CGFloat = 0.40
    public static let sideColumnMinWidth: CGFloat = 280
    public static let sideColumnMaxWidth: CGFloat = 460
    /// Alttaki müzik şeridinin (kapak + metin + düğmeler) içerik yüksekliği.
    public static let bottomStripHeight: CGFloat = 112

    public static func arrangement(width: CGFloat, height: CGFloat) -> Arrangement {
        width > height * wideAspectThreshold ? .sideBySide : .stacked
    }

    /// Yatay düzende müzik sütununun genişliği (kenar boşlukları dahil, sayfanın sağ ucuna kadar).
    public static func sideColumnWidth(totalWidth: CGFloat) -> CGFloat {
        min(max(totalWidth * sideColumnFraction, sideColumnMinWidth), min(sideColumnMaxWidth, totalWidth * 0.6))
    }
}
