import AVFoundation
import Foundation
import os

private let engineLog = Logger(subsystem: "com.musabustun.fokus", category: "focus-sound")

/// `NotificationCenter` gözlemcilerini tutar; serbest kalınca (`deinit`) hepsini kaldırır.
/// `@unchecked Sendable`: yalnızca ana iş parçacığından kullanılır.
final class NotificationObservers: @unchecked Sendable {
    private var tokens: [NSObjectProtocol] = []

    var isEmpty: Bool { tokens.isEmpty }

    func add(_ token: NSObjectProtocol) { tokens.append(token) }

    func removeAll() {
        for token in tokens { NotificationCenter.default.removeObserver(token) }
        tokens.removeAll()
    }

    deinit { removeAll() }
}

/// Motor hatası (kullanıcı mesajı oynatıcıda Türkçe üretilir).
enum SoundEngineError: Error, Equatable {
    case outputFormatUnavailable
    case notRunning
}

/// `FocusSoundPlayer`'ın ses motoruna bağımlılığı; testlerde sahte uygulama verilir.
@MainActor
protocol SoundEngineDriving: AnyObject {
    /// Sistem motoru yeniden yapılandırdığında (çıkış cihazı/örnekleme hızı değişimi) çağrılır.
    var onConfigurationChange: (@MainActor () -> Void)? { get set }
    var isRunning: Bool { get }
    /// Motoru başlatır; çalıyorsa kısa bir kısma ile türü değiştirir. Fade-in uygular.
    func start(kind: FocusSoundKind, volume: Double) throws
    func setVolume(_ volume: Double)
    /// Uyku zamanlayıcısı kısma çarpanı (0…1).
    func setFadeFactor(_ factor: Double)
    /// Kısa fade-out sonra motoru durdurur. İptal edilirse (yeni `start`) durdurmaz.
    func fadeOutAndStop() async
    /// Hemen durdurur (kesinti, kulaklık çıkarma).
    func stopNow()
    /// Motoru sıfırdan kurup aynı türü yeniden başlatır (yapılandırma değişimi, medya servisleri sıfırlandı).
    func rebuildAndRestart(kind: FocusSoundKind, volume: Double) throws
}

/// `AVAudioEngine` + `AVAudioSourceNode` ile gerçek zamanlı sentez yapan motor.
@MainActor
final class SoundEngine: SoundEngineDriving {
    enum Mode: Equatable {
        /// Donanım çıkışı.
        case realtime
        /// Çevrimdışı manuel render (testler; donanım gerekmez).
        case offline(sampleRate: Double)
    }

    static let fadeInSeconds = 0.25
    static let switchFadeSeconds = 0.06
    static let stopFadeSeconds = 0.15
    static let volumeRampSeconds = 0.04

    var onConfigurationChange: (@MainActor () -> Void)?

    private let mode: Mode
    private var seedGenerator: SoundRandom
    private var engineStorage: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var gain: GainControl?
    private var kind: FocusSoundKind?
    private var volume = SoundMath.defaultVolume
    private var fadeFactor = 1.0
    private var transitionTask: Task<Void, Never>?
    private let observers = NotificationObservers()

    /// `seed`: verilirse sesler deterministik (testler); yoksa rastgele.
    init(mode: Mode = .realtime, seed: UInt64? = nil) {
        self.mode = mode
        seedGenerator = SoundRandom(seed: seed ?? UInt64.random(in: .min ... .max))
    }

    var isRunning: Bool { engineStorage?.isRunning ?? false }

    // MARK: Motor

