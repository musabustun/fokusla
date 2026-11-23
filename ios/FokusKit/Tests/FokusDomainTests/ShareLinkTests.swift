import Foundation
import Testing

@testable import FokusDomain

// iMessage paylaşım bağlantıları: çalışma kartı ve oda daveti kodlama/çözme, oda durumu güncelleme.
// Saat dilimi bağımsız (Unix saniyesi); `Date()` çağrılmaz.

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let minute: TimeInterval = 60
private let roomId = UUID(uuidString: "4F2A1B3C-5D6E-47F8-9A0B-1C2D3E4F5A6B")!
private let hostId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
private let guestId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

// MARK: - Ad temizleme

struct ShareNameTests {
    @Test(arguments: [
        ("  Beyza  ", "Beyza"),
        ("Ay  se", "Ay se"),
        ("a\u{0}b\nc", "a b c"),
        ("ÇağlaŞ", "ÇağlaŞ"),
        ("12345678901234567890EXTRA", "12345678901234567890"),
    ] as [(String, String)])
    func sanitizes(input: String, expected: String) {
        #expect(ShareLink.sanitizedName(input) == expected)
    }

    @Test(arguments: ["", "   ", "\n\t", "\u{200B}"])
    func rejectsEmpty(input: String) {
        #expect(ShareLink.sanitizedName(input) == nil)
    }
}

// MARK: - Çalışma kartı

struct StudyShareCardTests {
    private let full = StudyShareCard(
        day: "2026-11-23", focusMinutes: 205, goalMinutes: 240,
        subjects: [.init(name: "Matematik", minutes: 120), .init(name: "Fizik: Optik & Dalga", minutes: 60)],
        streakDays: 5, name: "Beyza")

    @Test func roundTrips() throws {
        let url = full.url
        #expect(url.scheme == "fokus" && url.host == "study")
        #expect(try StudyShareCard(url: url) == full)
    }

    @Test func roundTripsMinimal() throws {
        let card = StudyShareCard(day: "2026-11-23", focusMinutes: 0)
        #expect(try StudyShareCard(url: card.url) == card)
    }

    @Test func summaryTexts() {
        #expect(full.summaryText == "Bugün 3 sa 25 dk çalıştım")
        #expect(StudyShareCard(day: "2026-11-23", focusMinutes: 45).summaryText == "Bugün 45 dk çalıştım")
        #expect(StudyShareCard(day: "2026-11-23", focusMinutes: 0).summaryText == "Bugün henüz çalışmadım")
    }

    @Test func goalRatioIsClampedAndOptional() {
        #expect(full.goalRatio == 205.0 / 240.0)
        var over = full
        over.focusMinutes = 999
        #expect(over.goalRatio == 1)
        #expect(StudyShareCard(day: "2026-11-23", focusMinutes: 30).goalRatio == nil)
    }

    @Test(arguments: [
        "fokus://study?v=2&d=2026-11-23&f=10",  // gelecek sürüm
        "fokus://study?d=2026-11-23&f=10",  // sürüm yok
        "fokus://study?v=1&d=2026-13-40&f=10",  // geçersiz gün
        "fokus://study?v=1&d=2026-11-23",  // süre yok
        "fokus://study?v=1&d=2026-11-23&f=-5",  // negatif
        "fokus://study?v=1&d=2026-11-23&f=99999",  // 24 saatten fazla
        "fokus://room?v=1&d=2026-11-23&f=10",  // yanlış host
        "https://study?v=1&d=2026-11-23&f=10",  // yanlış şema
    ])
    func rejectsInvalid(link: String) {
        #expect(throws: ShareLinkError.self) { try StudyShareCard(url: URL(string: link)!) }
    }

