import Foundation
import Testing

@testable import FokusAudio

private let sampleRate = 48_000.0

private func rms(_ x: [Float]) -> Double {
    guard !x.isEmpty else { return 0 }
    return (x.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(x.count)).squareRoot()
}

@Suite("SoundRandom")
struct SoundRandomTests {
    @Test("aynı tohum aynı diziyi üretir", arguments: [UInt64(0), 1, 42, 0xDEAD_BEEF, .max])
    func deterministic(seed: UInt64) {
        var a = SoundRandom(seed: seed)
        var b = SoundRandom(seed: seed)
        for _ in 0..<64 { #expect(a.nextUInt64() == b.nextUInt64()) }
    }

    @Test("farklı tohum farklı dizi üretir")
    func differentSeeds() {
        var a = SoundRandom(seed: 1)
        var b = SoundRandom(seed: 2)
        let sa = (0..<16).map { _ in a.nextUInt64() }
        let sb = (0..<16).map { _ in b.nextUInt64() }
        #expect(sa != sb)
    }

    @Test("birim ve çift kutuplu aralıklar")
    func ranges() {
        var r = SoundRandom(seed: 7)
        var sum = 0.0
        for _ in 0..<20_000 {
            let u = r.nextUnit()
            let d = r.nextUnitDouble()
            let b = r.nextBipolar()
            let c = r.next(in: 2...3)
            #expect(u >= 0 && u < 1)
            #expect(d >= 0 && d < 1)
            #expect(b >= -1 && b < 1)
            #expect(c >= 2 && c <= 3)
            sum += Double(b)
        }
        #expect(abs(sum / 20_000) < 0.02)
    }
}

@Suite("Biquad")
struct BiquadTests {
    @Test("Butterworth alçak geçiren fs/4 bilinen katsayılar")
    func lowpassKnownValues() {
        let c = BiquadCoefficients.lowpass(cutoff: sampleRate / 4, q: 1 / 2.0.squareRoot(), sampleRate: sampleRate)
        #expect(abs(c.b0 - 0.292_893) < 1e-4)
        #expect(abs(c.b1 - 0.585_786) < 1e-4)
        #expect(abs(c.b2 - 0.292_893) < 1e-4)
        #expect(abs(c.a1) < 1e-5)
        #expect(abs(c.a2 - 0.171_573) < 1e-4)
    }

    @Test("yüksek geçiren fs/4 bilinen katsayılar")
    func highpassKnownValues() {
        let c = BiquadCoefficients.highpass(cutoff: sampleRate / 4, q: 1 / 2.0.squareRoot(), sampleRate: sampleRate)
        #expect(abs(c.b0 - 0.292_893) < 1e-4)
        #expect(abs(c.b1 + 0.585_786) < 1e-4)
        #expect(abs(c.b2 - 0.292_893) < 1e-4)
        #expect(abs(c.a2 - 0.171_573) < 1e-4)
    }

    @Test("kesim frekansında Butterworth −3 dB; alçak geçiren DC'de 1, yüksekte ≈ 0")
    func lowpassResponse() {
        let c = BiquadCoefficients.lowpass(cutoff: 1_000, q: 1 / 2.0.squareRoot(), sampleRate: sampleRate)
        #expect(abs(c.magnitude(at: 1, sampleRate: sampleRate) - 1) < 0.01)
        #expect(abs(c.magnitude(at: 1_000, sampleRate: sampleRate) - 0.7071) < 0.01)
        #expect(c.magnitude(at: 20_000, sampleRate: sampleRate) < 0.01)
    }

    @Test("yüksek geçiren DC'de ≈ 0, yüksekte 1")
    func highpassResponse() {
        let c = BiquadCoefficients.highpass(cutoff: 1_000, q: 1 / 2.0.squareRoot(), sampleRate: sampleRate)
        #expect(c.magnitude(at: 10, sampleRate: sampleRate) < 0.001)
        #expect(abs(c.magnitude(at: 20_000, sampleRate: sampleRate) - 1) < 0.02)
    }

    @Test("bant geçiren merkezde 0 dB, uçlarda zayıf")
    func bandpassResponse() {
        let c = BiquadCoefficients.bandpass(center: 3_000, q: 2, sampleRate: sampleRate)
        #expect(abs(c.magnitude(at: 3_000, sampleRate: sampleRate) - 1) < 0.01)
        #expect(c.magnitude(at: 100, sampleRate: sampleRate) < 0.1)
        #expect(c.magnitude(at: 23_000, sampleRate: sampleRate) < 0.2)
    }

