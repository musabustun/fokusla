import CoreData
import Foundation
import Observation

/// Senkron durumu (web `SyncState` karşılığı).
public enum SyncStatus: Sendable, Equatable {
    /// Senkron kapalı ya da iCloud hesabı yok — veri yalnızca cihazda.
    case disabled
    case idle
    case syncing
    case error(String)
}

/// Senkron sözleşmesi (web `SyncService`). Native'de SwiftData otomatik mirroring kullanılır;
/// repository'lerin `recordLocalChange()` çağırmasına gerek YOKTUR (SwiftData kendisi izler).
@MainActor
public protocol SyncService: AnyObject {
    var status: SyncStatus { get }
    /// Kullanıcı tercihi. Değişiklik bir sonraki açılışta container kurulurken uygulanır.
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool)
}

/// Kullanıcı tercihleri anahtarları.
public enum SyncPreferences {
    public static let enabledKey = "fokus.sync.enabled"

    /// Varsayılan: açık (iCloud hesabı varsa senkronlanır).
    public static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? true
    }
}

/// CloudKit mirroring olaylarını (`NSPersistentCloudKitContainer.eventChangedNotification`)
/// izleyerek durum üretir. Uygulama ömrü boyunca yaşar.
@MainActor
@Observable
public final class CloudKitSyncService: SyncService {
    public private(set) var status: SyncStatus
    public private(set) var isEnabled: Bool
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    /// - Parameter isActive: container gerçekten CloudKit modunda mı kuruldu?
    public init(isActive: Bool, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = SyncPreferences.isEnabled(in: defaults)
        self.status = isActive ? .idle : .disabled
        if isActive { startObserving() }
    }

    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: SyncPreferences.enabledKey)
    }

    private func startObserving() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            let event = notification.userInfo?[key] as? NSPersistentCloudKitContainer.Event
            let finished = event?.endDate != nil
            let errorText = event?.error?.localizedDescription
            MainActor.assumeIsolated {
                self?.apply(finished: finished, errorText: errorText)
            }
        }
    }

    private func apply(finished: Bool, errorText: String?) {
        if let errorText {
            status = .error(errorText)
        } else {
            status = finished ? .idle : .syncing
        }
    }
}

/// Önizleme/test için sahte servis.
@MainActor
@Observable
public final class MockSyncService: SyncService {
    public var status: SyncStatus
    public private(set) var isEnabled: Bool

    public init(status: SyncStatus = .disabled, isEnabled: Bool = false) {
        self.status = status
        self.isEnabled = isEnabled
    }

    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        status = enabled ? .idle : .disabled
    }
}
