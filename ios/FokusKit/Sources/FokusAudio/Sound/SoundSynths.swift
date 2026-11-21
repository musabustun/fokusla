import Foundation

/// Gerçek zamanlı ses üreteci. `render` AVAudioSourceNode'un render bloğundan (ses iş parçacığı)
/// çağrılır: bellek ayırma, kilit, ObjC/Swift runtime çağrısı, log YOKTUR.
///
/// Eşzamanlılık (`@unchecked Sendable` gerekçesi): bir üretecin değişebilir durumuna yalnızca render
/// bloğu dokunur (tek ses iş parçacığı, seri). Oluşturan taraf (ana iş parçacığı) üretimden sonra
/// durumuna dokunmaz; yalnızca referansı render bloğuna devreder. Parametre değişimi atomik
/// `GainControl` üzerinden yapılır.
protocol SoundSynthesizing: AnyObject, Sendable {
    /// `left`/`right`: `frameCount` örneklik stereo çıktı. Üzerine YAZAR (toplamaz).
    func render(
        left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frameCount: Int)
}

enum SoundSynthFactory {
    static func make(kind: FocusSoundKind, sampleRate: Double, seed: UInt64) -> any SoundSynthesizing {
        switch kind {
        case .whiteNoise: NoiseSynth(color: .white, seed: seed)
        case .pinkNoise: NoiseSynth(color: .pink, seed: seed)
        case .brownNoise: NoiseSynth(color: .brown, seed: seed)
        case .rain: RainSynth(sampleRate: sampleRate, seed: seed)
        case .melody: MelodySynth(sampleRate: sampleRate, seed: seed)
        }
    }
}

// MARK: - Gürültü

/// Beyaz / pembe / kahverengi gürültü. Kanallar birbirinden bağımsız üretilir (geniş stereo).
final class NoiseSynth: SoundSynthesizing, @unchecked Sendable {
    enum Color: Sendable { case white, pink, brown }

    /// Renk başına seviye: ~−14…−12 dBFS RMS; yumuşak sınırlayıcı tepeleri korur.
    static func level(for color: Color) -> Float {
        switch color {
        case .white: 0.30
        case .pink: 1.0
        case .brown: 3.2
        }
    }

    private let color: Color
    private let scale: Float
    private var randomL: SoundRandom
    private var randomR: SoundRandom
    private var pinkL = PinkNoiseFilter()
    private var pinkR = PinkNoiseFilter()
    private var brownL = BrownNoiseIntegrator()
    private var brownR = BrownNoiseIntegrator()

    init(color: Color, seed: UInt64) {
        self.color = color
        scale = Self.level(for: color)
        randomL = SoundRandom(seed: seed)
        randomR = SoundRandom(seed: seed ^ 0xA5A5_A5A5_5A5A_5A5A)
    }

    func render(
        left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frameCount: Int
    ) {
        var rl = randomL
        var rr = randomR
        var pl = pinkL
        var pr = pinkR
        var bl = brownL
        var br = brownR
        let scale = scale
        switch color {
        case .white:
            for i in 0..<frameCount {
                left[i] = SoundMath.softLimit(rl.nextBipolar() * scale)
                right[i] = SoundMath.softLimit(rr.nextBipolar() * scale)
            }
        case .pink:
            for i in 0..<frameCount {
                left[i] = SoundMath.softLimit(pl.process(rl.nextBipolar()) * scale)
                right[i] = SoundMath.softLimit(pr.process(rr.nextBipolar()) * scale)
            }
        case .brown:
            for i in 0..<frameCount {
                left[i] = SoundMath.softLimit(bl.process(rl.nextBipolar()) * scale)
                right[i] = SoundMath.softLimit(br.process(rr.nextBipolar()) * scale)
            }
        }
        randomL = rl
        randomR = rr
        pinkL = pl
        pinkR = pr
        brownL = bl
        brownR = br
    }
}

// MARK: - Yağmur

