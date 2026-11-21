import Foundation

/// Görev hesapları — SAF fonksiyonlar (SwiftUI/SwiftData yok). Web `web/src/domain/calc/tasks.ts`
/// karşılığı; "Bugün" ekranı ve Görevler modülü bunları kullanır.
///
/// Ortak kurallar (web ile birebir aynıdır):
///  - `Date()` çağrılmaz; gün her zaman `day`/`today` (`ISODate`, YEREL takvim günü) parametresidir.
///  - Gün aritmetiği ve hafta günü `ISODate` → `ISODate` olarak, saat diliminden bağımsız (saf
///    takvim hesabı) yapılır; DST'den etkilenmez.
///  - `Date` → yerel gün dönüşümü (`createdAt`, `completedAt`) verilen `calendar` ile yapılır
///    (varsayılan `.current`); testlerde `calendar` ile saat dilimi sabitlenir.
///  - `deletedAt != nil` olan görev ve tamamlamalar her fonksiyonda yok sayılır.
///  - Aynı (görev, gün) için birden çok silinmemiş tamamlama olabilir (CloudKit): tek sayılır.
///  - Girdi dizileri değiştirilmez; yeni diziler döner. Sıralamalar kararlıdır (eşitlikte girdi sırası).
///  - Geçersiz `ISODate` girdisinin sonucu tanımsızdır (web'de `NaN`); hesaplar bunu doğrulamaz.
public enum TasksCalc {
    /// Seri/oran penceresi: son 7 gün (bugün dahil).
    public static let completionRateWindowDays = 7
    /// "Yaklaşan" ödevler: bugünden sonraki bu kadar gün içinde son tarihi olanlar.
    public static let upcomingHorizonDays = 7

    /// Bir günün görev gündemi. Her grup kendi içinde sıralıdır.
    public struct DayAgenda: Sendable, Equatable {
        /// O gün planlı rutinler (`order`, sonra `title` tr-TR).
        public var routines: [TaskSnapshot]
        /// `dueDate < day`: açık olanlar + o gün tamamlananlar (`dueDate` artan).
        public var overdue: [TaskSnapshot]
        /// `dueDate == day` ya da `dueDate == nil`: açık olanlar + o gün tamamlananlar.
        /// Önce son tarihi bugün olanlar, sonra tarihsizler (her biri `order`/`title`).
        public var dueToday: [TaskSnapshot]
        /// `day < dueDate <= day + horizonDays`: açık olanlar + o gün tamamlananlar (`dueDate` artan).
        public var upcoming: [TaskSnapshot]

        public init(
            routines: [TaskSnapshot] = [], overdue: [TaskSnapshot] = [],
            dueToday: [TaskSnapshot] = [], upcoming: [TaskSnapshot] = []
        ) {
            self.routines = routines
            self.overdue = overdue
            self.dueToday = dueToday
            self.upcoming = upcoming
        }
    }

    /// Penceredeki tamamlama oranı.
    public struct CompletionRate: Sendable, Equatable {
        /// Penceredeki planlı gün sayısı (başlangıçtan önceki günler hariç).
        public var scheduled: Int
        /// Bunlardan tamamlananların sayısı.
        public var completed: Int
        /// `completed / scheduled` (0–1); planlı gün yoksa `nil`.
        public var rate: Double?

        public init(scheduled: Int, completed: Int, rate: Double?) {
            self.scheduled = scheduled
            self.completed = completed
            self.rate = rate
        }
    }

    // MARK: - Gün aritmetiği

    /// `YYYY-MM-DD` → (yıl, ay, gün). Ayrıştırılamayan parça yok sayılıp epoch'un (1970-01-01) karşılığı
    /// kullanılır; geçerli girdi doğrulaması çağıranın işidir (bkz. `TaskDraft`).
    static func civilDate(of day: ISODate) -> (year: Int, month: Int, day: Int) {
        let parts = day.split(separator: "-", omittingEmptySubsequences: false).map { Int($0) }
        func part(_ index: Int, fallback: Int) -> Int {
            (parts.indices.contains(index) ? parts[index] : nil) ?? fallback
        }
        return (part(0, fallback: 1970), part(1, fallback: 1), part(2, fallback: 1))
    }

