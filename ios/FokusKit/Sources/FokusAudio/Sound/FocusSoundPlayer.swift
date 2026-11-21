import AVFoundation
import Foundation
import Observation
import os

private let playerLog = Logger(subsystem: "com.musabustun.fokus", category: "focus-sound")

/// Cihazda üretilen odak seslerini çalan oynatıcı (`AVAudioEngine` + `AVAudioSourceNode`).
/// Ses dosyası yoktur; beyaz/pembe/kahverengi gürültü, yağmur ve yumuşak melodi gerçek zamanlı
/// sentezlenir. Hacim ve "diğer seslerle karıştır" tercihi `UserDefaults`'ta kalıcıdır.
///
/// Arka planda ve kilitliyken çalmayı `UIBackgroundModes: audio` ve `.playback` kategorisi sağlar;
/// uygulama arka plana gidince motor durdurulmaz.
@MainActor
@Observable
public final class FocusSoundPlayer: FocusSoundControlling {
    public static let volumeDefaultsKey = "focus.sound.volume"
    public static let mixDefaultsKey = "focus.sound.mixWithOthers"

    public private(set) var currentKind: FocusSoundKind?
    public private(set) var isPlaying = false
    public private(set) var sleepTimerEndsAt: Date?
    public private(set) var errorMessage: String?

    public var volume: Double {
        didSet {
            let clamped = SoundMath.clampedVolume(volume)
            if clamped != volume {
                volume = clamped
                return
            }
            defaults.set(volume, forKey: Self.volumeDefaultsKey)
            engine.setVolume(volume)
        }
    }