/// Yağmur: filtrelenmiş gürültü yatağı + rastgele damla darbeleri (Poisson zamanlı, üstel zarflı).
final class RainSynth: SoundSynthesizing, @unchecked Sendable {
    private struct Voice {
        var phase: Float = 0
        var increment: Float = 0
        var chirp: Float = 1
        var envelope: Float = 0  // 0 = boşta
        var decay: Float = 1
        var amplitude: Float = 0
        var gainL: Float = 0
        var gainR: Float = 0
    }

    static let voiceCapacity = 32
    private static let silenceThreshold: Float = 0.0005
    private static let twoPi = Float.pi * 2

    private let sampleRate: Double
    private let voices: UnsafeMutablePointer<Voice>
    private var randomL: SoundRandom
    private var randomR: SoundRandom
    private var randomDrops: SoundRandom
    private var scheduler: DropScheduler
    private var samplesUntilDrop: Int
    private var highpassL: Biquad
    private var highpassR: Biquad
    private var lowpassL: Biquad
    private var lowpassR: Biquad
    private var gustPhase: Float = 0
    private let gustIncrement: Float

    init(sampleRate: Double, seed: UInt64, dropsPerSecond: Double = 20) {
        self.sampleRate = sampleRate
        voices = .allocate(capacity: Self.voiceCapacity)
        voices.initialize(repeating: Voice(), count: Self.voiceCapacity)
        randomL = SoundRandom(seed: seed)
        randomR = SoundRandom(seed: seed ^ 0x1234_5678_9ABC_DEF0)
        randomDrops = SoundRandom(seed: seed ^ 0x0F0F_F0F0_0F0F_F0F0)
        var sched = DropScheduler(ratePerSecond: dropsPerSecond, seed: seed ^ 0x7777_1111_3333_5555)
        samplesUntilDrop = Int(sched.nextInterval() * sampleRate)
        scheduler = sched
        let hp = BiquadCoefficients.highpass(cutoff: 260, q: 0.7071, sampleRate: sampleRate)
        let lp = BiquadCoefficients.lowpass(cutoff: 6_500, q: 0.7071, sampleRate: sampleRate)
        highpassL = Biquad(hp)
        highpassR = Biquad(hp)
        lowpassL = Biquad(lp)
        lowpassR = Biquad(lp)
        gustIncrement = Float(2 * Double.pi * 0.09 / sampleRate)
    }

    deinit {
        voices.deinitialize(count: Self.voiceCapacity)
        voices.deallocate()
    }

    func render(
        left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frameCount: Int
    ) {
        var rl = randomL
        var rr = randomR
        var hpL = highpassL
        var hpR = highpassR
        var lpL = lowpassL
        var lpR = lowpassR
        var gust = gustPhase
        var untilDrop = samplesUntilDrop
        let voices = voices
        let capacity = Self.voiceCapacity
        let threshold = Self.silenceThreshold
        let twoPi = Self.twoPi

        for i in 0..<frameCount {
            // Yatak: bant sınırlı gürültü, yavaş "rüzgâr" dalgalanması
            let gustGain = 0.85 + 0.15 * sinf(gust)
            gust += gustIncrement
            if gust > twoPi { gust -= twoPi }
            var l = lpL.process(hpL.process(rl.nextBipolar())) * 0.55 * gustGain
            var r = lpR.process(hpR.process(rr.nextBipolar())) * 0.55 * gustGain

            // Yeni damla
            untilDrop -= 1
            if untilDrop <= 0 {
                spawnDrop()
                untilDrop = max(1, Int(scheduler.nextInterval() * sampleRate))
            }

            // Damlalar
            for v in 0..<capacity where voices[v].envelope > 0 {
                let s = sinf(voices[v].phase) * voices[v].envelope * voices[v].amplitude
                l += s * voices[v].gainL
                r += s * voices[v].gainR
                var phase = voices[v].phase + voices[v].increment
                if phase > twoPi { phase -= twoPi }
                voices[v].phase = phase
                voices[v].increment *= voices[v].chirp
                let env = voices[v].envelope * voices[v].decay
                voices[v].envelope = env < threshold ? 0 : env
            }
            left[i] = SoundMath.softLimit(l)
            right[i] = SoundMath.softLimit(r)
        }
        randomL = rl
        randomR = rr
        highpassL = hpL
        highpassR = hpR
        lowpassL = lpL
        lowpassR = lpR
        gustPhase = gust
        samplesUntilDrop = untilDrop
    }

