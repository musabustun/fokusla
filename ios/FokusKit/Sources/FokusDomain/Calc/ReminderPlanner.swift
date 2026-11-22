import Foundation

/// Günün saati (yerel). Hatırlatma saati seçimi için.
public struct ReminderTime: Codable, Sendable, Hashable {
    public var hour: Int
    public var minute: Int

    /// Aralık dışı değerler 0–23 / 0–59'a sıkıştırılır.
    public init(hour: Int, minute: Int = 0) {
        self.hour = Swift.min(Swift.max(hour, 0), 23)
        self.minute = Swift.min(Swift.max(minute, 0), 59)
    }

    /// Gece yarısından beri dakika (0–1439).
    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public init(minutesSinceMidnight total: Int) {
        let clamped = Swift.min(Swift.max(total, 0), 24 * 60 - 1)
        self.init(hour: clamped / 60, minute: clamped % 60)
    }

    /// "08:05".
    public var text: String { String(format: "%02d:%02d", hour, minute) }

    public static let routineDefault = ReminderTime(hour: 8, minute: 0)
    public static let studyDefault = ReminderTime(hour: 19, minute: 0)
}

/// Kullanıcının hatırlatma tercihleri (cihaza özel; UserDefaults'ta saklanır, senkronlanmaz).
public struct ReminderSettings: Codable, Sendable, Equatable {
    public var routineEnabled: Bool
    public var routineTime: ReminderTime
    public var studyEnabled: Bool
    public var studyTime: ReminderTime

    public init(
        routineEnabled: Bool = false, routineTime: ReminderTime = .routineDefault,
        studyEnabled: Bool = false, studyTime: ReminderTime = .studyDefault
    ) {
        self.routineEnabled = routineEnabled
        self.routineTime = routineTime
        self.studyEnabled = studyEnabled
        self.studyTime = studyTime
    }

    /// En az bir hatırlatma açık mı?
    public var isAnyEnabled: Bool { routineEnabled || studyEnabled }
}

/// Hatırlatma türü.
public enum ReminderKind: String, Sendable, Equatable, CaseIterable {
    case routine, study
}

/// Planlanmış tek bir yerel bildirim (saf değer; `NotificationService` bunu sisteme yazar).
public struct PlannedReminder: Sendable, Equatable, Identifiable {
    /// `fokus.reminder.<tür>.<gün>` — aynı gün/tür için tekildir.
    public var id: String
    public var kind: ReminderKind
    /// Bildirimin düşeceği yerel gün (`ISODate`).
    public var day: ISODate
    public var time: ReminderTime
    public var title: String
    public var body: String

    public init(id: String, kind: ReminderKind, day: ISODate, time: ReminderTime, title: String, body: String) {
        self.id = id
        self.kind = kind
        self.day = day
        self.time = time
        self.title = title
        self.body = body
    }
}

/// Hatırlatma zamanlama hesapları — SAF (`Date()` çağrılmaz; `now` parametre).
///
/// Bildirim metni tarihe bağlı olduğundan (o günkü rutin sayısı, hedef) tekrarlayan tetikleyici
/// yerine önümüzdeki `horizonDays` gün için tek seferlik bildirimler planlanır; uygulama açıldığında
/// ve ilgili veri değiştiğinde yeniden planlanır.
public enum ReminderPlanner {
    /// Önümüzdeki kaç günün (bugün dahil) planlanacağı. iOS'un 64 bekleyen bildirim sınırının altındadır.
    public static let horizonDays = 7
    /// Fokus'un bildirim kimlikleri bu önekle başlar (yalnızca bunlar temizlenir).
    public static let identifierPrefix = "fokus.reminder."

    public static func identifier(kind: ReminderKind, day: ISODate) -> String {
        "\(identifierPrefix)\(kind.rawValue).\(day)"
    }

