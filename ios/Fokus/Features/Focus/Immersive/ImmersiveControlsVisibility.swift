import Foundation

/// Alt kontrol katmanının görünürlük durumu (saf mantık): dokununca belirir, `autoHideDelay` sonra
/// kaybolur. VoiceOver açıkken ve uzun mola uyarısı varken kaybolmaz ("sabitlenmiş").
struct ImmersiveControlsVisibility: Equatable {
    /// UI testlerinde (`-FokusUITestMode`) kontroller neredeyse hiç kaybolmaz: XCUITest uygulamanın boşta
    /// olmasını beklerken (saniyelik zamanlayıcı) birkaç sn geçebilir ve 4 sn'lik gizleme dokunuştan önce davranırdı.
    static var autoHideDelay: Duration {
        ProcessInfo.processInfo.arguments.contains("-FokusUITestMode") ? .seconds(300) : .seconds(4)
    }

    private(set) var isRevealed = false
    /// Her dokunuşta artar; zamanlayıcı görevi bu değere bağlıdır (yeniden başlar).
    private(set) var revision = 0

    mutating func reveal() {
        isRevealed = true
        revision += 1
    }

    mutating func hide() { isRevealed = false }

    /// Kontroller kaybolmamalı mı?
    static func isPinned(isVoiceOverRunning: Bool, isLongBreak: Bool) -> Bool {
        isVoiceOverRunning || isLongBreak
    }

    func isShown(pinned: Bool) -> Bool { isRevealed || pinned }

    /// Otomatik gizleme zamanlayıcısının kimliği: dokunuş veya sabitlenme durumu değişince yeniden başlar.
    struct TimerKey: Hashable {
        let revision: Int
        let pinned: Bool
    }

    func timerKey(pinned: Bool) -> TimerKey { TimerKey(revision: revision, pinned: pinned) }
}
