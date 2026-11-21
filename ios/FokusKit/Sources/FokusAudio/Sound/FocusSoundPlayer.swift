import Foundation
import Observation

/// GEÇİCİ İSKELET — gerçek `AVAudioEngine` uygulaması ses motoru işiyle bu dosyanın yerine geçer.
/// Durumu tutar ama ses üretmez.
@MainActor
@Observable
public final class FocusSoundPlayer: FocusSoundControlling {
    public private(set) var currentKind: FocusSoundKind?
    public private(set) var isPlaying = false
    public var volume: Double = 0.5
    public var mixesWithOtherAudio = true
    public private(set) var sleepTimerEndsAt: Date?
    public private(set) var errorMessage: String?

    public init() {}

    public func play(_ kind: FocusSoundKind) {
        currentKind = kind
        isPlaying = true
    }

    public func stop() {
        currentKind = nil
        isPlaying = false
        sleepTimerEndsAt = nil
    }

    public func setSleepTimer(minutes: Int?) {
        sleepTimerEndsAt = minutes.map { Date().addingTimeInterval(Double($0) * 60) }
    }
}
