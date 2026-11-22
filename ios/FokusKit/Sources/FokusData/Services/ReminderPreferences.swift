import FokusDomain
import Foundation

/// Hatırlatma tercihlerinin (`ReminderSettings`) UserDefaults deposu. Cihaza özeldir; senkronlanmaz.
public struct ReminderPreferences {
    public static let key = "fokus.reminders.settings"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Kayıt yoksa ya da çözülemezse varsayılan (hepsi kapalı).
    public func load() -> ReminderSettings {
        guard let data = defaults.data(forKey: Self.key),
            let settings = try? JSONDecoder().decode(ReminderSettings.self, from: data)
        else { return ReminderSettings() }
        return settings
    }

    public func save(_ settings: ReminderSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }

    public func reset() {
        defaults.removeObject(forKey: Self.key)
    }
}