    @Test("geçersiz kesim frekansı kırpılır (NaN/Inf üretmez)", arguments: [0.0, -5, 1e9])
    func cutoffClamped(cutoff: Double) {
        let c = BiquadCoefficients.lowpass(cutoff: cutoff, q: 0.7, sampleRate: sampleRate)
        for v in [c.b0, c.b1, c.b2, c.a1, c.a2] { #expect(v.isFinite) }
    }

    @Test("filtre çalıştırılınca kararlı: dürtü yanıtı sönümlenir")
    func impulseDecays() {
        var f = Biquad(.lowpass(cutoff: 500, q: 0.9, sampleRate: sampleRate))
        var last: Float = f.process(1)
        for _ in 0..<20_000 { last = f.process(0) }
        #expect(abs(last) < 1e-6)
    }

    @Test("passthrough girişi aynen verir")
    func passthrough() {
        var f = Biquad(.passthrough)
        for x: Float in [0.1, -0.7, 0.3] { #expect(f.process(x) == x) }
    }
}

@Suite("Gürültü üreteçleri")
struct NoiseStatisticsTests {
    private func white(_ n: Int, seed: UInt64 = 1) -> [Float] {
        var r = SoundRandom(seed: seed)
        return (0..<n).map { _ in r.nextBipolar() }
    }

    private func bandEnergies(_ x: [Float]) -> (low: Double, high: Double) {
        var lp = Biquad(.lowpass(cutoff: 200, q: 0.7071, sampleRate: sampleRate))
        var hp = Biquad(.highpass(cutoff: 4_000, q: 0.7071, sampleRate: sampleRate))
        let low = x.map { lp.process($0) }
        let high = x.map { hp.process($0) }
        return (rms(low), rms(high))
    }

    @Test("beyaz gürültü: ortalama ≈ 0, sınırlı, RMS ≈ 1/√3")
    func whiteStats() {
        let x = white(200_000)
        let mean = x.reduce(0.0) { $0 + Double($1) } / Double(x.count)
        #expect(abs(mean) < 0.01)
        #expect(x.allSatisfy { $0 >= -1 && $0 < 1 })
        #expect(abs(rms(x) - (1 / 3.0.squareRoot())) < 0.01)
    }

    @Test("pembe gürültü: düşük bant enerjisi > yüksek bant enerjisi; beyazdan daha eğimli")
    func pinkSlope() {
        var pink = PinkNoiseFilter()
        let p = white(200_000).map { pink.process($0) }
        let e = bandEnergies(p)
        #expect(e.low > e.high * 1.3)
        let w = bandEnergies(white(200_000))
        // Beyazda 200 Hz altı bant (≈ 0.4 oktav genişlik oranı) 4 kHz üstünden çok daha dar → düşük < yüksek.
        #expect(e.low / e.high > w.low / w.high * 10)
        #expect(p.allSatisfy { $0.isFinite })
    }

    @Test("kahverengi gürültü: |y| ≤ 1, pembeden daha eğimli, sonlu")
    func brownStats() {
        var brown = BrownNoiseIntegrator()
        var pink = PinkNoiseFilter()
        let src = white(200_000)
        let b = src.map { brown.process($0) }
        let p = src.map { pink.process($0) }
        #expect(b.allSatisfy { abs($0) <= 1 && $0.isFinite })
        let eb = bandEnergies(b)
        let ep = bandEnergies(p)
        #expect(eb.low > eb.high * 3)
        #expect(eb.low / eb.high > ep.low / ep.high)
    }

    @Test("üreteç çıktıları hep [-1, 1] içinde, sessiz değil", arguments: [
        NoiseSynth.Color.white, .pink, .brown,
    ])
    func synthOutputBounded(color: NoiseSynth.Color) {
        let synth = NoiseSynth(color: color, seed: 99)
        let n = 48_000
        var l = [Float](repeating: 0, count: n)
        var r = [Float](repeating: 0, count: n)
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                synth.render(left: lp.baseAddress!, right: rp.baseAddress!, frameCount: n)
            }
        }
        for x in l + r { #expect(x.isFinite && abs(x) <= 1) }
        #expect(rms(l) > 0.05)
        #expect(rms(l) < 0.5)
        // Kanallar bağımsız: aynı olmamalı.
        #expect(l != r)
    }

    @Test("aynı tohumlu üreteçler aynı çıktıyı verir")
    func synthDeterministic() {
        func run() -> [Float] {
            let synth = NoiseSynth(color: .pink, seed: 5)
            var l = [Float](repeating: 0, count: 256)
            var r = [Float](repeating: 0, count: 256)
            l.withUnsafeMutableBufferPointer { lp in
                r.withUnsafeMutableBufferPointer { rp in
                    synth.render(left: lp.baseAddress!, right: rp.baseAddress!, frameCount: 256)
                }
            }
            return l
        }
        #expect(run() == run())
    }
}

@Suite("Yağmur damlası zamanlayıcısı")
struct DropSchedulerTests {
    @Test("aralıklar ≥ 0 ve sonlu; ortalama ≈ 1/oran", arguments: [4.0, 12.0, 20.0, 50.0])
    func intervals(rate: Double) {
        var s = DropScheduler(ratePerSecond: rate, seed: 2024)
        let n = 40_000
        var sum = 0.0
        for _ in 0..<n {
            let t = s.nextInterval()
            #expect(t >= 0 && t.isFinite)
            sum += t
        }
        let mean = sum / Double(n)
        #expect(abs(mean - 1 / rate) / (1 / rate) < 0.05)
    }

