import Foundation
import Testing

@testable import FokusAudio

@MainActor
private final class FakeEngine: SoundEngineDriving {
    struct Failure: Error {}
    var onConfigurationChange: (@MainActor () -> Void)?
    var isRunning = false
    var startError: Error?
    private(set) var started: [(kind: FocusSoundKind, volume: Double)] = []
    private(set) var volumes: [Double] = []
    private(set) var fadeFactors: [Double] = []
    private(set) var fadeOutCount = 0
    private(set) var stopNowCount = 0
    private(set) var rebuildCount = 0

    func start(kind: FocusSoundKind, volume: Double) throws {
        if let startError { throw startError }
        started.append((kind, volume))
        isRunning = true
    }
    func setVolume(_ volume: Double) { volumes.append(volume) }
    func setFadeFactor(_ factor: Double) { fadeFactors.append(factor) }
    func fadeOutAndStop() async {
        fadeOutCount += 1
        isRunning = false
    }
    func stopNow() {
        stopNowCount += 1
        isRunning = false
    }
    func rebuildAndRestart(kind: FocusSoundKind, volume: Double) throws {
        if let startError { throw startError }
        rebuildCount += 1
        started.append((kind, volume))
        isRunning = true
    }
}

@MainActor
private final class FakeSession: SoundSessionControlling {
    struct Failure: Error {}
    var activateError: Error?
    private(set) var activations: [Bool] = []
    private(set) var deactivations = 0

    func activate(mixWithOthers: Bool) throws {
        if let activateError { throw activateError }
        activations.append(mixWithOthers)
    }
    func deactivate() { deactivations += 1 }
}

@MainActor
private struct Fixture {
    let suite: String
    let defaults: UserDefaults
    let engine = FakeEngine()
    let session = FakeSession()
    let player: FocusSoundPlayer

    init(fadeDuration: TimeInterval = 0.1, prepare: (UserDefaults) -> Void = { _ in }) {
        suite = "FocusSoundPlayerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        prepare(defaults)
        player = FocusSoundPlayer(
            defaults: defaults, engine: engine, session: session, sleepFadeDuration: fadeDuration)
    }

    func cleanUp() { defaults.removePersistentDomain(forName: suite) }
}

@MainActor
@Suite("FocusSoundPlayer")
struct FocusSoundPlayerTests {
    /// Zamanlayıcı testleri ana aktörü paylaşan ağır render testleriyle yarışabilir; sabit bekleme yerine yoklama.
    private func waitUntil(timeout: Duration = .seconds(60), _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test("başlangıç durumu: kapalı, hacim 0.5, karıştırma açık")
    func initialState() {
        let f = Fixture()
        defer { f.cleanUp() }
        #expect(f.player.currentKind == nil)
        #expect(!f.player.isPlaying)
        #expect(f.player.volume == 0.5)
        #expect(f.player.mixesWithOtherAudio)
        #expect(f.player.sleepTimerEndsAt == nil)
        #expect(f.player.errorMessage == nil)
    }

    @Test("parametresiz init çalışır")
    func parameterlessInit() {
        let player = FocusSoundPlayer()
        #expect(player.currentKind == nil)
        #expect(!player.isPlaying)
    }

    @Test("play: oturum etkinleşir, motor başlar, durum güncellenir", arguments: FocusSoundKind.allCases)
    func play(kind: FocusSoundKind) {
        let f = Fixture()
        defer { f.cleanUp() }
        f.player.play(kind)
        #expect(f.player.currentKind == kind)
        #expect(f.player.isPlaying)
        #expect(f.session.activations == [true])
        #expect(f.engine.started.map(\.kind) == [kind])
        #expect(f.engine.started.first?.volume == 0.5)
    }

    @Test("çalarken başka türe geçmek türü değiştirir")
    func switchKind() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.player.play(.rain)
        f.player.play(.melody)
        #expect(f.player.currentKind == .melody)
        #expect(f.player.isPlaying)
        #expect(f.engine.started.map(\.kind) == [.rain, .melody])
    }

    @Test("stop: durum sıfırlanır, fade-out ve oturum bırakma çalışır")
    func stop() async throws {
        let f = Fixture()
        defer { f.cleanUp() }
        f.player.play(.pinkNoise)
        f.player.stop()
        #expect(f.player.currentKind == nil)
        #expect(!f.player.isPlaying)
        try await Task.sleep(for: .milliseconds(60))
        #expect(f.engine.fadeOutCount == 1)
        #expect(f.session.deactivations == 1)
    }