    /// Epoch'tan (1970-01-01) beri gün sayısı (proleptik Gregoryen; Howard Hinnant algoritması).
    private static func epochDays(_ day: ISODate) -> Int {
        let (year, month, date) = civilDate(of: day)
        let shiftedYear = month <= 2 ? year - 1 : year
        let era = floorDivide(shiftedYear, 400)
        let yearOfEra = shiftedYear - era * 400
        let dayOfYear = (153 * (month > 2 ? month - 3 : month + 9) + 2) / 5 + date - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    /// Aşağı yuvarlayan tamsayı bölme (negatif sayılarda da doğru).
    private static func floorDivide(_ dividend: Int, _ divisor: Int) -> Int {
        Int((Double(dividend) / Double(divisor)).rounded(.down))
    }

    /// `epochDays`'in tersi: epoch'tan beri gün sayısı → `YYYY-MM-DD`.
    private static func isoDate(epochDays days: Int) -> ISODate {
        let shifted = days + 719_468
        let era = floorDivide(shifted, 146_097)
        let dayOfEra = shifted - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let monthIndex = (5 * dayOfYear + 2) / 153
        let date = dayOfYear - (153 * monthIndex + 2) / 5 + 1
        let month = monthIndex < 10 ? monthIndex + 3 : monthIndex - 9
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
        return String(format: "%04d-%02d-%02d", year, month, date)
    }

    /// ISO hafta günü (1 = Pazartesi … 7 = Pazar). Saat diliminden bağımsız.
    public static func weekday(of day: ISODate) -> Int {
        // 1970-01-01 Perşembe'dir (ISO 4).
        ((epochDays(day) % 7) + 7 + 3) % 7 + 1
    }

    /// `day`'e `amount` gün ekler (negatif olabilir); ay/yıl/artık yıl geçişlerini doğru yapar.
    public static func addDays(_ day: ISODate, _ amount: Int) -> ISODate {
        isoDate(epochDays: epochDays(day) + amount)
    }

    /// `to − from` gün farkı (`to < from` ise negatif).
    public static func daysBetween(from: ISODate, to: ISODate) -> Int {
        epochDays(to) - epochDays(from)
    }

    // MARK: - Sıralama

    /// `order`, sonra `title` (tr-TR).
    private static func isOrderedByOrderThenTitle(_ a: TaskSnapshot, _ b: TaskSnapshot) -> Bool? {
        if a.order != b.order { return a.order < b.order }
        let result = a.title.compare(b.title, locale: Locale(identifier: "tr_TR"))
        return result == .orderedSame ? nil : result == .orderedAscending
    }

    /// `dueDate` artan (`nil` en sonda), sonra `order`, sonra `title` (tr-TR).
    private static func isOrderedByDueDate(_ a: TaskSnapshot, _ b: TaskSnapshot) -> Bool? {
        switch (a.dueDate, b.dueDate) {
        case let (dueA?, dueB?) where dueA != dueB: return dueA < dueB
        case (nil, .some): return false
        case (.some, nil): return true
        default: return isOrderedByOrderThenTitle(a, b)
        }
    }

    /// Kararlı sıralama: karşılaştırıcı `nil` (eşit) dönerse girdi sırası korunur.
    private static func stableSorted(
        _ tasks: [TaskSnapshot], by areOrdered: (TaskSnapshot, TaskSnapshot) -> Bool?
    ) -> [TaskSnapshot] {
        tasks.enumerated().sorted { lhs, rhs in
            areOrdered(lhs.element, rhs.element) ?? (lhs.offset < rhs.offset)
        }.map(\.element)
    }

    // MARK: - Tekrar kuralı ve planlama

    /// Kural bu günde tekrar ediyor mu? `daily` → her gün. `weekly` → `weekdays` içeriyorsa;
    /// `weekly` + boş `weekdays` (ya da bilinmeyen sıklık) → hiçbir gün.
    public static func isDue(_ rule: RecurrenceRule, on day: ISODate) -> Bool {
        switch rule.frequencyValue {
        case .daily: true
        case .weekly: rule.weekdays.contains(weekday(of: day))
        case nil: false
        }
    }

    /// Rutinin başladığı yerel gün: `startDate` varsa o, yoksa `createdAt`'in yerel günü.
    public static func routineStartDate(_ task: TaskSnapshot, calendar: Calendar = .current) -> ISODate {
        task.startDate ?? Identifiers.isoDate(task.createdAt, calendar: calendar)
    }

    /// Rutin bu günde planlı mı? rutin + silinmemiş + `recurrence != nil` + `day >= başlangıç günü`
    /// + `isDue`. Ödevler için her zaman `false`.
    public static func isScheduled(
        _ task: TaskSnapshot, on day: ISODate, calendar: Calendar = .current
    ) -> Bool {
        guard task.kind == .routine, task.deletedAt == nil, let rule = task.recurrence else {
            return false
        }
        return day >= routineStartDate(task, calendar: calendar) && isDue(rule, on: day)
    }

    // MARK: - Tamamlama

    /// Ödevin tamamlandığı yerel gün (`completedAt`'ten); tamamlanmadıysa veya rutinse `nil`.
    public static func assignmentCompletionDay(
        _ task: TaskSnapshot, calendar: Calendar = .current
    ) -> ISODate? {
        guard task.kind == .assignment, let completedAt = task.completedAt else { return nil }
        return Identifiers.isoDate(completedAt, calendar: calendar)
    }

    /// Rutinin bu güne ait silinmemiş tamamlaması (birden çoksa en erken `completedAt`).
    public static func findCompletion(
        _ completions: [TaskCompletionSnapshot], taskId: UUID, day: ISODate
    ) -> TaskCompletionSnapshot? {
        completions
            .filter { $0.taskId == taskId && $0.date == day && $0.deletedAt == nil }
            .reduce(nil) { (earliest: TaskCompletionSnapshot?, completion) in
                guard let earliest else { return completion }
                return completion.completedAt < earliest.completedAt ? completion : earliest
            }
    }

    /// Görev o gün tamamlanmış sayılır mı?
    /// - rutin: o güne ait silinmemiş tamamlama var.
    /// - ödev: `completedAt != nil` ve tamamlanma günü `<= day` (o güne kadar bitirilmiş).
    /// - silinmiş görev: `false`.
    public static func isCompleted(
        _ task: TaskSnapshot, completions: [TaskCompletionSnapshot], on day: ISODate,
        calendar: Calendar = .current
    ) -> Bool {
        guard task.deletedAt == nil else { return false }
        if task.kind == .routine {
            return findCompletion(completions, taskId: task.id, day: day) != nil
        }
        guard let completionDay = assignmentCompletionDay(task, calendar: calendar) else {
            return false
        }
        return completionDay <= day
    }

    // MARK: - Ödev son tarihleri

    /// Ödev gecikmiş mi? ödev + silinmemiş + tamamlanmamış + `dueDate != nil` + `dueDate < today`.
    public static func isOverdue(_ task: TaskSnapshot, today: ISODate) -> Bool {
        guard task.kind == .assignment, task.deletedAt == nil, task.completedAt == nil,
            let dueDate = task.dueDate
        else { return false }
        return dueDate < today
    }

    /// Ödevleri son tarihe göre sıralar (`nil` en sonda; eşitlikte `order`, sonra `title` tr-TR).
    public static func sortedByDueDate(_ tasks: [TaskSnapshot]) -> [TaskSnapshot] {
        stableSorted(tasks, by: isOrderedByDueDate)
    }

    /// Geciken ödevler, en eski son tarih önce (eşitlikte `order`, sonra `title` tr-TR).
    public static func overdueAssignments(_ tasks: [TaskSnapshot], today: ISODate) -> [TaskSnapshot] {
        stableSorted(tasks.filter { isOverdue($0, today: today) }, by: isOrderedByDueDate)
    }

    /// Son tarihe kalan gün (`dueDate − today`; geçmişse negatif). Ödev değilse/`dueDate` yoksa `nil`.
    public static func daysUntilDue(_ task: TaskSnapshot, today: ISODate) -> Int? {
        guard task.kind == .assignment, let dueDate = task.dueDate else { return nil }
        return daysBetween(from: today, to: dueDate)
    }

    // MARK: - Gündem

    /// Günün gündemi ("Bugün" görünümü). Ödev, (açık ve gündem aralığında) VEYA (tamamlanma günü
    /// == `day`) ise dahil edilir — o gün tamamlanan ödev listede kalır ve geri alınabilir. Daha önceki
    /// bir günde tamamlanmış ödev dahil edilmez. Silinmiş görevler hariç.
    ///
    /// "Açık", `day` itibarıyla değerlendirilir (`isCompleted` ile tutarlı): geçmiş bir gün
    /// görüntülenirken o günden SONRA tamamlanmış ödev o gün için açık sayılır.
    public static func agenda(
        for day: ISODate, tasks: [TaskSnapshot], horizonDays: Int = upcomingHorizonDays,
        calendar: Calendar = .current
    ) -> DayAgenda {
        let horizonEnd = addDays(day, horizonDays)
        var routines: [TaskSnapshot] = []
        var overdue: [TaskSnapshot] = []
        var dueToday: [TaskSnapshot] = []
        var upcoming: [TaskSnapshot] = []

        for task in tasks {
            if task.kind == .routine {
                if isScheduled(task, on: day, calendar: calendar) { routines.append(task) }
                continue
            }
            guard task.deletedAt == nil, isVisible(task, on: day, calendar: calendar) else { continue }
            guard let due = task.dueDate else { dueToday.append(task); continue }
            if due == day {
                dueToday.append(task)
            } else if due < day {
                overdue.append(task)
            } else if due <= horizonEnd {
                upcoming.append(task)
            }
        }

        return DayAgenda(
            routines: stableSorted(routines, by: isOrderedByOrderThenTitle),
            overdue: stableSorted(overdue, by: isOrderedByDueDate),
            dueToday: stableSorted(dueToday, by: isOrderedByDueDate),
            upcoming: stableSorted(upcoming, by: isOrderedByDueDate))
    }

    /// Ödev bu günün gündeminde görünür mü? `day` itibarıyla açık (henüz tamamlanmamış ya da daha
    /// SONRAKİ bir günde tamamlanmış) VEYA tam o gün tamamlanmış. Daha önce tamamlanan hariç.
    private static func isVisible(_ task: TaskSnapshot, on day: ISODate, calendar: Calendar) -> Bool {
        guard let completionDay = assignmentCompletionDay(task, calendar: calendar) else { return true }
        return completionDay >= day
    }

    /// Belirli bir gün için gösterilecek görevler: `agenda` gruplarının sırayla birleşimi.
    public static func tasks(
        for day: ISODate, in tasks: [TaskSnapshot], calendar: Calendar = .current
    ) -> [TaskSnapshot] {
        let agenda = agenda(for: day, tasks: tasks, calendar: calendar)
        return agenda.routines + agenda.overdue + agenda.dueToday + agenda.upcoming
    }

    // MARK: - Seri ve oran

    /// Rutin serisi: `today`den geriye doğru, planlı günlerde kesintisiz tamamlama sayısı.
    /// Planlı olmayan günler atlanır (seriyi bozmaz). Bugün planlı ama henüz tamamlanmadıysa seri
    /// BOZULMAZ (bir önceki planlı günden saymaya başlanır). Başlangıç gününden önceye bakılmaz.
    /// Rutin değilse/silinmişse 0.
    public static func routineStreak(
        _ task: TaskSnapshot, completions: [TaskCompletionSnapshot], today: ISODate,
        calendar: Calendar = .current
    ) -> Int {
        guard task.kind == .routine, task.deletedAt == nil, task.recurrence != nil else { return 0 }
        let start = routineStartDate(task, calendar: calendar)
        var streak = 0
        var day = today
        while day >= start {
            defer { day = addDays(day, -1) }
            guard isScheduled(task, on: day, calendar: calendar) else { continue }
            if findCompletion(completions, taskId: task.id, day: day) != nil {
                streak += 1
            } else if day != today {
                break
            }
        }
        return streak
    }

    /// Son `windowDays` gün (bugün dahil: `[today − windowDays + 1, today]`) tamamlama oranı.
    public static func completionRate(
        _ task: TaskSnapshot, completions: [TaskCompletionSnapshot], today: ISODate,
        windowDays: Int = completionRateWindowDays, calendar: Calendar = .current
    ) -> CompletionRate {
        var scheduled = 0
        var completed = 0
        for offset in 0..<Swift.max(0, windowDays) {
            let day = addDays(today, -offset)
            guard isScheduled(task, on: day, calendar: calendar) else { continue }
            scheduled += 1
            if findCompletion(completions, taskId: task.id, day: day) != nil { completed += 1 }
        }
        return CompletionRate(
            scheduled: scheduled, completed: completed,
            rate: scheduled == 0 ? nil : Double(completed) / Double(scheduled))
    }
}