    @Test func decodingIsDefensive() throws {
        let link =
            "fokus://study?v=1&d=2026-11-23&f=60&g=7&k=-3&n=%20%20&s=bozuk&s=30,Ders1&s=30,Ders2&s=30,Ders3&s=30,Ders4&s=0,S%C4%B1f%C4%B1r"
        let card = try StudyShareCard(url: URL(string: link)!)
        #expect(card.goalMinutes == nil)  // 7 dk geçerli hedef değil
        #expect(card.streakDays == nil)  // negatif seri yok sayılır
        #expect(card.name == nil)  // boş ad
        #expect(card.subjects.map(\.name) == ["Ders1", "Ders2", "Ders3"])  // bozuk/sıfır atılır, en çok 3
    }

    @Test func subjectNameWithCommaSurvives() throws {
        let card = StudyShareCard(
            day: "2026-11-23", focusMinutes: 60, subjects: [.init(name: "Tarih, Coğrafya", minutes: 60)])
        #expect(try StudyShareCard(url: card.url).subjects.first?.name == "Tarih, Coğrafya")
    }
}

// MARK: - Çalışma kartı hesabı

struct StudyShareCalcTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }

    private func local(_ day: Int, _ hour: Int, _ minuteValue: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minuteValue))!
    }

    private func make(
        _ name: String, subject: UUID?, day: Int, from startHour: Int, minutes: Int
    ) -> (StudyShareCalc.Session, FocusSegmentSnapshot) {
        let id = Identifiers.uuidV5(name: name, namespace: Identifiers.catalogNamespace)
        let start = local(day, startHour)
        let end = start.addingTimeInterval(Double(minutes) * 60)
        return (
            .init(snapshot: FocusSessionSnapshot(id: id, startedAt: start, endedAt: end), subjectId: subject),
            FocusSegmentSnapshot(
                id: Identifiers.uuidV5(name: name + "-seg", namespace: Identifiers.catalogNamespace),
                sessionId: id, kind: .focus, startedAt: start, endedAt: end)
        )
    }

    private let math = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    private let physics = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
    private let names: [UUID: String] = [
        UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!: "Matematik",
        UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!: "Fizik",
    ]

    @Test func buildsTodayTotalGoalSubjectsAndStreak() {
        let rows = [
            make("a", subject: math, day: 23, from: 9, minutes: 90),
            make("b", subject: physics, day: 23, from: 12, minutes: 30),
            make("c", subject: nil, day: 23, from: 15, minutes: 20),
            make("d", subject: math, day: 22, from: 10, minutes: 40),
            make("e", subject: math, day: 21, from: 10, minutes: 40),
            make("f", subject: math, day: 19, from: 10, minutes: 40),  // 20'si boş: seri 21'de kırılır
        ]
        let card = StudyShareCalc.card(
            sessions: rows.map(\.0), segments: rows.map(\.1), subjectNames: names, goalMinutes: 240,
            displayName: "Beyza", fields: [.goal, .subjects, .streak], now: local(23, 20), calendar: calendar)
        #expect(card.day == "2026-11-23")
        #expect(card.focusMinutes == 140)
        #expect(card.goalMinutes == 240)
        #expect(card.subjects == [.init(name: "Matematik", minutes: 90), .init(name: "Fizik", minutes: 30)])
        #expect(card.streakDays == 3)
        #expect(card.name == "Beyza")
    }

    @Test func unselectedFieldsAreLeftOut() {
        let rows = [make("a", subject: math, day: 23, from: 9, minutes: 60)]
        let card = StudyShareCalc.card(
            sessions: rows.map(\.0), segments: rows.map(\.1), subjectNames: names, goalMinutes: 120,
            displayName: "Beyza", fields: [], now: local(23, 20), calendar: calendar)
        #expect(card.focusMinutes == 60)
        #expect(card.goalMinutes == nil && card.subjects.isEmpty && card.streakDays == nil)
    }

    @Test func streakContinuesFromYesterdayWhenTodayIsEmpty() {
        let rows = [
            make("a", subject: nil, day: 22, from: 9, minutes: 30), make("b", subject: nil, day: 21, from: 9, minutes: 30),
        ]
        let card = StudyShareCalc.card(
            sessions: rows.map(\.0), segments: rows.map(\.1), subjectNames: [:], goalMinutes: nil,
            displayName: nil, fields: [.streak], now: local(23, 8), calendar: calendar)
        #expect(card.focusMinutes == 0)
        #expect(card.streakDays == 2)
        #expect(card.name == nil)
    }

    @Test func noStudyMeansNoStreakAndNoGoalWithoutSetting() {
        let card = StudyShareCalc.card(
            sessions: [], segments: [], subjectNames: [:], goalMinutes: nil, displayName: "  ",
            fields: [.goal, .subjects, .streak], now: local(23, 8), calendar: calendar)
        #expect(card.focusMinutes == 0)
        #expect(card.goalMinutes == nil && card.streakDays == nil && card.name == nil)
    }

    @Test func subjectsAreSortedAndCappedAtThree() {
        let ids = (0..<5).map { UUID(uuidString: "00000000-0000-0000-0000-00000000010\($0)")! }
        let rows = ids.enumerated().map {
            make("s\($0.offset)", subject: $0.element, day: 23, from: 8 + $0.offset, minutes: 10 * ($0.offset + 1))
        }
        let names = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($0.element, "D\($0.offset)") })
        let card = StudyShareCalc.card(
            sessions: rows.map(\.0), segments: rows.map(\.1), subjectNames: names, goalMinutes: nil,
            displayName: nil, fields: [.subjects], now: local(23, 20), calendar: calendar)
        #expect(card.subjects.map(\.name) == ["D4", "D3", "D2"])
    }
}