    @Test("stop sonra yeniden play çalışır")
    func replayAfterStop() async throws {
        let f = Fixture()
        defer { f.cleanUp() }
        f.player.play(.whiteNoise)
        f.player.stop()
        f.player.play(.brownNoise)
        #expect(f.player.currentKind == .brownNoise)
        #expect(f.player.isPlaying)
        try await Task.sleep(for: .milliseconds(60))
        // İptal edilen durdurma oturumu bırakmamalı.
        #expect(f.session.deactivations == 0)
    }

    @Test("çalmıyorken stop zararsız (motor/oturum çağrılmaz)")
    func stopWhenIdle() async throws {
        let f = Fixture()
        defer { f.cleanUp() }
        f.player.stop()
        try await Task.sleep(for: .milliseconds(30))
        #expect(f.engine.fadeOutCount == 0)
        #expect(f.session.deactivations == 0)
    }

    @Test("hacim 0…1'e kırpılır, kalıcıdır ve motora iletilir")
    func volumePersistence() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.player.volume = 1.7
        #expect(f.player.volume == 1)
        f.player.volume = -3
        #expect(f.player.volume == 0)
        f.player.volume = 0.8
        #expect(f.defaults.double(forKey: FocusSoundPlayer.volumeDefaultsKey) == 0.8)
        #expect(f.engine.volumes.last == 0.8)