    public var mixesWithOtherAudio: Bool {
        didSet {
            guard mixesWithOtherAudio != oldValue else { return }
            defaults.set(mixesWithOtherAudio, forKey: Self.mixDefaultsKey)
            guard currentKind != nil else { return }
            do {
                try session.activate(mixWithOthers: mixesWithOtherAudio)
            } catch {
                playerLog.error("karıştırma ayarı uygulanamadı: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let engine: any SoundEngineDriving
    @ObservationIgnored private let session: any SoundSessionControlling
    @ObservationIgnored private let sleepFadeDuration: TimeInterval
    @ObservationIgnored private let observers = NotificationObservers()
    @ObservationIgnored private var sleepTask: Task<Void, Never>?
    @ObservationIgnored private var stopTask: Task<Void, Never>?

    /// Parametresiz kullanım: `FocusSoundPlayer()`.
    public convenience init(defaults: UserDefaults = .standard) {
        self.init(
            defaults: defaults, engine: SoundEngine(), session: AudioSessionController(),
            sleepFadeDuration: SleepFade.defaultDuration)
    }

    init(
        defaults: UserDefaults,
        engine: any SoundEngineDriving,
        session: any SoundSessionControlling,
        sleepFadeDuration: TimeInterval
    ) {
        self.defaults = defaults
        self.engine = engine
        self.session = session
        self.sleepFadeDuration = sleepFadeDuration
        let storedVolume = defaults.object(forKey: Self.volumeDefaultsKey) as? Double
        volume = SoundMath.clampedVolume(storedVolume ?? SoundMath.defaultVolume)
        mixesWithOtherAudio = defaults.object(forKey: Self.mixDefaultsKey) as? Bool ?? true
        engine.onConfigurationChange = { [weak self] in self?.handleConfigurationChange() }
    }

    // MARK: FocusSoundControlling

    public func play(_ kind: FocusSoundKind) {
        stopTask?.cancel()
        stopTask = nil
        errorMessage = nil
        if sleepTimerEndsAt == nil { engine.setFadeFactor(1) }
        do {
            try session.activate(mixWithOthers: mixesWithOtherAudio)
        } catch {
            fail("Ses oturumu açılamadı. Başka bir uygulama sesi kullanıyor olabilir.", error: error)
            return
        }
        do {
            try engine.start(kind: kind, volume: volume)
        } catch {
            engine.stopNow()
            session.deactivate()
            fail("Ses başlatılamadı. Lütfen tekrar dene.", error: error)
            return
        }
        currentKind = kind
        isPlaying = true
        installObservers()
        playerLog.info("play: \(kind.rawValue, privacy: .public)")
    }

    public func stop() {
        cancelSleepTimer(restoresVolume: false)
        let wasActive = currentKind != nil || isPlaying
        currentKind = nil
        isPlaying = false
        errorMessage = nil
        removeObservers()
        guard wasActive || engine.isRunning else { return }
        playerLog.info("stop")
        stopTask?.cancel()
        let engine = engine
        let session = session
        stopTask = Task { @MainActor in
            await engine.fadeOutAndStop()
            if !Task.isCancelled { session.deactivate() }
        }
    }

    public func setSleepTimer(minutes: Int?) {
        setSleepTimer(seconds: minutes.map { Double(max($0, 0)) * 60 })
    }

    // MARK: Uyku zamanlayıcısı

    /// Saniye cinsinden zamanlayıcı (testler için; genel API dakika alır).
    func setSleepTimer(seconds: TimeInterval?) {
        cancelSleepTimer()
        guard let seconds, seconds > 0 else { return }
        let end = Date().addingTimeInterval(seconds)
        sleepTimerEndsAt = end
        playerLog.info("uyku zamanlayıcısı: \(Int(seconds)) sn")
        let fade = sleepFadeDuration
        sleepTask = Task { @MainActor [weak self] in
            let wait = max(0, end.timeIntervalSinceNow - fade)
            if wait > 0 {
                do { try await Task.sleep(for: .seconds(wait)) } catch { return }
            }
            while true {
                let remaining = end.timeIntervalSinceNow
                if remaining <= 0 { break }
                guard let self, !Task.isCancelled else { return }
                self.engine.setFadeFactor(SleepFade.gain(remaining: remaining, fadeDuration: fade))
                do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
            }
            guard let self, !Task.isCancelled else { return }
            playerLog.info("uyku zamanlayıcısı doldu")
            self.sleepTask = nil
            self.stop()
        }
    }

    /// `restoresVolume`: kısma çarpanını sıfırlar (çalarken zamanlayıcı iptali). `stop()` bunu kullanmaz:
    /// sönümleme zaten devam ediyorsa hacmin geri sıçramaması için.
    private func cancelSleepTimer(restoresVolume: Bool = true) {
        sleepTask?.cancel()
        sleepTask = nil
        sleepTimerEndsAt = nil
        if restoresVolume { engine.setFadeFactor(1) }
    }

    // MARK: Hata

    private func fail(_ message: String, error: Error) {
        playerLog.error("\(message, privacy: .public) \(error.localizedDescription, privacy: .public)")
        currentKind = nil
        isPlaying = false
        errorMessage = message
    }

    // MARK: Kesintiler ve yönlendirme

    private func handleConfigurationChange() {
        guard isPlaying, let kind = currentKind else { return }
        playerLog.info("motor yapılandırması değişti; yeniden başlatılıyor")
        restart(kind)
    }

    /// Motoru yeniden kurup sesi sürdürür (yapılandırma değişimi, medya servisleri sıfırlandı, kesinti sonu).
    private func restart(_ kind: FocusSoundKind) {
        do {
            try session.activate(mixWithOthers: mixesWithOtherAudio)
            try engine.rebuildAndRestart(kind: kind, volume: volume)
            isPlaying = true
            errorMessage = nil
        } catch {
            fail("Ses yeniden başlatılamadı. Lütfen tekrar dene.", error: error)
        }
    }

    private func pausePlayback(reason: String) {
        guard isPlaying else { return }
        playerLog.info("duraklatıldı: \(reason, privacy: .public)")
        isPlaying = false
        engine.stopNow()
    }

    func handleInterruption(began: Bool, shouldResume: Bool) {
        if began {
            pausePlayback(reason: "kesinti başladı")
            return
        }
        playerLog.info("kesinti bitti, devam: \(shouldResume, privacy: .public)")
        guard shouldResume, !isPlaying, let kind = currentKind else { return }
        restart(kind)
    }

    func handleOldDeviceUnavailable() {
        pausePlayback(reason: "çıkış cihazı çıkarıldı")
        session.deactivate()
    }

    func handleMediaServicesReset() {
        playerLog.info("medya servisleri sıfırlandı")
        guard isPlaying, let kind = currentKind else { return }
        restart(kind)
    }

    private func installObservers() {
        #if os(iOS)
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        let audioSession = AVAudioSession.sharedInstance()
        observers.add(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification, object: audioSession, queue: .main
            ) { [weak self] note in
                let typeRaw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
                MainActor.assumeIsolated {
                    let type = typeRaw.flatMap(AVAudioSession.InterruptionType.init(rawValue:))
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw ?? 0)
                    self?.handleInterruption(
                        began: type == .began, shouldResume: options.contains(.shouldResume))
                }
            })
        observers.add(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification, object: audioSession, queue: .main
            ) { [weak self] note in
                let reasonRaw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                MainActor.assumeIsolated {
                    let reason = reasonRaw.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
                    if reason == .oldDeviceUnavailable { self?.handleOldDeviceUnavailable() }
                }
            })
        observers.add(
            center.addObserver(
                forName: AVAudioSession.mediaServicesWereResetNotification, object: audioSession,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.handleMediaServicesReset() }
            })
        #endif
    }

    private func removeObservers() {
        observers.removeAll()
    }
}