    /// Her gün için O GÜN planlı rutin sayısı. `today` için yalnızca henüz tamamlanmamış olanlar sayılır
    /// (hepsi bittiyse 0 → bildirim planlanmaz).
    public static func routineCounts(
        tasks: [TaskSnapshot], completions: [TaskCompletionSnapshot], days: [ISODate],
        today: ISODate, calendar: Calendar = .current
    ) -> [ISODate: Int] {
        var counts: [ISODate: Int] = [:]
        for day in days {
            let scheduled = tasks.filter { TasksCalc.isScheduled($0, on: day, calendar: calendar) }
            counts[day] = day == today
                ? scheduled.filter { !TasksCalc.isCompleted($0, completions: completions, on: day, calendar: calendar) }.count
                : scheduled.count
        }
        return counts
    }

    /// Planlanacak bildirimler (kronolojik, aynı saatte önce rutin).
    /// - Geçmişte kalan saatler atlanır (`fire <= now`).
    /// - Rutin: o gün sayı 0 ise planlanmaz.
    /// - Çalışma: bugün için hedefe ulaşıldıysa planlanmaz (iptal anlamına gelir; diğer günler etkilenmez).
    public static func plan(
        settings: ReminderSettings, now: Date, calendar: Calendar = .current,
        goalMinutes: Int?, focusMsToday: Double, routineCounts: [ISODate: Int],
        horizonDays: Int = horizonDays
    ) -> [PlannedReminder] {
        guard settings.isAnyEnabled, horizonDays > 0 else { return [] }
        let today = Identifiers.isoDate(now, calendar: calendar)
        let goal = DailyGoalCalc.normalized(goalMinutes)
        var result: [PlannedReminder] = []

        for offset in 0..<horizonDays {
            let day = TasksCalc.addDays(today, offset)
            if settings.routineEnabled,
                let count = routineCounts[day], count > 0,
                isUpcoming(day: day, time: settings.routineTime, now: now, calendar: calendar)
            {
                result.append(PlannedReminder(
                    id: identifier(kind: .routine, day: day), kind: .routine, day: day,
                    time: settings.routineTime, title: "Rutin hatırlatması", body: routineBody(count: count)))
            }
            let goalReachedToday = day == today && DailyGoalCalc.isReached(focusMs: focusMsToday, goalMinutes: goal)
            if settings.studyEnabled, !goalReachedToday,
                isUpcoming(day: day, time: settings.studyTime, now: now, calendar: calendar)
            {
                result.append(PlannedReminder(
                    id: identifier(kind: .study, day: day), kind: .study, day: day,
                    time: settings.studyTime, title: "Çalışma zamanı", body: studyBody(goalMinutes: goal)))
            }
        }
        return result.sorted { ($0.day, $0.time.minutesSinceMidnight) < ($1.day, $1.time.minutesSinceMidnight) }
    }

    /// "Bugün 1 rutinin var." / "Bugün 3 rutinin var."
    public static func routineBody(count: Int) -> String { "Bugün \(count) rutinin var." }

    /// "Bugünkü hedefin: 3 saat 30 dk" (hedef kapalıysa genel çağrı).
    public static func studyBody(goalMinutes: Int?) -> String {
        guard let goalMinutes else { return "Bir odak oturumu başlatmaya ne dersin?" }
        return "Bugünkü hedefin: \(DailyGoalCalc.goalText(minutes: goalMinutes))"
    }

    /// Gün + saat `now`'dan SONRA mı? (DST'de var olmayan saat takvim tarafından ileri alınır.)
    private static func isUpcoming(day: ISODate, time: ReminderTime, now: Date, calendar: Calendar) -> Bool {
        guard let fire = fireDate(day: day, time: time, calendar: calendar) else { return false }
        return fire > now
    }

    /// Günün yerel saatteki tetik anı.
    public static func fireDate(day: ISODate, time: ReminderTime, calendar: Calendar = .current) -> Date? {
        let civil = TasksCalc.civilDate(of: day)
        return calendar.date(from: DateComponents(
            year: civil.year, month: civil.month, day: civil.day, hour: time.hour, minute: time.minute))
    }
}
