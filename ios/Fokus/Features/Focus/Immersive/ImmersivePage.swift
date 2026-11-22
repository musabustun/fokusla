import Foundation

/// Tam ekran odak görünümünün yatay kaydırmalı sayfaları (sıra = kaydırma sırası).
/// Raw değerler `AppStorage` ve UI testi başlatma argümanında (`-fokus.focus.immersivePage night`) kullanılır.
enum ImmersivePage: String, CaseIterable, Identifiable, Sendable {
    case stopwatch, ring, night, summary, sound

    /// Son seçilen sayfanın saklandığı `UserDefaults` anahtarı.
    static let storageKey = "fokus.focus.immersivePage"
    static let `default`: ImmersivePage = .stopwatch

    var id: String { rawValue }

    /// VoiceOver'da sayfa göstergesinin okuduğu ad.
    var title: String {
        switch self {
        case .stopwatch: "Kronometre"
        case .ring: "Halka"
        case .night: "Gece"
        case .summary: "Bugünün özeti"
        case .sound: "Ses ve müzik"
        }
    }

    var accessibilityIdentifier: String { "immersive.page.\(rawValue)" }

    /// 0 tabanlı sıra.
    var position: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// Verilen sayfaya `offset` kadar kayar; uçlarda durur.
    func advanced(by offset: Int) -> ImmersivePage {
        let all = Self.allCases
        return all[min(max(position + offset, 0), all.count - 1)]
    }
}
