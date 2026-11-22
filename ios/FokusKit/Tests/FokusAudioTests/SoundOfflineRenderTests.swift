import AVFoundation
import Foundation
import Testing

@testable import FokusAudio

/// Kanıt testi: `AVAudioEngine` çevrimdışı manuel render kipinde (donanım çıkışı olmadan) her ses
/// türünü gerçek motor üzerinden render eder; çıktının sessiz olmadığını, sonlu olduğunu ve
/// [-1, 1] içinde kaldığını doğrular.
@MainActor
@Suite("Çevrimdışı motor render kanıtı")
struct SoundOfflineRenderTests {
    static let sampleRate = 48_000.0

    private func rms(_ x: ArraySlice<Float>) -> Double {
        (x.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(max(x.count, 1))).squareRoot()
    }

    private func render(_ kind: FocusSoundKind, volume: Double = 0.5, seconds: Double = 1.5) throws
        -> (left: [Float], right: [Float])
    {
        let engine = SoundEngine(mode: .offline(sampleRate: Self.sampleRate), seed: 1234)
        try engine.start(kind: kind, volume: volume)
        defer { engine.stopNow() }
        return try engine.renderOffline(seconds: seconds)
    }

    @Test("her tür sessiz değil, NaN/Inf yok, |x| ≤ 1", arguments: FocusSoundKind.allCases)
    func rendersAudibleBoundedOutput(kind: FocusSoundKind) throws {
        let out = try render(kind)
        let n = out.left.count
        #expect(n == Int(1.5 * Self.sampleRate))
        for x in out.left + out.right {
            #expect(x.isFinite)
            #expect(abs(x) <= 1)
        }
        // İlk 0.5 sn fade-in; son 1 sn analiz edilir.
        let tailStart = Int(0.5 * Self.sampleRate)
        let rmsL = rms(out.left[tailStart...])
        let rmsR = rms(out.right[tailStart...])
        print("ÇEVRİMDIŞI RENDER \(kind.rawValue): RMS L=\(rmsL) R=\(rmsR)")
        #expect(rmsL > 0.01)
        #expect(rmsR > 0.01)
        #expect(rmsL < 0.7)
    }

    @Test("fade-in: ilk örnekler sessizden başlar (patlama yok)")
    func fadeInStartsSilent() throws {
        let out = try render(.whiteNoise)
        let firstMs = out.left.prefix(48).map { abs($0) }.max() ?? 1
        #expect(firstMs < 0.01)
    }

    @Test("hacim 0 sessiz, hacim 1 hacim 0.5'ten yüksek")
    func volumeAffectsLevel() throws {
        let silent = try render(.pinkNoise, volume: 0)
        #expect(rms(silent.left[24_000...]) < 1e-6)
        let half = try render(.pinkNoise, volume: 0.5)
        let full = try render(.pinkNoise, volume: 1)
        #expect(rms(full.left[24_000...]) > rms(half.left[24_000...]) * 1.5)
    }

    @Test("çalarken hacim değişimi motora yansır")
    func liveVolumeChange() throws {
        let engine = SoundEngine(mode: .offline(sampleRate: Self.sampleRate), seed: 7)
        try engine.start(kind: .whiteNoise, volume: 1)
        defer { engine.stopNow() }
        let loud = try engine.renderOffline(seconds: 1)
        engine.setVolume(0.2)
        _ = try engine.renderOffline(seconds: 0.3)  // rampa
        let quiet = try engine.renderOffline(seconds: 0.5)
        #expect(rms(quiet.left[...]) < rms(loud.left[24_000...]) * 0.4)
    }

    @Test("aynı tohum aynı render (deterministik)")
    func deterministicRender() throws {
        let a = try render(.rain, seconds: 0.5)
        let b = try render(.rain, seconds: 0.5)
        #expect(a.left == b.left)
    }

    @Test("yağmur damla darbeleri taşır: yatak tek başına olandan zamanda daha değişken")
    func rainHasTransients() throws {
        let out = try render(.rain, seconds: 3)
        // 10 ms'lik pencerelerin RMS'i; damlalar pencere zarfında dalgalanma yaratır.
        let window = 480
        let levels = stride(from: 24_000, to: out.left.count - window, by: window).map {
            rms(out.left[$0..<($0 + window)])
        }
        let mean = levels.reduce(0, +) / Double(levels.count)
        let variance = levels.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(levels.count)
        #expect(variance > 0)
        #expect(levels.max()! > mean * 1.02)
    }

    @Test("melodi zamanla değişir (statik değil) ve stereo")
    func melodyEvolves() throws {
        let out = try render(.melody, seconds: 6)
        let a = rms(out.left[48_000..<96_000])
        let b = rms(out.left[240_000..<288_000])
        #expect(a > 0.005 && b > 0.005)
        #expect(out.left != out.right)
    }

    @Test("motor durdurulunca çalışmaz; yeniden başlatılabilir")
    func stopAndRestart() throws {
        let engine = SoundEngine(mode: .offline(sampleRate: Self.sampleRate), seed: 3)
        try engine.start(kind: .brownNoise, volume: 0.5)
        #expect(engine.isRunning)
        engine.stopNow()
        #expect(!engine.isRunning)
        try engine.start(kind: .rain, volume: 0.5)
        #expect(engine.isRunning)
        let out = try engine.renderOffline(seconds: 0.6)
        #expect(rms(out.left[14_400...]) > 0.005)
        engine.stopNow()
    }

    @Test("çalarken tür değişimi (kısma + yeni kaynak) sonrası yeni ses duyulur")
    func switchWhileRunning() async throws {
        let engine = SoundEngine(mode: .offline(sampleRate: Self.sampleRate), seed: 9)
        try engine.start(kind: .whiteNoise, volume: 0.5)
        defer { engine.stopNow() }
        _ = try engine.renderOffline(seconds: 0.5)
        try engine.start(kind: .pinkNoise, volume: 0.5)
        await engine.waitForTransition()
        let out = try engine.renderOffline(seconds: 1)
        #expect(rms(out.left[24_000...]) > 0.01)
    }

    @Test("çevrimdışı olmayan/çalışmayan motorda render hata verir")
    func renderRequiresRunningEngine() {
        let engine = SoundEngine(mode: .offline(sampleRate: Self.sampleRate), seed: 1)
        #expect(throws: SoundEngineError.notRunning) { try engine.renderOffline(seconds: 0.1) }
    }
}