// MARK: - Oda daveti

struct RoomInviteTests {
    private func invite(participants: [RoomInvite.Participant]? = nil) -> RoomInvite {
        RoomInvite(
            id: roomId, startsAt: now.addingTimeInterval(10 * minute), durationMinutes: 50,
            participants: participants ?? [.init(id: hostId, name: "Beyza")])
    }

    @Test func roundTrips() throws {
        let value = invite(participants: [.init(id: hostId, name: "Beyza"), .init(id: guestId, name: "Ali, Veli & Co")])
        let url = value.url
        #expect(url.scheme == "fokus" && url.host == "room")
        #expect(try RoomInvite(url: url) == value)
    }

    @Test func urlStaysSmallWithFullRoom() {
        let people = (0..<RoomInvite.maxParticipants).map { _ in
            RoomInvite.Participant(id: UUID(), name: String(repeating: "Ğ", count: 20))
        }
        #expect(invite(participants: people).url.absoluteString.utf8.count < 2000)
    }

    @Test func hostIsFirstParticipant() {
        let value = invite(participants: [.init(id: hostId, name: "Beyza"), .init(id: guestId, name: "Ali")])
        #expect(value.host?.id == hostId)
        #expect(invite(participants: []).host == nil)
    }

    // MARK: Katılma (değişmez güncelleme)

    @Test func joinAppendsAndDoesNotMutateOriginal() {
        let original = invite()
        let result = original.joining(.init(id: guestId, name: "Ali"), now: now)
        guard case .joined(let updated) = result else {
            Issue.record("katılmalıydı")
            return
        }
        #expect(updated.participants.map(\.name) == ["Beyza", "Ali"])
        #expect(original.participants.count == 1)
    }

    @Test func joiningTwiceRenamesInsteadOfDuplicating() {
        let first = invite(participants: [.init(id: hostId, name: "Beyza"), .init(id: guestId, name: "Ali")])
        guard case .alreadyJoined(let updated) = first.joining(.init(id: guestId, name: "Ali K."), now: now) else {
            Issue.record("zaten katılmış olmalıydı")
            return
        }
        #expect(updated.participants.map(\.name) == ["Beyza", "Ali K."])
    }