    private var engine: AVAudioEngine {
        if let engineStorage { return engineStorage }
        let created = AVAudioEngine()
        if case .offline(let rate) = mode {
            let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
            do {
                try created.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4_096)
            } catch {
                engineLog.error("çevrimdışı kip açılamadı: \(error.localizedDescription, privacy: .public)")
            }
        }
        engineStorage = created
        observeConfigurationChange(of: created)
        return created
    }

    private func observeConfigurationChange(of engine: AVAudioEngine) {
        observers.removeAll()
        observers.add(
            NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.onConfigurationChange?() }
            })
    }

    private var sampleRate: Double {
        if case .offline(let rate) = mode { return rate }
        let rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        return rate > 0 ? rate : 48_000
    }

    // MARK: SoundEngineDriving

    func start(kind newKind: FocusSoundKind, volume newVolume: Double) throws {
        volume = SoundMath.clampedVolume(newVolume)
        transitionTask?.cancel()
        transitionTask = nil

        if engine.isRunning, sourceNode != nil, let gain {
            if kind == newKind {
                // Yalnızca (iptal edilmiş durdurma sonrası) yeniden yükselt.
                gain.set(target: currentTargetGain, rampSeconds: Self.fadeInSeconds)
                return
            }
            kind = newKind
            gain.set(target: 0, rampSeconds: Self.switchFadeSeconds)
            transitionTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(Int(Self.switchFadeSeconds * 1_000) + 30))
                guard !Task.isCancelled, let self else { return }
                self.installSource(kind: newKind)
            }
            return
        }

        installSource(kind: newKind)
        try startEngine()
        kind = newKind
        engineLog.info(
            "motor başladı: \(newKind.rawValue, privacy: .public), hacim \(self.volume, format: .fixed(precision: 2)), örnekleme \(self.sampleRate, format: .fixed(precision: 0)) Hz"
        )
    }

    func setVolume(_ newVolume: Double) {
        volume = SoundMath.clampedVolume(newVolume)
        applyGain(rampSeconds: Self.volumeRampSeconds)
    }

    func setFadeFactor(_ factor: Double) {
        fadeFactor = SoundMath.clampedVolume(factor)
        applyGain(rampSeconds: 0.1)
    }

    func fadeOutAndStop() async {
        guard isRunning else {
            teardown()
            return
        }
        transitionTask?.cancel()
        transitionTask = nil
        gain?.set(target: 0, rampSeconds: Self.stopFadeSeconds)
        try? await Task.sleep(for: .milliseconds(Int(Self.stopFadeSeconds * 1_000) + 30))
        guard !Task.isCancelled else { return }
        teardown()
    }

    func stopNow() {
        transitionTask?.cancel()
        transitionTask = nil
        teardown()
    }

    func rebuildAndRestart(kind newKind: FocusSoundKind, volume newVolume: Double) throws {
        transitionTask?.cancel()
        transitionTask = nil
        discardEngine()
        try start(kind: newKind, volume: newVolume)
    }

    // MARK: İç

    private var currentTargetGain: Double {
        SoundGainMath.targetGain(volume: volume, fadeFactor: fadeFactor)
    }

    private func applyGain(rampSeconds: Double) {
        gain?.set(target: kind == nil ? 0 : currentTargetGain, rampSeconds: rampSeconds)
    }

    private func nextSeed() -> UInt64 { seedGenerator.nextUInt64() }

    /// Yeni üreteç + kaynak düğümü kurar, eskisini söker. Motor çalışıyorken de güvenle çağrılabilir.
    private func installSource(kind newKind: FocusSoundKind) {
        let rate = sampleRate
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else { return }
        let synth = SoundSynthFactory.make(kind: newKind, sampleRate: rate, seed: nextSeed())
        let control = GainControl(initial: 0, target: Float(currentTargetGain), rampSeconds: Float(Self.fadeInSeconds))
        let node = AVAudioSourceNode(
            format: format,
            renderBlock: makeSoundRenderBlock(synth: synth, gain: control, sampleRate: rate))
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        if let old = sourceNode {
            engine.disconnectNodeOutput(old)
            engine.detach(old)
        }
        sourceNode = node
        gain = control
        kind = newKind
    }

    private func startEngine() throws {
        let engine = engine
        engine.prepare()
        try engine.start()
    }

    private func teardown() {
        if let engineStorage {
            if engineStorage.isRunning { engineStorage.stop() }
            if let node = sourceNode {
                engineStorage.disconnectNodeOutput(node)
                engineStorage.detach(node)
            }
        }
        sourceNode = nil
        gain = nil
        kind = nil
    }

    private func discardEngine() {
        teardown()
        observers.removeAll()
        engineStorage = nil
    }

    // MARK: Test yardımcıları

    /// Süren tür geçişi (kısma + kaynak değişimi) bitene kadar bekler.
    func waitForTransition() async {
        await transitionTask?.value
    }

    // MARK: Çevrimdışı render (testler)

    /// Çevrimdışı kipte `seconds` saniyeyi render eder; kanal başına örnekleri döndürür.
    func renderOffline(seconds: Double) throws -> (left: [Float], right: [Float]) {
        guard case .offline(let rate) = mode, engine.isRunning else { throw SoundEngineError.notRunning }
        let engine = engine
        let total = Int(seconds * rate)
        let chunk = 4_096
        guard
            let buffer = AVAudioPCMBuffer(
                pcmFormat: engine.manualRenderingFormat, frameCapacity: AVAudioFrameCount(chunk))
        else { throw SoundEngineError.outputFormatUnavailable }
        var left: [Float] = []
        var right: [Float] = []
        left.reserveCapacity(total)
        right.reserveCapacity(total)
        var rendered = 0
        while rendered < total {
            let frames = min(chunk, total - rendered)
            let status = try engine.renderOffline(AVAudioFrameCount(frames), to: buffer)
            guard status == .success, let channels = buffer.floatChannelData else {
                throw SoundEngineError.notRunning
            }
            let n = Int(buffer.frameLength)
            left.append(contentsOf: UnsafeBufferPointer(start: channels[0], count: n))
            right.append(contentsOf: UnsafeBufferPointer(start: channels[1], count: n))
            rendered += max(n, 1)
        }
        return (left, right)
    }
}

/// Render bloğunu `nonisolated` bir bağlamda üretir. ÖNEMLİ: blok `@MainActor` bir yöntemin içinde
/// yazılsaydı Swift onu ana aktöre bağlardı ve ses iş parçacığında çağrılınca çökerdi.
/// Blok gerçek zamanlı güvenlidir: yalnızca önceden ayrılmış durumla aritmetik yapar.
private func makeSoundRenderBlock(
    synth: any SoundSynthesizing, gain: GainControl, sampleRate: Double
) -> AVAudioSourceNodeRenderBlock {
    { isSilence, _, frameCount, audioBufferList in
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        isSilence.pointee = false
        guard buffers.count >= 2,
            let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
            let right = buffers[1].mData?.assumingMemoryBound(to: Float.self)
        else {
            for buffer in buffers {
                if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
            }
            return noErr
        }
        let frames = Int(frameCount)
        synth.render(left: left, right: right, frameCount: frames)
        gain.apply(left: left, right: right, frameCount: frames, sampleRate: sampleRate)
        return noErr
    }
}
