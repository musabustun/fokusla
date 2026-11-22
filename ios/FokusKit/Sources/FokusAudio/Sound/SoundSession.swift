import AVFoundation
import Foundation

/// Ses oturumu (AVAudioSession) yönetimi; testlerde sahte uygulama verilir.
@MainActor
protocol SoundSessionControlling: AnyObject {
    /// Kategori `.playback`, mod `.default`; `mixWithOthers` → `.mixWithOthers` seçeneği. Etkinleştirir.
    func activate(mixWithOthers: Bool) throws
    /// Etkinliği bırakır ve diğer uygulamalara (ör. Spotify) devam edebileceklerini bildirir.
    func deactivate()
}

/// Gerçek uygulama: iOS'ta `AVAudioSession`; macOS'ta (yalnızca geliştirme/test) hiçbir şey yapmaz.
@MainActor
final class AudioSessionController: SoundSessionControlling {
    init() {}

    #if os(iOS)
    func activate(mixWithOthers: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: mixWithOthers ? [.mixWithOthers] : [])
        try session.setActive(true)
    }

    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    #else
    func activate(mixWithOthers: Bool) throws {}
    func deactivate() {}
    #endif
}
