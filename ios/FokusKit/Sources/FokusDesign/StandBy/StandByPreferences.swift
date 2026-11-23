import Foundation
import SwiftUI

// Tam ekran odak ("StandBy") görünümünün kullanıcı tercihleri. Saf değer tipleri: uygulama
// `StandByPreferences`'ı JSON olarak UserDefaults'ta (App Group varsa orada) saklar, görünümler okur.
// Raw değerler KALICIDIR (saklanan JSON ve erişilebilirlik kimlikleri): yeniden adlandırma yok, yalnızca ekleme.

/// Tam ekran görünümün kart/sayfaları. Erişilebilirlik kimliği `immersive.page.<raw>`.
public enum StandByPage: String, CaseIterable, Codable, Identifiable, Sendable {
    /// Ekranı dolduran odak sayacı.
    case stopwatch
    /// Analog saat + küçük odak sayacı (StandBy ikili görünümü).
    case clock
    /// Günlük hedef halkası (hedef yoksa saatlik tur halkası).
    case ring
    /// Ders/konu bilgisi büyük yazıyla.
    case subject
    /// Bugünün özeti (toplam, oturum, ortalamalar).
    case summary
    /// Şimdi çalıyor (yalnızca müzik sağlayıcısı bağlıyken görünür).
    case music
    /// Saf siyah, soluk sayaç (yatak başı).
    case night
    /// Odak sesleri ve müzik bağlantısı.
    case sound

    public var id: String { rawValue }

    /// Kullanıcıya görünen ad (sayfa göstergesi, düzenleyici).
    public var title: String {
        switch self {
        case .stopwatch: "Kronometre"
        case .clock: "Saat"
        case .ring: "Hedef halkası"
        case .subject: "Ders"
        case .summary: "Bugünün özeti"
        case .music: "Şimdi çalıyor"
        case .night: "Gece"
        case .sound: "Ses ve müzik"
        }
    }

    /// Düzenleyicideki SF Symbol.
    public var symbolName: String {
        switch self {
        case .stopwatch: "timer"
        case .clock: "clock"
        case .ring: "circle.dashed"
        case .subject: "book.closed"
        case .summary: "chart.bar.xaxis"
        case .music: "music.note"
        case .night: "moon"
        case .sound: "speaker.wave.2"
        }
    }

    /// Yalnızca müzik sağlayıcısı bağlıyken gösterilir.
    public var requiresMusic: Bool { self == .music }

    public var accessibilityIdentifier: String { "immersive.page.\(rawValue)" }
}

/// Büyük sayaç yazı tipi stili (kilit ekranı saat stilleri gibi). Yalnızca gömülü fontlar ve sistem fontu.
public enum StandByClockStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    /// JetBrains Mono Regular — "Gece mesaisi" varsayılanı.
    case mono
    /// Bricolage Grotesque ExtraBold — iddialı başlık yazısı.
    case grotesk
    /// SF Pro Rounded, yarı kalın.
    case rounded
    /// SF Pro, ince (kilit ekranı saati gibi).
    case thin
    /// SF Pro sıkıştırılmış, kalın (StandBy dijital saati gibi).
    case condensed

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mono: "Mono"
        case .grotesk: "Grotesk"
        case .rounded: "Yuvarlak"
        case .thin: "İnce"
        case .condensed: "Dar"
        }
    }

    /// Verilen sabit puntoda yazı tipi (boyut alana göre hesaplanır; Dynamic Type ile ölçeklenmez).
    public func font(size: CGFloat) -> Font {
        switch self {
        case .mono: .custom(FokusFonts.monoRegular, fixedSize: size)
        case .grotesk: .custom(FokusFonts.displayExtraBold, fixedSize: size)
        case .rounded: .system(size: size, weight: .semibold, design: .rounded)
        case .thin: .system(size: size, weight: .thin)
        case .condensed: .system(size: size, weight: .bold).width(.compressed)
        }
    }
}

