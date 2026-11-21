import Foundation
import Synchronization

/// Render bloğunda uygulanan, tıklamasız (doğrusal rampalı) kazanç.
///
/// Hedef kazanç ve rampa süresi atomiktir (ana iş parçacığı yazar, ses iş parçacığı okur; kilit yok).
/// `current` yalnızca `apply` içinde (ses iş parçacığı) değişir.
///
/// `@unchecked Sendable` gerekçesi: tek değişebilir durum `current`, yalnızca render bloğuna aittir;
/// geri kalanı atomiktir.
final class GainControl: @unchecked Sendable {
    private let targetBits: Atomic<UInt32>
    private let rampBits: Atomic<UInt32>
    private var current: Float

    /// Tam ölçekli (0→1) bir geçişin süresi `rampSeconds` olur.
    init(initial: Float = 0, target: Float = 0, rampSeconds: Float = 0.05) {
        targetBits = Atomic(target.bitPattern)
        rampBits = Atomic(rampSeconds.bitPattern)
        current = initial
    }

    /// Ana iş parçacığından: yeni hedef kazanç ve rampa süresi.
    func set(target: Double, rampSeconds: Double) {
        rampBits.store(Float(max(rampSeconds, 0)).bitPattern, ordering: .relaxed)
        targetBits.store(Float(target).bitPattern, ordering: .relaxed)
    }

    var target: Float { Float(bitPattern: targetBits.load(ordering: .relaxed)) }

    /// Ses iş parçacığından: `frameCount` örneğe rampalı kazanç uygular.
    func apply(
        left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frameCount: Int,
        sampleRate: Double
    ) {
        let target = Float(bitPattern: targetBits.load(ordering: .relaxed))
        let ramp = Float(bitPattern: rampBits.load(ordering: .relaxed))
        let step: Float = ramp > 0 ? Float(1 / (Double(ramp) * sampleRate)) : 1
        var c = current
        for i in 0..<frameCount {
            if c < target {
                c = min(c + step, target)
            } else if c > target {
                c = max(c - step, target)
            }
            left[i] *= c
            right[i] *= c
        }
        current = c
    }
}

/// Hacim (0…1) ve uyku kısma çarpanından hedef kazanç.
enum SoundGainMath {
    static func targetGain(volume: Double, fadeFactor: Double) -> Double {
        SoundMath.clampedVolume(volume) * SoundMath.clampedVolume(fadeFactor)
    }
}