    @Test("aynı tohum aynı aralıklar")
    func deterministic() {
        var a = DropScheduler(ratePerSecond: 10, seed: 3)
        var b = DropScheduler(ratePerSecond: 10, seed: 3)
        for _ in 0..<50 { #expect(a.nextInterval() == b.nextInterval()) }
    }

    @Test("sıfır/negatif oran sonlu kalır")
    func degenerateRate() {
        var s = DropScheduler(ratePerSecond: 0, seed: 1)
        #expect(s.nextInterval().isFinite)
    }
}

@Suite("Nota eşleme ve pentatonik skala")
struct NoteMappingTests {
    @Test(
        "MIDI → Hz",
        arguments: [
            (69.0, 440.0), (81.0, 880.0), (57.0, 220.0), (60.0, 261.6256), (45.0, 110.0),
        ])
    func midiToHz(note: Double, hz: Double) {
        #expect(abs(SoundMath.midiToHz(note) - hz) < 0.001)
    }

    @Test("cent oranı: 1200 cent = oktav, 0 = 1")
    func cents() {
        #expect(abs(SoundMath.centsToRatio(1200) - 2) < 1e-9)
        #expect(SoundMath.centsToRatio(0) == 1)
        #expect(SoundMath.centsToRatio(5) > 1)
    }

    @Test("skala: tüm notalar A minör pentatonik içinde, artan sırada")
    func scaleMembership() {
        var previous = -1
        for i in 0..<PentatonicScale.noteCount {
            let m = PentatonicScale.midi(at: i)
            #expect(PentatonicScale.contains(midi: m))
            #expect(m > previous)
            previous = m
        }
        #expect(PentatonicScale.midi(at: 0) == 57)
        #expect(PentatonicScale.midi(at: PentatonicScale.noteCount - 1) == 81)
        #expect(!PentatonicScale.contains(midi: 58))
        #expect(!PentatonicScale.contains(midi: 59))
    }

    @Test("indeks sınırları kırpılır", arguments: [-5, 0, 10, 11, 999])
    func indexClamped(index: Int) {
        let m = PentatonicScale.midi(at: index)
        #expect(m >= 57 && m <= 81)
    }

    @Test("nota seçici: skalada kalır, hep geçerli süreler, deterministik")
    func picker() {
        var a = MelodyNotePicker(seed: 11)
        var b = MelodyNotePicker(seed: 11)
        var seen = Set<Int>()
        for _ in 0..<500 {
            let n = a.next()
            #expect(n == b.next())
            #expect(PentatonicScale.contains(midi: n.midi))
            #expect((0..<PentatonicScale.noteCount).contains(n.index))
            #expect(n.frequency > 200 && n.frequency < 900)
            #expect(n.gapToNext >= 2.2 && n.gapToNext <= 4.8)
            #expect(n.attack >= 1.6 && n.hold >= 0.5 && n.release >= 3.0)
            seen.insert(n.index)
        }
        #expect(seen.count >= 6)
    }
}

@Suite("Pad zarfı")
struct PadEnvelopeTests {
    @Test("sıfırdan 1'e çıkar, tutar, 0'a iner; değerler [0,1]")
    func shape() {
        var env = PadEnvelope(attackSamples: 100, holdSamples: 50, releaseSamples: 100)
        var values: [Float] = []
        while !env.isFinished { values.append(env.next()) }
        #expect(values.count == 250)
        #expect(values[0] == 0)
        #expect(values.allSatisfy { $0 >= 0 && $0 <= 1 })
        #expect(abs(values[100] - 1) < 1e-6)
        #expect(abs(values[149] - 1) < 1e-6)
        #expect(values.last! < 0.001)
        // Attack monoton artan
        for i in 1..<100 { #expect(values[i] >= values[i - 1]) }
        #expect(env.next() == 0)
    }
}

@Suite("Hacim ve uyku kısma eğrisi")
struct VolumeAndFadeTests {
    @Test(
        "hacim kırpma",
        arguments: [
            (-1.0, 0.0), (0.0, 0.0), (0.25, 0.25), (0.5, 0.5), (1.0, 1.0), (2.0, 1.0),
            (.infinity, 1.0), (-.infinity, 0.0), (.nan, 0.5),
        ])
    func clamp(input: Double, expected: Double) {
        #expect(SoundMath.clampedVolume(input) == expected)
    }

