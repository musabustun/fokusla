import FokusDomain
import Foundation
import UserNotifications
import WatchKit

/// Saatte dokunsal geri bildirim: anlık ipuçları (`WKInterfaceDevice`) + uygulama arka plandayken bileği
/// titreten yerel bildirimler (uzun mola, günlük hedef). Sunucu/push yok; hepsi cihazda planlanır.
enum WatchHaptics {
    static func play(_ cue: FocusLink.Cue) {
        let device = WKInterfaceDevice.current()
        switch cue {
        case .started: device.play(.start)
        case .paused: device.play(.directionDown)
        case .resumed: device.play(.directionUp)
        case .finished: device.play(.stop)
        case .longBreak: device.play(.notification)
        case .goalReached: device.play(.success)
        }
    }

    /// Görev işareti gibi küçük onaylar.
    static func tap() { WKInterfaceDevice.current().play(.click) }
}

/// Bekleyen hatırlatmalar yalnızca açık oturumun durumuna göre yeniden kurulur (önce hepsi silinir).
@MainActor
enum WatchReminders {
    private static let longBreakId = "fokus.watch.longbreak"
    private static let goalId = "fokus.watch.goal"

    /// İlk oturum başlarken bir kez sorar; reddedilirse sessizce yalnızca uygulama içi geri bildirim kalır.
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    static func sync(live: FocusLink.LiveState?, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [longBreakId, goalId])
        if let due = FocusLink.longBreakReminder(live, now: now) {
            schedule(
                id: longBreakId, title: "Molan uzadı", body: "Hazır olduğunda devam et.", at: due, now: now)
        }
        if let due = FocusLink.goalReachedDate(live, now: now) {
            schedule(
                id: goalId, title: "Günlük hedef tamam", body: "Bugünkü odak hedefine ulaştın.", at: due, now: now)
        }
    }

    private static func schedule(id: String, title: String, body: String, at due: Date, now: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, due.timeIntervalSince(now)), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