    /// Boşta bir ses bulup rastgele perde/genlik/panorama ile damla başlatır (yoksa atlar).
    private func spawnDrop() {
        var slot = -1
        for v in 0..<Self.voiceCapacity where voices[v].envelope == 0 {
            slot = v
            break
        }
        guard slot >= 0 else { return }
        let frequency = 1_500 * powf(4.5, randomDrops.nextUnit())  // 1.5–6.75 kHz, log-düzgün
        let tau = randomDrops.next(in: 0.004...0.016)  // saniye
        let pan = randomDrops.next(in: 0.15...0.85)
        // Eşit güç panorama (hafif stereo yayılım)
        let angle = pan * (Float.pi / 2)
        voices[slot] = Voice(
            phase: 0,
            increment: Self.twoPi * frequency / Float(sampleRate),
            chirp: 1 + randomDrops.next(in: 0...0.00005),
            envelope: 1,
            decay: expf(-1 / (tau * Float(sampleRate))),
            amplitude: randomDrops.next(in: 0.05...0.28),
            gainL: cosf(angle),
            gainR: sinf(angle))
    }
}

// MARK: - Yumuşak melodi

/// Basit stereo geri beslemeli yankı gecikme hattı (önceden ayrılmış bellek).
struct DelayLine {
    private let buffer: UnsafeMutablePointer<Float>
    private let length: Int
    private var index = 0

    init(length: Int) {
        self.length = max(length, 1)
        buffer = .allocate(capacity: self.length)
        buffer.initialize(repeating: 0, count: self.length)
    }

    /// Sahibi (`MelodySynth.deinit`) çağırır.
    func free() {
        buffer.deallocate()
    }

    @inline(__always) func read() -> Float { buffer[index] }

    @inline(__always)
    mutating func write(_ x: Float) {
        buffer[index] = x
        index += 1
        if index >= length { index = 0 }
    }
}

/// Üretken pad melodisi: A minör pentatonik; yavaş attack/release'li, hafif detune'lu sinüs
/// partial'leri; rastgele nota zamanlayıcı; ping-pong geri beslemeli yankı.
final class MelodySynth: SoundSynthesizing, @unchecked Sendable {
    private struct Voice {
        var active = false
        var phase1: Float = 0
        var phase2: Float = 0
        var phase3: Float = 0
        var increment1: Float = 0
        var increment2: Float = 0
        var increment3: Float = 0
        var envelope = PadEnvelope(attackSamples: 1, holdSamples: 0, releaseSamples: 1)
        var amplitude: Float = 0
        var gainL: Float = 0
        var gainR: Float = 0
    }

    static let voiceCapacity = 8
    private static let twoPi = Float.pi * 2

    private let sampleRate: Double
    private let voices: UnsafeMutablePointer<Voice>
    private var picker: MelodyNotePicker
    private var spawnRandom: SoundRandom
    private var samplesUntilNote: Int
    private var delayL: DelayLine
    private var delayR: DelayLine
    private var dampL: Float = 0
    private var dampR: Float = 0
    private let dampCoefficient: Float

    init(sampleRate: Double, seed: UInt64) {
        self.sampleRate = sampleRate
        voices = .allocate(capacity: Self.voiceCapacity)
        voices.initialize(repeating: Voice(), count: Self.voiceCapacity)
        picker = MelodyNotePicker(seed: seed, startIndex: 3)
        spawnRandom = SoundRandom(seed: seed ^ 0x3C3C_C3C3_3C3C_C3C3)
        delayL = DelayLine(length: Int(0.31 * sampleRate))
        delayR = DelayLine(length: Int(0.37 * sampleRate))
        dampCoefficient = SoundMath.onePoleCoefficient(cutoff: 2_800, sampleRate: sampleRate)
        samplesUntilNote = Int(2.5 * sampleRate)
        // Hemen duyulsun: kök (A3) ve beşli (E4) birlikte, kısa attack ile başlar.
        spawn(index: 0, attack: 0.7, hold: 2.0, release: 4.0, amplitude: 0.5)
        spawn(index: 3, attack: 0.9, hold: 1.5, release: 4.0, amplitude: 0.4)
    }