/// Arka plan.
public enum StandByBackdrop: String, CaseIterable, Codable, Identifiable, Sendable {
    /// Tema zemini (`background`).
    case plain
    /// Zeminden vurgu tonuna çok hafif radyal geçiş.
    case gradient
    /// Yavaşça süzülen yumuşak vurgu lekeleri (hareket azaltmada durağan).
    case aura
    /// Saf siyah (OLED'de pikseller kapalı).
    case black

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .plain: "Düz"
        case .gradient: "Gradyan"
        case .aura: "Aura"
        case .black: "Siyah"
        }
    }
}

/// Gece kırmızısı (StandBy gece modu benzeri): tüm görünüm siyah üstünde soluk kırmızı tek renk.
public enum StandByNightMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case off
    /// Yerel saatle `nightStartHour`–`nightEndHour` arasında açık.
    case auto
    case on

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .off: "Kapalı"
        case .auto: "Otomatik"
        case .on: "Açık"
        }
    }

    public static let nightStartHour = 22
    public static let nightEndHour = 7

    /// Verilen anda gece kırmızısı etkin mi? (saf; `date` ve `calendar` dışarıdan gelir)
    public func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .off: return false
        case .on: return true
        case .auto:
            let hour = calendar.component(.hour, from: date)
            return hour >= Self.nightStartHour || hour < Self.nightEndHour
        }
    }
}

/// Tam ekran odak görünümünün tüm tercihleri. Değişiklikler yeni kopya döndürür (değişmezlik).
public struct StandByPreferences: Codable, Equatable, Sendable {
    /// Etkin sayfalar, kaydırma sırasıyla (tekrarsız).
    public var pages: [StandByPage]
    public var clockStyle: StandByClockStyle
    /// Tam ekrana özel palet; `nil` = uygulamanın paleti.
    public var accent: FokusPalette?
    /// Büyük rakamlar vurgu renginde mi (yoksa `label`)?
    public var tintedDigits: Bool
    public var backdrop: StandByBackdrop
    public var nightMode: StandByNightMode
    /// Müzik bağlıyken diğer sayfaların köşesinde küçük "şimdi çalıyor" çipi.
    public var showsNowPlayingChip: Bool

    public static let storageKey = "fokus.focus.standby"
    public static let defaultPages: [StandByPage] = [.stopwatch, .clock, .ring, .music, .summary, .night, .sound]

    public static let `default` = StandByPreferences(
        pages: defaultPages, clockStyle: .mono, accent: nil, tintedDigits: false, backdrop: .gradient,
        nightMode: .auto, showsNowPlayingChip: true)

    public init(
        pages: [StandByPage], clockStyle: StandByClockStyle, accent: FokusPalette?, tintedDigits: Bool,
        backdrop: StandByBackdrop, nightMode: StandByNightMode, showsNowPlayingChip: Bool
    ) {
        self.pages = Self.unique(pages)
        self.clockStyle = clockStyle
        self.accent = accent
        self.tintedDigits = tintedDigits
        self.backdrop = backdrop
        self.nightMode = nightMode
        self.showsNowPlayingChip = showsNowPlayingChip
    }

    // MARK: Okuma

    public func isEnabled(_ page: StandByPage) -> Bool { pages.contains(page) }

    /// Gösterilecek sayfalar: müzik sayfası yalnızca bağlıyken. Hiç sayfa kalmazsa kronometre.
    public func visiblePages(isMusicConnected: Bool) -> [StandByPage] {
        let visible = pages.filter { !$0.requiresMusic || isMusicConnected }
        return visible.isEmpty ? [.stopwatch] : visible
    }

    /// Kapatılabilir mi? En az bir müzik dışı sayfa açık kalmalı.
    public func canDisable(_ page: StandByPage) -> Bool {
        isEnabled(page) && pages.contains { $0 != page && !$0.requiresMusic }
    }

    /// Etkin palet.
    public func palette(appPalette: FokusPalette) -> FokusPalette { accent ?? appPalette }

    // MARK: Değişiklikler (yeni kopya)

