import Foundation

// Saf DSP parçaları. Hepsi değer tipidir, ayırma yapmaz ve `mutating` yöntemleriyle durumunu
// kendi içinde tutar; bu yüzden gerçek zamanlı render bloğunda ve birim testlerde aynen kullanılır.

/// Tohumlu, deterministik rastgele sayı üreteci (SplitMix64). Aynı tohum → aynı dizi.
struct SoundRandom: Equatable {
    private(set) var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// [0, 1)
    mutating func nextUnit() -> Float {
        Float(nextUInt64() >> 40) * (1.0 / 16_777_216.0)
    }

    /// [0, 1) çift duyarlıklı
    mutating func nextUnitDouble() -> Double {
        Double(nextUInt64() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    /// [-1, 1)
    mutating func nextBipolar() -> Float {
        nextUnit() * 2 - 1
    }

    mutating func next(in range: ClosedRange<Float>) -> Float {
        range.lowerBound + nextUnit() * (range.upperBound - range.lowerBound)
    }
}

/// Biquad (iki kutuplu iki sıfırlı) filtre katsayıları — RBJ Audio EQ Cookbook, `a0 = 1`'e normalize.
struct BiquadCoefficients: Equatable {
    var b0: Float
    var b1: Float
    var b2: Float
    var a1: Float
    var a2: Float

    static let passthrough = BiquadCoefficients(b0: 1, b1: 0, b2: 0, a1: 0, a2: 0)

    private init(b0: Float, b1: Float, b2: Float, a1: Float, a2: Float) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.a1 = a1
        self.a2 = a2
    }

    private init(b0: Double, b1: Double, b2: Double, a0: Double, a1: Double, a2: Double) {
        self.init(
            b0: Float(b0 / a0), b1: Float(b1 / a0), b2: Float(b2 / a0),
            a1: Float(a1 / a0), a2: Float(a2 / a0))
    }

    private static func angular(_ cutoff: Double, _ sampleRate: Double) -> (cos: Double, sin: Double, w0: Double) {
        let fc = min(max(cutoff, 10), sampleRate * 0.45)
        let w0 = 2 * Double.pi * fc / sampleRate
        return (cos(w0), sin(w0), w0)
    }

    static func lowpass(cutoff: Double, q: Double, sampleRate: Double) -> BiquadCoefficients {
        let (c, s, _) = angular(cutoff, sampleRate)
        let alpha = s / (2 * q)
        return BiquadCoefficients(
            b0: (1 - c) / 2, b1: 1 - c, b2: (1 - c) / 2,
            a0: 1 + alpha, a1: -2 * c, a2: 1 - alpha)
    }

    static func highpass(cutoff: Double, q: Double, sampleRate: Double) -> BiquadCoefficients {
        let (c, s, _) = angular(cutoff, sampleRate)
        let alpha = s / (2 * q)
        return BiquadCoefficients(
            b0: (1 + c) / 2, b1: -(1 + c), b2: (1 + c) / 2,
            a0: 1 + alpha, a1: -2 * c, a2: 1 - alpha)
    }

    /// Bant geçiren (sabit 0 dB tepe kazancı).
    static func bandpass(center: Double, q: Double, sampleRate: Double) -> BiquadCoefficients {
        let (c, s, _) = angular(center, sampleRate)
        let alpha = s / (2 * q)
        return BiquadCoefficients(
            b0: alpha, b1: 0, b2: -alpha,
            a0: 1 + alpha, a1: -2 * c, a2: 1 - alpha)
    }

    /// Verilen frekanstaki kazanç büyüklüğü (|H(e^{jω})|); testler ve ayar için.
    func magnitude(at frequency: Double, sampleRate: Double) -> Double {
        let w = 2 * Double.pi * frequency / sampleRate
        let (c1, s1) = (cos(w), sin(w))
        let (c2, s2) = (cos(2 * w), sin(2 * w))
        let numRe = Double(b0) + Double(b1) * c1 + Double(b2) * c2
        let numIm = -(Double(b1) * s1 + Double(b2) * s2)
        let denRe = 1 + Double(a1) * c1 + Double(a2) * c2
        let denIm = -(Double(a1) * s1 + Double(a2) * s2)
        return (numRe * numRe + numIm * numIm).squareRoot() / (denRe * denRe + denIm * denIm).squareRoot()
    }
}

/// Biquad filtre (aktarılmış doğrudan form II).
struct Biquad {
    var coefficients: BiquadCoefficients
    private var z1: Float = 0
    private var z2: Float = 0

    init(_ coefficients: BiquadCoefficients) { self.coefficients = coefficients }