    deinit {
        voices.deinitialize(count: Self.voiceCapacity)
        voices.deallocate()
        delayL.free()
        delayR.free()
    }

    func render(
        left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frameCount: Int
    ) {
        var dl = delayL
        var dr = delayR
        var dampL = dampL
        var dampR = dampR
        var untilNote = samplesUntilNote
        let damping = dampCoefficient
        let voices = voices
        let capacity = Self.voiceCapacity
        let twoPi = Self.twoPi
        let feedback: Float = 0.52
        let wet: Float = 0.5
        let master: Float = 0.42

        for i in 0..<frameCount {
            untilNote -= 1
            if untilNote <= 0 {
                let note = picker.next()
                spawn(
                    index: note.index, attack: note.attack, hold: note.hold, release: note.release,
                    amplitude: spawnRandom.next(in: 0.3...0.5))
                untilNote = max(1, Int(note.gapToNext * sampleRate))
            }

            var l: Float = 0
            var r: Float = 0
            for v in 0..<capacity where voices[v].active {
                let env = voices[v].envelope.next()
                if voices[v].envelope.isFinished {
                    voices[v].active = false
                    continue
                }
                let tone =
                    0.5 * (sinf(voices[v].phase1) + sinf(voices[v].phase2))
                    + 0.22 * sinf(voices[v].phase3)
                let s = tone * env * voices[v].amplitude
                l += s * voices[v].gainL
                r += s * voices[v].gainR
                voices[v].phase1 = wrap(voices[v].phase1 + voices[v].increment1, twoPi)
                voices[v].phase2 = wrap(voices[v].phase2 + voices[v].increment2, twoPi)
                voices[v].phase3 = wrap(voices[v].phase3 + voices[v].increment3, twoPi)
            }

            // Ping-pong yankı: L gecikmesi R'ye, R gecikmesi L'ye besler; döngüde alçak geçiren sönümleme.
            dampL += damping * (dl.read() - dampL)
            dampR += damping * (dr.read() - dampR)
            dl.write(l + feedback * dampR)
            dr.write(r + feedback * dampL)
            left[i] = SoundMath.softLimit((l + wet * dampL) * master)
            right[i] = SoundMath.softLimit((r + wet * dampR) * master)
        }
        delayL = dl
        delayR = dr
        self.dampL = dampL
        self.dampR = dampR
        samplesUntilNote = untilNote
    }

    @inline(__always)
    private func wrap(_ phase: Float, _ twoPi: Float) -> Float {
        phase > twoPi ? phase - twoPi : phase
    }

    /// Boşta bir ses bulup notayı başlatır; hepsi doluysa atlar.
    private func spawn(index: Int, attack: Double, hold: Double, release: Double, amplitude: Float) {
        var slot = -1
        for v in 0..<Self.voiceCapacity where !voices[v].active {
            slot = v
            break
        }
        guard slot >= 0 else { return }
        let f = PentatonicScale.frequency(at: index)
        let detune = SoundMath.centsToRatio(Double(spawnRandom.next(in: 3...8)))
        let w = 2 * Double.pi / sampleRate
        let pan = spawnRandom.next(in: 0.25...0.75)
        let angle = pan * (Float.pi / 2)
        voices[slot] = Voice(
            active: true,
            phase1: 0,
            phase2: spawnRandom.next(in: 0...Self.twoPi),
            phase3: 0,
            increment1: Float(w * f),
            increment2: Float(w * f * detune),
            increment3: Float(w * f * 2 * 0.9985),
            envelope: PadEnvelope(
                attackSamples: Int(attack * sampleRate),
                holdSamples: Int(hold * sampleRate),
                releaseSamples: Int(release * sampleRate)),
            amplitude: amplitude,
            gainL: cosf(angle),
            gainR: sinf(angle))
    }
}
