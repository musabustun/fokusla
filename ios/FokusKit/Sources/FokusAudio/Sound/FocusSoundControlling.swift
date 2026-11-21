import Foundation
import Observation

/// Cihazda üretilen odak seslerinin türleri. Hiçbir ses dosyası yoktur; hepsi `AVAudioEngine` ile
/// gerçek zamanlı sentezlenir (indirme yok, telif yok, ağ yok).
public enum FocusSoundKind: String, CaseIterable, Sendable, Identifiable, Codable {
    case whiteNoise, pinkNoise, brownNoise, rain, melody

    public var id: String { rawValue }

    /// Arayüzde gösterilen Türkçe ad.
    public var title: String {
        switch self {
        case .whiteNoise: "Beyaz gürültü"
        case .pinkNoise: "Pembe gürültü"
        case .brownNoise: "Kahverengi gürültü"
        case .rain: "Yağmur"
        case .melody: "Yumuşak melodi"
        }
    }

    /// Kısa açıklama (seçici satırının alt metni).
    public var subtitle: String {
        switch self {
        case .whiteNoise: "Parlak, düz bir fon"
        case .pinkNoise: "Dengeli, doğal bir fon"
        case .brownNoise: "Derin, yumuşak uğultu"
        case .rain: "Yağmur ve damla sesleri"
        case .melody: "Yavaş, sakin bir pad"
        }
    }

    /// SF Symbols adı.
    public var symbolName: String {
        switch self {
        case .whiteNoise: "waveform"
        case .pinkNoise: "waveform.path"
        case .brownNoise: "waveform.low"
        case .rain: "cloud.rain"
        case .melody: "music.note"
        }
    }
}

/// Odak sesi oynatıcısının arayüzü. Arayüz (SwiftUI) yalnızca bu sözleşmeye bağlanır; gerçek
/// uygulama `FocusSoundPlayer`, test/önizleme için sahte uygulamalar yazılabilir.
/// `Observable`: uygulamalar `@Observable` olmalı ki görünümler durumu izleyebilsin.
@MainActor
public protocol FocusSoundControlling: AnyObject, Observable {
    /// Seçili ses; `nil` = kapalı. `isPlaying` yalnızca çalarken `true` (kesintide `currentKind` kalır).
    var currentKind: FocusSoundKind? { get }
    var isPlaying: Bool { get }
    /// 0…1 (dışı kırpılır). Değişiklik anında çalan sese yansır; kalıcı saklanır.
    var volume: Double { get set }
    /// `true`: başka uygulamaların sesiyle (ör. Spotify) birlikte çalar (`.mixWithOthers`);
    /// `false`: onları susturur. Varsayılan `true`. Kalıcı saklanır.
    var mixesWithOtherAudio: Bool { get set }
    /// Uyku zamanlayıcısının biteceği an; zamanlayıcı yoksa `nil`.
    var sleepTimerEndsAt: Date? { get }
    /// Kullanıcıya gösterilecek Türkçe hata (ses oturumu açılamadı vb.); yoksa `nil`.
    var errorMessage: String? { get }

    /// Sesi başlatır (başka ses çalıyorsa onun yerine geçer). Ses çıkışı ilk çalıştırmada kurulur.
    func play(_ kind: FocusSoundKind)
    /// Sesi durdurur ve uyku zamanlayıcısını iptal eder.
    func stop()
    /// Uyku zamanlayıcısı: dakika sonra sesi yumuşakça kısıp durdurur; `nil` = iptal.
    func setSleepTimer(minutes: Int?)
}

/// Uyku zamanlayıcısı için hazır seçenekler (dakika).
public enum SleepTimerPresets {
    public static let minutes: [Int] = [15, 30, 45, 60, 90]
}
