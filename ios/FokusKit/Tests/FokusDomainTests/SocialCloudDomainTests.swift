import Foundation
import Testing

@testable import FokusDomain

@Suite("SocialDirectory / SocialMailCrypto / SocialContentFilter")
struct SocialCloudDomainTests {
    @Test("özet kararlıdır, adı içermez ve adlar arasında ayrışır")
    func claimKey() {
        let key = SocialDirectory.claimKey(forUsername: "elif.say")
        #expect(key == SocialDirectory.claimKey(forUsername: "elif.say"))
        #expect(key != SocialDirectory.claimKey(forUsername: "elif_say"))
        #expect(key.hasPrefix("u1-"))
        #expect(key.count == 3 + 64)
        #expect(!key.contains("elif"))
    }

    @Test("mektubu yalnız alıcı, yalnız kendi kutusunda açabilir")
    func sealAndOpen() throws {
        let recipient = SocialMailCrypto.generatePrivateKey()
        let stranger = SocialMailCrypto.generatePrivateKey()
        let message = Data("davet".utf8)
        let sealed = try SocialMailCrypto.seal(
            message, publicKey: SocialMailCrypto.publicKey(forPrivateKey: recipient), mailbox: "kutu-1")

        #expect(try SocialMailCrypto.open(sealed, privateKey: recipient, mailbox: "kutu-1") == message)
        #expect(sealed.range(of: message) == nil)
        #expect(throws: SocialMailCrypto.Failure.invalidMessage) {
            try SocialMailCrypto.open(sealed, privateKey: stranger, mailbox: "kutu-1")
        }
        #expect(throws: SocialMailCrypto.Failure.invalidMessage) {
            try SocialMailCrypto.open(sealed, privateKey: recipient, mailbox: "kutu-2")
        }
    }

    @Test("bozuk anahtar ve bozuk mektup hata verir")
    func malformed() {
        let key = SocialMailCrypto.generatePrivateKey()
        #expect(throws: SocialMailCrypto.Failure.invalidKey) {
            try SocialMailCrypto.seal(Data(), publicKey: Data([1, 2]), mailbox: "k")
        }
        #expect(throws: SocialMailCrypto.Failure.invalidKey) {
            try SocialMailCrypto.publicKey(forPrivateKey: Data([1]))
        }
        #expect(throws: SocialMailCrypto.Failure.invalidMessage) {
            try SocialMailCrypto.open(Data([1, 2, 3]), privateKey: key, mailbox: "k")
        }
    }

    @Test("süzgeç tam kelimeye bakar", arguments: [
        ("klasik.muzik", true), ("elif_say", true), ("Sabah kampı", true), ("", true),
        ("sik_123", false), ("PİÇ oda", false), ("a.amk", false),
    ])
    func filter(text: String, ok: Bool) {
        #expect(SocialContentFilter.isAcceptable(text) == ok)
    }
}

@Suite("SocialCalc: yayın ve gün dönümü")
struct SocialCalcCloudTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }()
    /// 2026-11-24 00:00 İstanbul.
    private static let midnight = calendar.date(from: DateComponents(year: 2026, month: 11, day: 24))!

    private func presence(_ state: PresenceState, at date: Date, today: Double = 60_000, expires: Date? = nil)
        -> SocialPresence {
        SocialPresence(
            state: state, sessionStartedAt: date, stateSince: date, todayFocusMs: today, updatedAt: date,
            expiresAt: expires)
    }

    @Test("odakta ve molada geçerlilik süresi yazılır, çevrimdışıyken yazılmaz")
    func publishing() {
        let at = Self.midnight
        let expected = at.addingTimeInterval(3 * 3600)
        #expect(SocialCalc.presenceForPublishing(presence(.focusing, at: at)).expiresAt == expected)
        #expect(SocialCalc.presenceForPublishing(presence(.onBreak, at: at)).expiresAt == expected)
        #expect(SocialCalc.presenceForPublishing(presence(.offline, at: at, expires: at)).expiresAt == nil)
    }

    @Test("expiresAt 10 dk kuralının önüne geçer")
    func expiry() {
        let at = Self.midnight
        let live = presence(.focusing, at: at, expires: at.addingTimeInterval(3 * 3600))
        #expect(SocialCalc.effectivePresenceState(live, now: at.addingTimeInterval(2 * 3600)) == .focusing)
        #expect(SocialCalc.effectivePresenceState(live, now: at.addingTimeInterval(3 * 3600)) == .focusing)
        #expect(SocialCalc.effectivePresenceState(live, now: at.addingTimeInterval(3 * 3600 + 1)) == .offline)
        let legacy = presence(.focusing, at: at)
        #expect(SocialCalc.effectivePresenceState(legacy, now: at.addingTimeInterval(601)) == .offline)
    }

    @Test("bugün yayınlanan durum değişmez")
    func sameDay() {
        let value = presence(.focusing, at: Self.midnight)
        #expect(SocialCalc.presenceForToday(value, now: Self.midnight.addingTimeInterval(60), calendar: Self.calendar) == value)
    }

    @Test("dünkü toplam bugüne sayılmaz")
    func yesterdayOffline() {
        let value = presence(.offline, at: Self.midnight.addingTimeInterval(-3600))
        let today = SocialCalc.presenceForToday(value, now: Self.midnight.addingTimeInterval(60), calendar: Self.calendar)
        #expect(today.todayFocusMs == 0)
        #expect(today.updatedAt == value.updatedAt)
    }

    @Test("gece yarısını geçen odakta bugünkü süre 00:00'dan ilerler")
    func acrossMidnight() {
        let at = Self.midnight.addingTimeInterval(-600)
        let now = Self.midnight.addingTimeInterval(1200)
        let value = presence(.focusing, at: at, expires: at.addingTimeInterval(3 * 3600))
        let today = SocialCalc.presenceForToday(value, now: now, calendar: Self.calendar)
        #expect(SocialCalc.liveTodayFocusMs(today, now: now) == 1_200_000)
        #expect(today.sessionStartedAt == at)
    }

    @Test("expiresAt'siz dünkü odak eski bayatlama anını korur")
    func acrossMidnightLegacy() {
        let at = Self.midnight.addingTimeInterval(-300)
        let today = SocialCalc.presenceForToday(
            presence(.focusing, at: at), now: Self.midnight.addingTimeInterval(400), calendar: Self.calendar)
        #expect(today.expiresAt == at.addingTimeInterval(600))
        #expect(SocialCalc.effectivePresenceState(today, now: Self.midnight.addingTimeInterval(400)) == .offline)
    }
}
