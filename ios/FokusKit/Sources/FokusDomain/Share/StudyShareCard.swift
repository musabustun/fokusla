import Foundation

/// "Bugün şu kadar çalıştım" kartının verisi. Mesajın bağlantısında taşınır
/// (`fokus://study?v=1&d=…&f=<dk>&g=<hedef dk>&s=<dk>,<ders>&k=<seri>&n=<ad>`); sunucu yoktur.
/// Yalnızca kullanıcının seçtiği alanlar dolu gelir; türetilmiş değer saklanmaz, bağlantıdan yeniden çizilir.
public struct StudyShareCard: Equatable, Sendable {
    public struct SubjectShare: Equatable, Sendable {
        public var name: String
        public var minutes: Int

        public init(name: String, minutes: Int) {
            self.name = name
            self.minutes = minutes
        }
    }

    /// Kullanıcının kartta göstermeyi seçebildiği ek alanlar (toplam süre her zaman vardır).
    public struct Fields: OptionSet, Sendable, Equatable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let goal = Fields(rawValue: 1 << 0)
        public static let subjects = Fields(rawValue: 1 << 1)
        public static let streak = Fields(rawValue: 1 << 2)
        public static let all: Fields = [.goal, .subjects, .streak]
        /// Varsayılan seçim: toplam süre + hedef halkası.
        public static let `default`: Fields = [.goal]
    }

    public static let maxSubjects = 3
    public static let maxMinutes = 24 * 60
    public static let maxStreakDays = 3650

    /// Yerel takvim günü.
    public var day: ISODate
    public var focusMinutes: Int
    public var goalMinutes: Int?
    public var subjects: [SubjectShare]
    public var streakDays: Int?
    public var name: String?

    public init(
        day: ISODate, focusMinutes: Int, goalMinutes: Int? = nil, subjects: [SubjectShare] = [],
        streakDays: Int? = nil, name: String? = nil
    ) {
        self.day = day
        self.focusMinutes = focusMinutes
        self.goalMinutes = goalMinutes
        self.subjects = subjects
        self.streakDays = streakDays
        self.name = name
    }

    /// Hedef halkası oranı (0–1); hedef paylaşılmıyorsa `nil`.
    public var goalRatio: Double? {
        guard let goalMinutes, goalMinutes > 0 else { return nil }
        return Swift.min(1, Double(focusMinutes) / Double(goalMinutes))
    }

    /// Mesaj özeti (Messages'ta balonun altında, erişilebilirlik ve eski cihazlarda yedek metin).
    public var summaryText: String {
        guard focusMinutes > 0 else { return "Bugün henüz çalışmadım" }
        return "Bugün \(SocialFormat.formatDurationShort(Double(focusMinutes) * 60_000)) çalıştım"
    }

    // MARK: - Bağlantı

    public var url: URL {
        var items: [(String, String)] = [
            ("v", String(ShareLink.version)), ("d", day), ("f", String(focusMinutes)),
        ]
        if let goalMinutes { items.append(("g", String(goalMinutes))) }
        for subject in subjects.prefix(Self.maxSubjects) {
            items.append(("s", "\(subject.minutes),\(subject.name)"))
        }
        if let streakDays { items.append(("k", String(streakDays))) }
        if let name { items.append(("n", name)) }
        return ShareLink.makeURL(host: "study", items: items)
    }

    /// Dışarıdan gelen bağlantıdan kartı çözer; geçersiz zorunlu alan → hata, geçersiz isteğe bağlı alan → yok sayılır.
    public init(url: URL) throws {
        let items = try ShareLink.parse(url, host: "study")
        func first(_ key: String) -> String? { items.first { $0.key == key }?.value }
        guard let day = first("d"), ShareLink.isValidDay(day) else { throw ShareLinkError.invalid("d") }
        guard let focus = first("f").flatMap(Int.init), (0...Self.maxMinutes).contains(focus) else {
            throw ShareLinkError.invalid("f")
        }
        var subjects: [SubjectShare] = []
        for item in items where item.key == "s" && subjects.count < Self.maxSubjects {
            let pieces = item.value.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard pieces.count == 2, let minutes = Int(pieces[0]), (1...Self.maxMinutes).contains(minutes),
                let name = ShareLink.sanitizedName(String(pieces[1]), maxLength: ShareLink.subjectNameMaxLength)
            else { continue }
            subjects.append(SubjectShare(name: name, minutes: minutes))
        }
        self.init(
            day: day, focusMinutes: focus,
            goalMinutes: first("g").flatMap(Int.init).flatMap { DailyGoalCalc.options.contains($0) ? $0 : nil },
            subjects: subjects,
            streakDays: first("k").flatMap(Int.init).flatMap { (1...Self.maxStreakDays).contains($0) ? $0 : nil },
            name: first("n").flatMap { ShareLink.sanitizedName($0) })
    }
}