    /// Açıksa kapatır (izin varsa), kapalıysa sona ekler.
    public func toggling(_ page: StandByPage) -> StandByPreferences {
        var copy = self
        if isEnabled(page) {
            guard canDisable(page) else { return self }
            copy.pages = pages.filter { $0 != page }
        } else {
            copy.pages = pages + [page]
        }
        return copy
    }

    /// Listeden sürükle-bırak (`List.onMove` imzası).
    public func moving(fromOffsets source: IndexSet, toOffset destination: Int) -> StandByPreferences {
        var copy = self
        copy.pages.move(fromOffsets: source, toOffset: destination)
        return copy
    }

    /// Bir sayfayı `offset` kadar kaydırır (erişilebilirlik "yukarı/aşağı taşı"); uçlarda sıkıştırılır.
    public func moving(_ page: StandByPage, by offset: Int) -> StandByPreferences {
        guard let index = pages.firstIndex(of: page) else { return self }
        let target = min(max(index + offset, 0), pages.count - 1)
        guard target != index else { return self }
        var copy = self
        copy.pages.remove(at: index)
        copy.pages.insert(page, at: target)
        return copy
    }

    /// Tek alanı değiştirilmiş kopya.
    public func with<Value>(
        _ keyPath: WritableKeyPath<StandByPreferences, Value>, _ value: Value
    ) -> StandByPreferences {
        var copy = self
        copy[keyPath: keyPath] = value
        copy.pages = Self.unique(copy.pages)
        return copy
    }

    // MARK: Kodlama

    private enum CodingKeys: String, CodingKey {
        case pages, clockStyle, accent, tintedDigits, backdrop, nightMode, showsNowPlayingChip
    }

    /// Hoşgörülü çözme: eksik alan → varsayılan, bilinmeyen sayfa/değer → atlanır/varsayılan.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Self.default
        func string(_ key: CodingKeys) -> String? {
            (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil
        }
        func bool(_ key: CodingKeys) -> Bool? {
            (try? container.decodeIfPresent(Bool.self, forKey: key)) ?? nil
        }
        let rawPages = (try? container.decodeIfPresent([String].self, forKey: .pages)) ?? nil
        let decodedPages = rawPages.map { $0.compactMap(StandByPage.init(rawValue:)) } ?? fallback.pages
        self.init(
            pages: decodedPages.isEmpty ? fallback.pages : decodedPages,
            clockStyle: string(.clockStyle).flatMap(StandByClockStyle.init(rawValue:)) ?? fallback.clockStyle,
            accent: string(.accent).flatMap(FokusPalette.init(rawValue:)),
            tintedDigits: bool(.tintedDigits) ?? fallback.tintedDigits,
            backdrop: string(.backdrop).flatMap(StandByBackdrop.init(rawValue:)) ?? fallback.backdrop,
            nightMode: string(.nightMode).flatMap(StandByNightMode.init(rawValue:)) ?? fallback.nightMode,
            showsNowPlayingChip: bool(.showsNowPlayingChip) ?? fallback.showsNowPlayingChip)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pages.map(\.rawValue), forKey: .pages)
        try container.encode(clockStyle.rawValue, forKey: .clockStyle)
        try container.encodeIfPresent(accent?.rawValue, forKey: .accent)
        try container.encode(tintedDigits, forKey: .tintedDigits)
        try container.encode(backdrop.rawValue, forKey: .backdrop)
        try container.encode(nightMode.rawValue, forKey: .nightMode)
        try container.encode(showsNowPlayingChip, forKey: .showsNowPlayingChip)
    }

    /// Saklanan veriden okur; boş/bozuk veri → varsayılan.
    public static func decoded(from data: Data?) -> StandByPreferences {
        guard let data, !data.isEmpty,
            let value = try? JSONDecoder().decode(StandByPreferences.self, from: data)
        else { return .default }
        return value
    }

    /// Saklanacak veri (anahtar sırası sabit).
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    private static func unique(_ pages: [StandByPage]) -> [StandByPage] {
        var seen = Set<StandByPage>()
        return pages.filter { seen.insert($0).inserted }
    }
}
