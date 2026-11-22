import AppIntents
import FokusAudio
import FokusData
import FokusDomain
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "focus-filter")

/// iOS Odak (Focus) filtresi seçeneği: Odak modu açılınca çalınacak ses. Varsayılan "Dokunma".
enum AmbientSoundOption: String, AppEnum {
    case none, whiteNoise, pinkNoise, brownNoise, rain, melody

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Odak sesi")
    static let caseDisplayRepresentations: [AmbientSoundOption: DisplayRepresentation] = [
        .none: "Dokunma", .whiteNoise: "Beyaz gürültü", .pinkNoise: "Pembe gürültü",
        .brownNoise: "Kahverengi gürültü", .rain: "Yağmur", .melody: "Yumuşak melodi",
    ]

    var soundRaw: String? { self == .none ? nil : rawValue }
}

/// Odak filtresi (Ayarlar → Odak → Odak filtreleri → Fokus). Sade tutuldu: iki seçenek.
/// Varsayılanlar "etkisiz"dir; bu yüzden filtre kapanınca (sistem varsayılanlarla çağırsa da) hiçbir şey bastırılmaz.
struct FokusFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Fokus"
    static let description = IntentDescription(
        "Odak modu açıkken Fokus'un hatırlatmalarını susturur ve istersen bir odak sesi çalar.")

    @Parameter(title: "Hatırlatmaları sustur", default: false) var silenceReminders: Bool
    @Parameter(title: "Odak sesi", default: AmbientSoundOption.none) var ambientSound: AmbientSoundOption

    var displayRepresentation: DisplayRepresentation {
        var parts: [String] = []
        if silenceReminders { parts.append("Hatırlatmalar sessiz") }
        if ambientSound != .none { parts.append("Odak sesi açık") }
        let subtitle = parts.isEmpty ? "Değişiklik yok" : parts.joined(separator: " · ")
        return DisplayRepresentation(title: "Fokus", subtitle: LocalizedStringResource(stringLiteral: subtitle))
    }

    var settings: FocusFilterSettings {
        FocusFilterSettings(silenceReminders: silenceReminders, ambientSoundRaw: ambientSound.soundRaw)
    }

    func perform() async throws -> some IntentResult {
        FocusFilterStore.save(settings)
        await FocusFilterStore.applyReminderPolicy()
        return .result()
    }
}

/// Filtre ayarlarının paylaşılan (App Group) saklaması ve uygulaması.
enum FocusFilterStore {
    private static var defaults: UserDefaults { UserDefaults(suiteName: FokusAppGroup.identifier) ?? .standard }

    static func load() -> FocusFilterSettings {
        FocusFilterSettings.decode(defaults.data(forKey: FocusFilterSettings.storageKey))
            ?? FocusFilterSettings(silenceReminders: false)
    }

    static func save(_ settings: FocusFilterSettings) {
        defaults.set(settings.encoded(), forKey: FocusFilterSettings.storageKey)
    }

    /// Uygulama öne gelince sistemdeki etkin filtreyi okur (filtre yoksa varsayılan = etkisiz).
    @MainActor
    static func refreshFromSystem() async {
        guard let current = try? await FokusFocusFilter.current else { return }
        save(current.settings)
        await applyReminderPolicy()
    }

    /// Filtre hatırlatmaları susturuyorsa bekleyenleri siler; değilse normal planı yeniden kurar.
    @MainActor
    static func applyReminderPolicy() async {
        let scheduler = ReminderScheduler(service: SystemNotificationService())
        if load().silenceReminders {
            await scheduler.cancelAll()
        } else if let context = try? FokusSystem.context() {
            await scheduler.reschedule(context: context)
        }
    }
}