/// Kartı depo anlık görüntülerinden üreten SAF hesap (`Date()` çağrılmaz).
public enum StudyShareCalc {
    /// Oturum + ders bağı (anlık görüntüde ders yok; ders dökümü için gerekir).
    public struct Session: Sendable, Equatable {
        public var snapshot: FocusSessionSnapshot
        public var subjectId: UUID?

        public init(snapshot: FocusSessionSnapshot, subjectId: UUID?) {
            self.snapshot = snapshot
            self.subjectId = subjectId
        }
    }

    /// Seri için en fazla geriye bakılan gün sayısı.
    public static let streakLookbackDays = 366
    private static let minuteMs = 60_000.0

    public static func card(
        sessions: [Session], segments: [FocusSegmentSnapshot], subjectNames: [UUID: String],
        goalMinutes: Int?, displayName: String?, fields: StudyShareCard.Fields, now: Date,
        calendar: Calendar = .current
    ) -> StudyShareCard {
        let snapshots = sessions.map(\.snapshot)
        let today = Identifiers.isoDate(now, calendar: calendar)
        let totalMs =
            (try? FocusCalc.dailyFocusTotalMs(
                sessions: snapshots, segments: segments, day: today, now: now, calendar: calendar)) ?? 0
        return StudyShareCard(
            day: today,
            focusMinutes: minutes(totalMs),
            goalMinutes: fields.contains(.goal) ? DailyGoalCalc.normalized(goalMinutes) : nil,
            subjects: fields.contains(.subjects)
                ? subjectBreakdown(
                    sessions: sessions, segments: segments, names: subjectNames, day: today, now: now,
                    calendar: calendar)
                : [],
            streakDays: fields.contains(.streak)
                ? streak(sessions: snapshots, segments: segments, now: now, calendar: calendar).flatMap {
                    $0 > 0 ? $0 : nil
                } : nil,
            name: displayName.flatMap { ShareLink.sanitizedName($0) })
    }

    private static func minutes(_ ms: Double) -> Int {
        ms.isFinite && ms > 0 ? Int((ms / minuteMs).rounded(.down)) : 0
    }

    /// Bugünün en çok çalışılan dersleri (en çok `maxSubjects`), süre azalan, eşitlikte ada göre.
    static func subjectBreakdown(
        sessions: [Session], segments: [FocusSegmentSnapshot], names: [UUID: String], day: ISODate, now: Date,
        calendar: Calendar
    ) -> [StudyShareCard.SubjectShare] {
        let grouped = Dictionary(grouping: sessions.filter { $0.subjectId != nil }, by: { $0.subjectId! })
        let rows: [StudyShareCard.SubjectShare] = grouped.compactMap { subjectId, group in
            guard let name = names[subjectId].flatMap({
                ShareLink.sanitizedName($0, maxLength: ShareLink.subjectNameMaxLength)
            }) else { return nil }
            let ms =
                (try? FocusCalc.dailyFocusTotalMs(
                    sessions: group.map(\.snapshot), segments: segments, day: day, now: now,
                    calendar: calendar)) ?? 0
            let value = minutes(ms)
            return value > 0 ? StudyShareCard.SubjectShare(name: name, minutes: value) : nil
        }
        return Array(
            rows.sorted { $0.minutes != $1.minutes ? $0.minutes > $1.minutes : $0.name < $1.name }
                .prefix(StudyShareCard.maxSubjects))
    }

    /// Art arda çalışılan gün sayısı (günde en az 1 dk odak). Bugün henüz çalışılmadıysa dünden sayılır.
    static func streak(
        sessions: [FocusSessionSnapshot], segments: [FocusSegmentSnapshot], now: Date, calendar: Calendar
    ) -> Int? {
        let days: [ISODate] = (0..<streakLookbackDays).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: now).map { Identifiers.isoDate($0, calendar: calendar) }
        }
        guard
            let totals = try? FocusCalc.dailyFocusTotals(
                sessions: sessions, segments: segments, days: days, now: now, calendar: calendar)
        else { return nil }
        let startIndex = (totals.first?.focusMs ?? 0) >= minuteMs ? 0 : 1
        var count = 0
        for total in totals.dropFirst(startIndex) {
            guard total.focusMs >= minuteMs else { break }
            count += 1
        }
        return count
    }
}