        let reloaded = FocusSoundPlayer(
            defaults: f.defaults, engine: FakeEngine(), session: FakeSession(), sleepFadeDuration: 5)
        #expect(reloaded.volume == 0.8)
    }

    @Test("karıştırma tercihi kalıcıdır; çalarken oturum yeniden yapılandırılır")
    func mixPersistence() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.player.play(.rain)
        f.player.mixesWithOtherAudio = false
        #expect(f.session.activations == [true, false])
        #expect(f.defaults.object(forKey: FocusSoundPlayer.mixDefaultsKey) as? Bool == false)

        let reloaded = FocusSoundPlayer(
            defaults: f.defaults, engine: FakeEngine(), session: FakeSession(), sleepFadeDuration: 5)
        #expect(!reloaded.mixesWithOtherAudio)
    }

    @Test("karıştırma kapalıyken oturum seçeneksiz etkinleşir")
    func playWithoutMixing() {
        let f = Fixture { $0.set(false, forKey: FocusSoundPlayer.mixDefaultsKey) }
        defer { f.cleanUp() }
        f.player.play(.rain)
        #expect(f.session.activations == [false])
    }

    @Test("kayıtlı hacim başlangıçta okunur ve kırpılır")
    func storedVolumeClamped() {
        let f = Fixture { $0.set(9.0, forKey: FocusSoundPlayer.volumeDefaultsKey) }
        defer { f.cleanUp() }
        #expect(f.player.volume == 1)
    }

    @Test("oturum açılamazsa Türkçe hata, çalma yok")
    func sessionFailure() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.session.activateError = FakeSession.Failure()
        f.player.play(.rain)
        #expect(!f.player.isPlaying)
        #expect(f.player.currentKind == nil)
        #expect(f.player.errorMessage?.contains("Ses oturumu") == true)
        #expect(f.engine.started.isEmpty)
    }

    @Test("motor başlamazsa Türkçe hata; sonraki başarılı play hatayı temizler")
    func engineFailureThenRecovery() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.engine.startError = FakeEngine.Failure()
        f.player.play(.melody)
        #expect(!f.player.isPlaying)
        #expect(f.player.errorMessage != nil)
        #expect(f.session.deactivations == 1)
        f.engine.startError = nil
        f.player.play(.melody)
        #expect(f.player.isPlaying)
        #expect(f.player.errorMessage == nil)
    }

    // MARK: Uyku zamanlayıcısı

    @Test("dakika cinsinden zamanlayıcı bitiş anını yayınlar; nil iptal eder")
    func sleepTimerPublishAndCancel() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.player.play(.rain)
        let before = Date()
        f.player.setSleepTimer(minutes: 30)
        let ends = f.player.sleepTimerEndsAt ?? .distantPast
        #expect(abs(ends.timeIntervalSince(before) - 1_800) < 2)
        f.player.setSleepTimer(minutes: nil)
        #expect(f.player.sleepTimerEndsAt == nil)
        #expect(f.engine.fadeFactors.last == 1)
        #expect(f.player.isPlaying)
    }

    @Test("zamanlayıcı yeniden kurulunca öncekinin yerine geçer")
    func sleepTimerReplace() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.player.play(.rain)
        f.player.setSleepTimer(minutes: 15)
        let first = f.player.sleepTimerEndsAt
        f.player.setSleepTimer(minutes: 60)
        #expect((f.player.sleepTimerEndsAt ?? .distantPast) > (first ?? .distantFuture))
    }

    @Test("stop zamanlayıcıyı iptal eder")
    func stopCancelsTimer() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.player.play(.rain)
        f.player.setSleepTimer(minutes: 45)
        f.player.stop()
        #expect(f.player.sleepTimerEndsAt == nil)
    }

    @Test("zamanlayıcı dolunca son saniyelerde kısar, sonra durdurur")
    func sleepTimerExpires() async throws {
        let f = Fixture(fadeDuration: 0.2)
        defer { f.cleanUp() }
        f.player.play(.pinkNoise)
        f.player.setSleepTimer(seconds: 0.5)
        try await waitUntil { f.engine.fadeOutCount == 1 }
        #expect(!f.player.isPlaying)
        #expect(f.player.currentKind == nil)
        #expect(f.player.sleepTimerEndsAt == nil)
        #expect(f.engine.fadeOutCount == 1)
        // Uygulanan kısma çarpanları (ana aktör yoğunsa hiç olmayabilir) azalan sırada ve [0,1] içinde olmalı.
        let fades = f.engine.fadeFactors.filter { $0 < 1 }
        #expect(fades == fades.sorted(by: >))
        #expect(fades.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    @Test("sıfır/negatif dakika zamanlayıcı kurmaz", arguments: [0, -5])
    func sleepTimerNonPositive(minutes: Int) {
        let f = Fixture()
        defer { f.cleanUp() }
        f.player.setSleepTimer(minutes: minutes)
        #expect(f.player.sleepTimerEndsAt == nil)
    }

    // MARK: Kesinti ve yönlendirme

    @Test("kesinti başlayınca isPlaying=false ama tür kalır; shouldResume ile yeniden başlar")
    func interruptionResume() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.player.play(.melody)
        f.player.handleInterruption(began: true, shouldResume: false)
        #expect(!f.player.isPlaying)
        #expect(f.player.currentKind == .melody)
        f.player.handleInterruption(began: false, shouldResume: true)
        #expect(f.player.isPlaying)
        #expect(f.engine.rebuildCount == 1)
        #expect(f.engine.started.last?.kind == .melody)
    }

    @Test("kesinti bitince shouldResume yoksa duraklamış kalır")
    func interruptionNoResume() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.player.play(.rain)
        f.player.handleInterruption(began: true, shouldResume: false)
        f.player.handleInterruption(began: false, shouldResume: false)
        #expect(!f.player.isPlaying)
        #expect(f.player.currentKind == .rain)
        #expect(f.engine.rebuildCount == 0)
    }

    @Test("kulaklık çıkarılınca duraklar ve otomatik sürdürmez")
    func routeOldDeviceUnavailable() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.player.play(.brownNoise)
        f.player.handleOldDeviceUnavailable()
        #expect(!f.player.isPlaying)
        #expect(f.player.currentKind == .brownNoise)
        #expect(f.engine.stopNowCount == 1)
        #expect(f.session.deactivations == 1)
        f.player.handleInterruption(began: false, shouldResume: false)
        #expect(!f.player.isPlaying)
    }

    @Test("medya servisleri sıfırlanınca motor yeniden kurulur")
    func mediaServicesReset() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.player.play(.whiteNoise)
        f.player.handleMediaServicesReset()
        #expect(f.engine.rebuildCount == 1)
        #expect(f.player.isPlaying)
    }

    @Test("motor yapılandırması değişince çalıyorsa yeniden başlar; çalmıyorsa dokunmaz")
    func configurationChange() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.engine.onConfigurationChange?()
        #expect(f.engine.rebuildCount == 0)
        f.player.play(.rain)
        f.engine.onConfigurationChange?()
        #expect(f.engine.rebuildCount == 1)
        #expect(f.player.isPlaying)
    }

    @Test("yeniden başlatma hatası Türkçe mesaj verir")
    func restartFailure() {
        let f = Fixture()
        defer { f.cleanUp() }
        f.player.play(.rain)
        f.engine.startError = FakeEngine.Failure()
        f.engine.onConfigurationChange?()
        #expect(!f.player.isPlaying)
        #expect(f.player.errorMessage?.contains("yeniden") == true)
    }
}

@Suite("FocusSoundKind meta")
struct FocusSoundKindTests {
    @Test("her tür Türkçe başlık, alt metin ve sembol taşır", arguments: FocusSoundKind.allCases)
    func metadata(kind: FocusSoundKind) {
        #expect(!kind.title.isEmpty)
        #expect(!kind.subtitle.isEmpty)
        #expect(!kind.symbolName.isEmpty)
        #expect(kind.id == kind.rawValue)
    }
}
