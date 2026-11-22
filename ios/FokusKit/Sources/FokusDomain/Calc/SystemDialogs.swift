import Foundation

/// Siri / Kestirmeler yanıt metinleri ve Odak filtresi ayarları — SAF (Türkçe, tr-TR biçimleri).
/// App Intents `perform()` bu metinleri kullanır; mantık burada test edilir.
public enum SystemDialogs {
    /// "Bugün ne kadar çalıştım?" yanıtı.
    public static func todaySummary(focusMs: Double, goalMinutes: Int?) -> String {
        let focus = focusMs.isFinite && focusMs > 0 ? focusMs : 0
        let head =
            focus < 60_000
            ? "Bugün henüz odaklanmadın."
            : "Bugün \(FocusFormat.durationText(focus)) odaklandın."
        guard let progress = DailyGoalCalc.progress(focusMs: focus, goalMinutes: goalMinutes) else {
            return head
        }
        if progress.isReached { return "\(head) Günlük hedefine ulaştın." }
        let remaining = DailyGoalCalc.remainingText(progress).replacingOccurrences(of: " kaldı", with: "")
        return "\(head) Hedefine \(remaining) kaldı."
    }

    public static func focusStarted(subjectName: String?) -> String {
        guard let name = subjectName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return "Odak başladı."
        }
        return "\(name) odağı başladı."
    }

    public static let focusAlreadyRunning = "Bir odak oturumu zaten sürüyor."
    public static let noActiveFocus = "Açık bir odak oturumu yok."

    public static func focusFinished(focusMs: Double) -> String {
        let focus = focusMs.isFinite && focusMs > 0 ? focusMs : 0
        return focus < 1000
            ? "Odak bitti."
            : "Odak bitti. Bu oturumda \(FocusFormat.durationText(focus)) odaklandın."
    }

    public static func taskAdded(title: String) -> String { "“\(title)” görevi eklendi." }

    /// Görev adı: kenar boşlukları kırpılır; boşsa `nil`.
    public static func normalizedTaskTitle(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// iOS Odak (Focus) filtresi: Odak modu açılınca Fokus'ta uygulanacak sade ayarlar.
public struct FocusFilterSettings: Codable, Sendable, Equatable {
    /// Filtre açıkken Fokus'un yerel hatırlatmaları planlanmaz/bastırılır.
    public var silenceReminders: Bool
    /// Odak oturumu başlayınca otomatik çalınacak ses (`FocusSoundKind.rawValue`); `nil` = dokunma.
    public var ambientSoundRaw: String?

    public init(silenceReminders: Bool = true, ambientSoundRaw: String? = nil) {
        self.silenceReminders = silenceReminders
        self.ambientSoundRaw = ambientSoundRaw
    }

    /// Paylaşılan (App Group) UserDefaults anahtarı.
    public static let storageKey = "fokus.focusFilter.settings"

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }

    public static func decode(_ data: Data?) -> FocusFilterSettings? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(FocusFilterSettings.self, from: data)
    }
}