    @inline(__always)
    mutating func process(_ x: Float) -> Float {
        let c = coefficients
        let y = c.b0 * x + z1
        z1 = c.b1 * x - c.a1 * y + z2
        z2 = c.b2 * x - c.a2 * y
        return y
    }
}

/// Pembe gürültü: Paul Kellet'in "rafine" filtresi (beyaz gürültüyü ~−3 dB/oktav eğimli yapar).
struct PinkNoiseFilter {
    private var b0: Float = 0
    private var b1: Float = 0
    private var b2: Float = 0
    private var b3: Float = 0
    private var b4: Float = 0
    private var b5: Float = 0
    private var b6: Float = 0

    /// `white` ∈ [-1, 1] → pembe gürültü (≈ ±0.5 civarında, nadiren daha fazla).
    @inline(__always)
    mutating func process(_ white: Float) -> Float {
        b0 = 0.99886 * b0 + white * 0.0555179
        b1 = 0.99332 * b1 + white * 0.0750759
        b2 = 0.96900 * b2 + white * 0.1538520
        b3 = 0.86650 * b3 + white * 0.3104856
        b4 = 0.55000 * b4 + white * 0.5329522
        b5 = -0.7616 * b5 - white * 0.0168980
        let out = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362
        b6 = white * 0.115926
        return out * 0.11
    }
}

/// Kahverengi (Brown/kırmızı) gürültü: sızıntılı integratör. |y| ≤ 1 garantilidir
/// (geometrik seri: 0.02/1.02 · Σ(1/1.02)^k = 1).
struct BrownNoiseIntegrator {
    static let leak: Float = 1.02
    static let gain: Float = 0.02
    private(set) var value: Float = 0

    @inline(__always)
    mutating func process(_ white: Float) -> Float {
        value = (value + Self.gain * white) / Self.leak
        return value
    }
}

/// Yağmur damlası zamanlayıcısı: Poisson süreci → damlalar arası süre üstel dağılımlı
/// (ortalama 1 / oran). Tohumlu olduğundan deterministik test edilebilir.
struct DropScheduler {
    private var random: SoundRandom
    let ratePerSecond: Double

    init(ratePerSecond: Double, seed: UInt64) {
        self.ratePerSecond = max(ratePerSecond, 0.001)
        random = SoundRandom(seed: seed)
    }

    /// Bir sonraki damlaya kadar saniye (her zaman ≥ 0 ve sonlu).
    mutating func nextInterval() -> Double {
        let u = 1 - random.nextUnitDouble()  // (0, 1]
        return -log(u) / ratePerSecond
    }
}

/// Yumuşak melodinin nota seçici: skala üzerinde sınırlı rastgele yürüyüş.
struct MelodyNotePicker {
    struct Note: Equatable {
        let index: Int
        let midi: Int
        let frequency: Double
        /// Bir sonraki notaya kadar saniye.
        let gapToNext: Double
        let attack: Double
        let hold: Double
        let release: Double
    }

    private var random: SoundRandom
    private(set) var index: Int

    init(seed: UInt64, startIndex: Int = 0) {
        random = SoundRandom(seed: seed)
        index = min(max(startIndex, 0), PentatonicScale.noteCount - 1)
    }

    mutating func next() -> Note {
        var step = Int(random.nextUnit() * 5) - 2  // -2…2
        if step == 0 { step = random.nextUnit() < 0.5 ? 1 : -1 }
        index = min(max(index + step, 0), PentatonicScale.noteCount - 1)
        return Note(
            index: index,
            midi: PentatonicScale.midi(at: index),
            frequency: PentatonicScale.frequency(at: index),
            gapToNext: Double(random.next(in: 2.2...4.8)),
            attack: Double(random.next(in: 1.6...3.0)),
            hold: Double(random.next(in: 0.5...2.0)),
            release: Double(random.next(in: 3.0...5.0)))
    }
}

/// Pad zarfı: yumuşak (smoothstep) attack, düz hold, yumuşak release. Süreler örnek sayısıdır.
struct PadEnvelope {
    private let attack: Int
    private let hold: Int
    private let release: Int
    private let invAttack: Float
    private let invRelease: Float
    private var position = 0

    init(attackSamples: Int, holdSamples: Int, releaseSamples: Int) {
        attack = max(attackSamples, 1)
        hold = max(holdSamples, 0)
        release = max(releaseSamples, 1)
        invAttack = 1 / Float(attack)
        invRelease = 1 / Float(release)
    }

    var isFinished: Bool { position >= attack + hold + release }

    @inline(__always)
    mutating func next() -> Float {
        let p = position
        position += 1
        if p < attack {
            let x = Float(p) * invAttack
            return x * x * (3 - 2 * x)
        }
        if p < attack + hold { return 1 }
        if p < attack + hold + release {
            let x = 1 - Float(p - attack - hold) * invRelease
            return x * x * (3 - 2 * x)
        }
        return 0
    }
}
