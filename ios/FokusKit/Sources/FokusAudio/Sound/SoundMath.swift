import Foundation

/// Odak sesi motorunun saf (yan etkisiz) matematik yardımcıları. Donanım/AVFoundation bilmez;
/// hepsi birim testlerle doğrulanır.
enum SoundMath {
    static let defaultVolume = 0.5

    /// Hacmi 0…1 aralığına kırpar. `NaN` → varsayılan (0.5); ±∞ uçlara kırpılır.
    static func clampedVolume(_ value: Double) -> Double {
        if value.isNaN { return defaultVolume }
        return min(max(value, 0), 1)
    }

    /// Yumuşak sınırlayıcı (Padé benzeri): |x| küçükken ≈ x, büyürken yumuşakça 1'e yaklaşır.
    /// Çıktı her zaman [-1, 1] aralığındadır, monotondur; render bloğunda güvenle çağrılabilir
    /// (yalnızca aritmetik, çağrı/ayırma yok).
    @inline(__always)
    static func softLimit(_ x: Float) -> Float {
        let c = min(max(x, -3), 3)
        // |c| = 3'te tepe noktası tam 1; yuvarlama hatası 1'i aşmasın diye son kırpma.
        return min(max(c * (27 + c * c) / (27 + 9 * c * c), -1), 1)
    }

    /// MIDI nota numarası → Hz (A4 = MIDI 69 = 440 Hz, eşit tamperaman).
    static func midiToHz(_ note: Double) -> Double {
        440 * pow(2, (note - 69) / 12)
    }

    /// Cent cinsinden perde farkı → frekans oranı (100 cent = 1 yarım ton).
    static func centsToRatio(_ cents: Double) -> Double {
        pow(2, cents / 1200)
    }

    /// Bir pencerede, tek kutuplu alçak geçiren filtre katsayısı (damping için).
    static func onePoleCoefficient(cutoff: Double, sampleRate: Double) -> Float {
        let c = min(max(cutoff, 1), sampleRate * 0.45)
        return Float(1 - exp(-2 * Double.pi * c / sampleRate))
    }
}

/// Uyku zamanlayıcısının son saniyelerindeki yumuşak kısma eğrisi.
enum SleepFade {
    /// Bitmeden önce kısmanın başladığı süre (saniye).
    static let defaultDuration: TimeInterval = 5

    /// Kalan süreye göre çarpan: `remaining >= fadeDuration` → 1, `remaining <= 0` → 0, arada
    /// yarım kosinüs (monoton azalan, uçlarda türev 0 → tıklama/ani kesilme yok).
    static func gain(remaining: TimeInterval, fadeDuration: TimeInterval = defaultDuration) -> Double {
        if remaining.isNaN { return 0 }
        if remaining <= 0 { return 0 }
        if fadeDuration <= 0 || remaining >= fadeDuration { return 1 }
        let t = remaining / fadeDuration  // 1 → 0
        return 0.5 - 0.5 * cos(Double.pi * t)
    }
}

/// A minör pentatonik skala (A C D E G), A3'ten iki oktav + üst A (11 nota).
enum PentatonicScale {
    static let rootMIDI = 57
    static let intervals = [0, 3, 5, 7, 10]
    static let octaves = 2
    static var noteCount: Int { intervals.count * octaves + 1 }

    /// Skala indeksi (0…noteCount-1; dışı kırpılır) → MIDI numarası.
    static func midi(at index: Int) -> Int {
        let i = min(max(index, 0), noteCount - 1)
        let (octave, degree) = i.quotientAndRemainder(dividingBy: intervals.count)
        return rootMIDI + 12 * octave + intervals[degree]
    }

    static func frequency(at index: Int) -> Double {
        SoundMath.midiToHz(Double(midi(at: index)))
    }

    /// Verilen MIDI notası skalanın bir derecesi mi? (oktavdan bağımsız)
    static func contains(midi: Int) -> Bool {
        let pitchClass = ((midi - rootMIDI) % 12 + 12) % 12
        return intervals.contains(pitchClass)
    }
}
