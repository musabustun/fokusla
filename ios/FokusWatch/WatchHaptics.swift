import FokusDomain
import WatchKit

/// Saatte dokunsal geri bildirim (`WKInterfaceDevice`). İpucu görünen durumun geçişinden gelir
/// (`FocusLink.cue`): saatte başlat/bitir de telefondan gelen değişiklik de aynı yoldan titreşir.
enum WatchHaptics {
    static func play(_ cue: FocusLink.Cue) {
        let device = WKInterfaceDevice.current()
        switch cue {
        case .started: device.play(.start)
        case .paused: device.play(.directionDown)
        case .resumed: device.play(.directionUp)
        case .finished: device.play(.stop)
        }
    }
}
