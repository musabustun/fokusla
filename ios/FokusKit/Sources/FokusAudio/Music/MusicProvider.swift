import Foundation
import Observation

/// Odak sırasında bağlanılabilen harici müzik uygulamaları. Yeni sağlayıcı = yeni `case` + `MusicProvider`
/// uygulaması + `MusicProviderRegistry`'ye kayıt. `appleMusic` yalnızca UZANTI NOKTASIDIR: henüz
/// uygulanmadı (MusicKit/`MPMusicPlayerController` ile eklenecek).
public enum MusicProviderID: String, Sendable, CaseIterable, Identifiable {
    case spotify, appleMusic
    public var id: String { rawValue }
}

/// Çalan parça (sağlayıcıdan gelen anlık görüntü).
public struct MusicTrack: Equatable, Sendable {
    public var title: String
    public var artist: String
    /// Kapak görseli (PNG/JPEG baytları); yoksa `nil`.
    public var artworkData: Data?
    public var isPaused: Bool
    /// Çalıyor mu (`!isPaused`).
    public var isPlaying: Bool { !isPaused }

    public init(title: String, artist: String, artworkData: Data? = nil, isPaused: Bool = false) {
        self.title = title
        self.artist = artist
        self.artworkData = artworkData
        self.isPaused = isPaused
    }
}

/// Entegrasyonun bu cihazda kullanılabilirliği.
public enum MusicProviderAvailability: Equatable, Sendable {
    /// Yapılandırılmış ve uygulama yüklü: bağlanılabilir.
    case available
    /// `SPOTIFY_CLIENT_ID` boş: entegrasyon gizlenir.
    case notConfigured
    /// Müzik uygulaması yüklü değil: entegrasyon gizlenir, yerine "…'da aç" bağlantısı gösterilir.
    case appNotInstalled
}

public enum MusicConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case failed(MusicProviderError)
}

/// Sağlayıcı hataları; her biri kullanıcıya Türkçe, anlaşılır bir mesajla gösterilir.
public enum MusicProviderError: Error, Equatable, Sendable {
    case notConfigured
    case appNotInstalled
    /// Kullanıcı yetkilendirmeyi reddetti ya da iptal etti.
    case authorizationDenied
    /// Bağlantı kurulamadı/koptu ve otomatik yeniden denemeler tükendi (ya da token süresi doldu): "Yeniden bağlan" durumu.
    case connectionLost
    /// Komut reddedildi — çoğunlukla Spotify Premium gerektirir.
    case premiumRequired
    case commandFailed
    case unknown

    public var userMessage: String {
        switch self {
        case .notConfigured: "Spotify bağlantısı bu sürümde yapılandırılmamış."
        case .appNotInstalled: "Spotify uygulaması yüklü değil. Önce Spotify'ı App Store'dan yükle."
        case .authorizationDenied: "Spotify erişimi onaylanmadı. Bağlanmak için Spotify'da izin vermen gerekir."
        case .connectionLost: "Spotify bağlantısı kesildi. Yeniden bağlanmak için dokun."
        case .premiumRequired:
            "Spotify bu komutu kabul etmedi. Uygulamadan çalmayı denetlemek çoğunlukla Spotify Premium gerektirir."
        case .commandFailed: "Spotify komutu uygulanamadı. Biraz sonra tekrar dene."
        case .unknown: "Spotify ile bağlantı kurulamadı. Biraz sonra tekrar dene."
        }
    }
}

/// Harici müzik uygulaması sözleşmesi (Spotify, ileride Apple Music). Uygulamalar `@Observable`
/// olmalı; görünümler durumu bu özelliklerden izler.
@MainActor
public protocol MusicProvider: AnyObject, Observable {
    var id: MusicProviderID { get }
    /// "Spotify", "Apple Music"…
    var displayName: String { get }
    var availability: MusicProviderAvailability { get }
    var connectionState: MusicConnectionState { get }
    var nowPlaying: MusicTrack? { get }
    /// Bağlıyken reddedilen son komutun hatası (ör. Premium gerektiren atlama); bağlantıyı düşürmez.
    /// Sonraki başarılı komut ya da çalma durumu güncellemesiyle temizlenir. Varsayılan: `nil`.
    var lastCommandError: MusicProviderError? { get }
    /// Bağlantı kısa süreliğine yok ama sağlayıcı sessizce yeniden bağlanıyor (arka plandan dönüş, beklenmedik
    /// kopma). `connectionState` bu sırada `connected` kalır; komutlar yoksayılır. Varsayılan: `false`.
    var isReconnecting: Bool { get }
    /// Müzik uygulamasını doğrudan açan bağlantı (ör. `spotify:`); uygulama yüklü değilse açılmaz.
    var appURL: URL { get }
    /// Uygulama yüklü değilken açılacak web bağlantısı (ör. `https://open.spotify.com`).
    var webURL: URL { get }

    /// Yetkilendirir ve bağlanır. Sonuç `connectionState`'e yansır (hata `failed`).
    func connect()
    /// Bağlantıyı keser; çalan müziği durdurmaz (müzik uygulaması çalmaya devam eder).
    func disconnect()
    func togglePlayPause()
    func skipToNext()
    func skipToPrevious()
    /// `onOpenURL`'dan gelen geri dönüş bağlantısını işler; sağlayıcıya aitse `true`.
    func handleOpenURL(_ url: URL) -> Bool
    /// Uygulama öne geldi/arka plana gitti (App Remote gibi yalnızca ön planda yaşayan bağlantılar için).
    func sceneDidBecomeActive()
    func sceneWillResignActive()
}

extension MusicProvider {
    public var lastCommandError: MusicProviderError? { nil }
    public var isReconnecting: Bool { false }
}

/// Arayüzde bir sağlayıcının nasıl gösterileceği (saf; birim testli).
public enum MusicSectionMode: Equatable, Sendable {
    /// Yalnızca "…'da aç" bağlantısı (yapılandırılmamış ya da uygulama yüklü değil).
    case openLink
    /// "Bağlan" düğmesi (veya bağlanıyor / hata).
    case connect
    /// Çalan parça + kontroller.
    case controls

    public static func mode(
        availability: MusicProviderAvailability, connection: MusicConnectionState
    ) -> MusicSectionMode {
        guard availability == .available else { return .openLink }
        return connection == .connected ? .controls : .connect
    }
}

/// Uygulamadaki sağlayıcıların kaydı. Kök (`FokusApp`) kurar, ortama koyar; `onOpenURL` ve sahne
/// yaşam döngüsü buradan sağlayıcılara iletilir.
@MainActor
@Observable
public final class MusicProviderRegistry {
    public let providers: [any MusicProvider]

    public init(providers: [any MusicProvider] = []) {
        self.providers = providers
    }

    public func provider(_ id: MusicProviderID) -> (any MusicProvider)? {
        providers.first { $0.id == id }
    }

    @discardableResult
    public func handleOpenURL(_ url: URL) -> Bool {
        providers.contains { $0.handleOpenURL(url) }
    }

    public func sceneDidBecomeActive() { providers.forEach { $0.sceneDidBecomeActive() } }
    public func sceneWillResignActive() { providers.forEach { $0.sceneWillResignActive() } }
}