    @Test func fullRoomRejectsNewcomers() {
        let people = (0..<RoomInvite.maxParticipants).map { RoomInvite.Participant(id: UUID(), name: "K\($0)") }
        let full = invite(participants: people)
        #expect(full.joining(.init(id: guestId, name: "Geç"), now: now) == .full)
        // Mevcut katılımcı tam odada da adını güncelleyebilir.
        if case .alreadyJoined = full.joining(.init(id: people[3].id, name: "Yeni"), now: now) {
        } else {
            Issue.record("güncellemeliydi")
        }
    }

    @Test func joiningAfterEndIsRejected() {
        let value = invite()
        let late = value.startsAt.addingTimeInterval(50 * minute + 1)
        #expect(value.joining(.init(id: guestId, name: "Ali"), now: late) == .ended)
    }

    // MARK: Faz (oda `now + 10 dk`da başlar, 50 dk sürer)

    @Test(arguments: [
        (-5.0, RoomInvite.Phase.upcoming(secondsLeft: 15 * 60)),
        (0.0, .upcoming(secondsLeft: 10 * 60)),
        (10.0, .live(secondsLeft: 50 * 60)),
        (35.0, .live(secondsLeft: 25 * 60)),
        (60.0, .ended),
        (120.0, .ended),
    ] as [(Double, RoomInvite.Phase)])
    func phase(minutesFromNow: Double, expected: RoomInvite.Phase) {
        #expect(invite().phase(now: now.addingTimeInterval(minutesFromNow * minute)) == expected)
    }

    // MARK: Kodlama sertliği

    private static let goodId = "4F2A1B3C-5D6E-47F8-9A0B-1C2D3E4F5A6B"
    private static let goodPerson = "11111111-2222-3333-4444-555555555555,Beyza"

    @Test(arguments: [
        "fokus://room?v=1&id=bozuk&t=1800000600&m=50&p=\(goodPerson)",
        "fokus://room?v=1&id=\(goodId)&m=50&p=\(goodPerson)",  // başlangıç yok
        "fokus://room?v=1&id=\(goodId)&t=1800000600&m=5&p=\(goodPerson)",  // çok kısa
        "fokus://room?v=1&id=\(goodId)&t=1800000600&m=500&p=\(goodPerson)",  // çok uzun
        "fokus://room?v=1&id=\(goodId)&t=1800000600&m=50",  // katılımcı yok
        "fokus://room?v=9&id=\(goodId)&t=1800000600&m=50&p=\(goodPerson)",  // gelecek sürüm
        "fokus://study?v=1&id=\(goodId)&t=1800000600&m=50&p=\(goodPerson)",  // yanlış host
    ])
    func rejectsInvalid(link: String) {
        #expect(throws: ShareLinkError.self) { try RoomInvite(url: URL(string: link)!) }
    }

    @Test func decodingDropsBadParticipantsAndCapsCount() throws {
        var link =
            "fokus://room?v=1&id=\(Self.goodId)&t=1800000600&m=50&p=\(Self.goodPerson)&p=k%C3%B6t%C3%BC,Ali&p=11111111-2222-3333-4444-555555555555,Kopya"
        for _ in 0..<20 { link += "&p=\(UUID().uuidString),Ek" }
        let decoded = try RoomInvite(url: URL(string: link)!)
        #expect(decoded.participants.count == RoomInvite.maxParticipants)
        #expect(decoded.participants.first?.name == "Beyza")
        #expect(Set(decoded.participants.map(\.id)).count == decoded.participants.count)
    }

    @Test func summaryTexts() {
        #expect(invite().summaryText == "Beyza ile 50 dk birlikte çalışalım")
        let two = invite(participants: [.init(id: hostId, name: "Beyza"), .init(id: guestId, name: "Ali")])
        #expect(two.summaryText == "Beyza, Ali · 50 dk ortak odak")
        #expect(invite(participants: []).summaryText == "50 dk ortak odak")
    }

    @Test func durationOptionsAreValid() {
        #expect(RoomInvite.durationOptions.allSatisfy { RoomInvite.durationRange.contains($0) })
        #expect(RoomInvite.durationOptions.contains(50))
    }
}