    @Test("hedef kazanç = hacim × kısma çarpanı")
    func targetGain() {
        #expect(SoundGainMath.targetGain(volume: 0.5, fadeFactor: 0.5) == 0.25)
        #expect(SoundGainMath.targetGain(volume: 2, fadeFactor: 2) == 1)
        #expect(SoundGainMath.targetGain(volume: 0.8, fadeFactor: 0) == 0)
    }

    @Test(
        "uyku kısma: kenarlar",
        arguments: [(10.0, 1.0), (5.0, 1.0), (0.0, 0.0), (-1.0, 0.0), (2.5, 0.5)])
    func fadeEdges(remaining: Double, expected: Double) {
        #expect(abs(SleepFade.gain(remaining: remaining) - expected) < 1e-9)
    }

    @Test("uyku kısma eğrisi monoton azalır, [0,1] içinde")
    func fadeMonotonic() {
        var previous = 1.0
        var t = 5.0
        while t >= 0 {
            let g = SleepFade.gain(remaining: t)
            #expect(g >= 0 && g <= 1)
            #expect(g <= previous + 1e-12)
            previous = g
            t -= 0.05
        }
        #expect(SleepFade.gain(remaining: .nan) == 0)
        #expect(SleepFade.gain(remaining: 1, fadeDuration: 0) == 1)
    }

    @Test("yumuşak sınırlayıcı: |çıktı| ≤ 1, monoton, küçük genlikte ≈ doğrusal", arguments: [
        -1e9 as Float, -10, -3, -1, -0.5, -0.1, 0, 0.1, 0.5, 1, 3, 10, 1e9,
    ])
    func softLimit(x: Float) {
        let y = SoundMath.softLimit(x)
        #expect(abs(y) <= 1)
        if abs(x) <= 0.1 { #expect(abs(y - x) < 0.001) }
    }

    @Test("yumuşak sınırlayıcı monoton artandır")
    func softLimitMonotonic() {
        var previous = SoundMath.softLimit(-5)
        var x: Float = -5
        while x < 5 {
            x += 0.01
            let y = SoundMath.softLimit(x)
            #expect(y >= previous)
            previous = y
        }
    }

    @Test("tek kutuplu katsayı (0,1) aralığında")
    func onePole() {
        let c = SoundMath.onePoleCoefficient(cutoff: 2_800, sampleRate: sampleRate)
        #expect(c > 0 && c < 1)
        #expect(SoundMath.onePoleCoefficient(cutoff: 0, sampleRate: sampleRate) > 0)
    }
}

@Suite("GainControl")
struct GainControlTests {
    private func run(_ gain: GainControl, frames: Int, input: Float = 1) -> [Float] {
        var l = [Float](repeating: input, count: frames)
        var r = [Float](repeating: input, count: frames)
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                gain.apply(left: lp.baseAddress!, right: rp.baseAddress!, frameCount: frames, sampleRate: sampleRate)
            }
        }
        return l
    }

    @Test("sıfırdan hedefe doğrusal yükselir, tek adımda sıçramaz")
    func rampsUp() {
        let g = GainControl(initial: 0, target: 0.5, rampSeconds: 0.1)
        let out = run(g, frames: 48_000)
        #expect(out[0] < 0.01)
        for i in 1..<out.count { #expect(out[i] >= out[i - 1]) }
        #expect(abs(out.last! - 0.5) < 1e-5)
        // Adım ≤ 1/(ramp·fs)
        let maxStep = zip(out.dropFirst(), out).map { $0 - $1 }.max()!
        #expect(maxStep <= Float(1 / (0.1 * sampleRate)) * 1.01)
    }

    @Test("hedef sıfıra çekilince tıklamasız iner")
    func rampsDown() {
        let g = GainControl(initial: 1, target: 1, rampSeconds: 0.05)
        g.set(target: 0, rampSeconds: 0.05)
        let out = run(g, frames: 4_800)
        for i in 1..<out.count { #expect(out[i] <= out[i - 1]) }
        #expect(out.last! == 0)
        #expect(g.target == 0)
    }

    @Test("rampa 0 ise anında")
    func instant() {
        let g = GainControl(initial: 0, target: 0.7, rampSeconds: 0)
        let out = run(g, frames: 4)
        #expect(out.allSatisfy { abs($0 - 0.7) < 1e-6 })
    }
}
