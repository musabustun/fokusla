import FokusDomain
import Foundation
import UserNotifications

/// Bildirim izni durumu (`UNAuthorizationStatus`'un sade hali).
public enum NotificationAuthorization: Sendable, Equatable {
    /// Henüz sorulmadı — `requestAuthorization()` sistem iletişim kutusunu gösterir.
    case notDetermined
    /// Kullanıcı reddetti — yalnızca sistem Ayarlar'dan açılabilir.
    case denied
    /// İzin var (geçici/provisional dahil).
    case authorized

    public var canSchedule: Bool { self == .authorized }
}

/// Yerel bildirim sözleşmesi (sunucu/push yok). Yalnızca Fokus'un kendi `fokus.reminder.` kimlikli
/// bildirimlerine dokunur.
@MainActor
public protocol NotificationService: AnyObject {
    func authorizationStatus() async -> NotificationAuthorization
    /// Sistem izin iletişim kutusunu gösterir; izin verildiyse `true`. Daha önce reddedildiyse sormaz → `false`.
    func requestAuthorization() async -> Bool
    /// Fokus'un bekleyen hatırlatmalarını verilenlerle DEĞİŞTİRİR (liste boşsa hepsi silinir).
    func replaceReminders(with reminders: [PlannedReminder]) async
    /// Bekleyen Fokus hatırlatma kimlikleri (sıralı).
    func pendingReminderIdentifiers() async -> [String]
}

/// `UNUserNotificationCenter` uygulaması.
@MainActor
public final class SystemNotificationService: NotificationService {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func authorizationStatus() async -> NotificationAuthorization {
        let settings = await center.notificationSettings()
        return Self.map(settings.authorizationStatus)
    }

    public func requestAuthorization() async -> Bool {
        guard await authorizationStatus() == .notDetermined else {
            return await authorizationStatus().canSchedule
        }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    public func replaceReminders(with reminders: [PlannedReminder]) async {
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix(ReminderPlanner.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        for reminder in reminders {
            guard let request = Self.request(for: reminder) else { continue }
            try? await center.add(request)
        }
    }

    public func pendingReminderIdentifiers() async -> [String] {
        await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(ReminderPlanner.identifierPrefix) }
            .sorted()
    }

    static func map(_ status: UNAuthorizationStatus) -> NotificationAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .authorized
        @unknown default: .denied
        }
    }

    /// Tek seferlik, takvim tetikleyicili bildirim (gün + saat yerel).
    static func request(for reminder: PlannedReminder, calendar: Calendar = .current) -> UNNotificationRequest? {
        guard let fire = ReminderPlanner.fireDate(day: reminder.day, time: reminder.time, calendar: calendar)
        else { return nil }
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
    }
}

/// Test/önizleme için sahte servis: izin durumunu ve planlananları bellekte tutar.
@MainActor
public final class MockNotificationService: NotificationService {
    public var authorization: NotificationAuthorization
    /// `requestAuthorization()` notDetermined iken ne döndürsün?
    public var grantsOnRequest: Bool
    public private(set) var scheduled: [PlannedReminder] = []
    public private(set) var requestCount = 0
    public private(set) var replaceCount = 0

    public init(authorization: NotificationAuthorization = .notDetermined, grantsOnRequest: Bool = true) {
        self.authorization = authorization
        self.grantsOnRequest = grantsOnRequest
    }

    public func authorizationStatus() async -> NotificationAuthorization { authorization }

    public func requestAuthorization() async -> Bool {
        requestCount += 1
        if authorization == .notDetermined { authorization = grantsOnRequest ? .authorized : .denied }
        return authorization.canSchedule
    }

    public func replaceReminders(with reminders: [PlannedReminder]) async {
        replaceCount += 1
        scheduled = reminders
    }

    public func pendingReminderIdentifiers() async -> [String] { scheduled.map(\.id).sorted() }
}
