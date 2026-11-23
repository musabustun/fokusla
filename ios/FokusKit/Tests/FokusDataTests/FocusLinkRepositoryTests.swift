import FokusDomain
import Foundation
import SwiftData
import Testing

@testable import FokusData

// Saat ↔ telefon kayıt eşlemesi: iki ayrı bellek içi depo = iki cihaz.

@MainActor
struct FocusLinkRepositoryTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let watch: ModelContext
    private let phone: ModelContext

    init() throws {
        watch = ModelContext(try FokusStore.makeInMemoryContainer())
        phone = ModelContext(try FokusStore.makeInMemoryContainer())
    }

    private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

    /// `from` deposundaki değişiklikleri `to` deposuna taşır (WC'nin yaptığı iş).
    @discardableResult
    private func ship(from: ModelContext, to: ModelContext, lastSent: Date? = nil, now: Date) throws -> Int {
        let batch = try FocusLinkRepository(context: from).outgoing(lastSent: lastSent, echo: [:], now: now)
        return try FocusLinkRepository(context: to).apply(batch, now: now)
    }

    @Test("telefon yokken saatte başlat-mola-devam-bitir: telefon gelince oturum ve segmentler birebir görünür")
    func offlineWatchSessionArrivesOnPhone() throws {
        let watchRepo = FocusRepository(context: watch)
        let session = try watchRepo.start(now: at(0))
        try watchRepo.pause(sessionId: session.id, now: at(25))
        try watchRepo.resume(sessionId: session.id, now: at(30))
        try watchRepo.finish(sessionId: session.id, now: at(55))

        #expect(try ship(from: watch, to: phone, now: at(60)) == 4)

        let phoneRepo = FocusRepository(context: phone)
        let phoneSegments = try phoneRepo.segments(forSession: session.id)
        #expect(phoneSegments.map(\.kind) == [.focus, .break, .focus])
        #expect(phoneSegments.map(\.linkRecord) == (try watchRepo.segments(forSession: session.id)).map(\.linkRecord))
        let stats = try #require(try phoneRepo.finish(sessionId: session.id, now: at(70)))
        #expect(stats.focusMs == 50 * 60_000)
        #expect(try phoneRepo.findActive() == nil)
    }

    @Test("aynı küme iki kez gelirse (kuyruk tekrarı) sonuç değişmez")
    func idempotent() throws {
        let session = try FocusRepository(context: watch).start(now: at(0))
        let batch = try FocusLinkRepository(context: watch).outgoing(lastSent: nil, echo: [:], now: at(1))
        let link = FocusLinkRepository(context: phone)
        #expect(try link.apply(batch, now: at(1)) == 2)
        #expect(try link.apply(batch, now: at(2)) == 0)
        #expect(try EntityStore<FocusSession>(context: phone).all().map(\.id) == [session.id])
        #expect(try EntityStore<FocusSegment>(context: phone).all().count == 1)
    }

    @Test("telefonda başlatılan oturuma saatten mola: telefon molayı görür (canlı kontrol)")
    func watchPausesPhoneSession() throws {
        let session = try FocusRepository(context: phone).start(now: at(0))
        try ship(from: phone, to: watch, now: at(0.1))
        try FocusRepository(context: watch).pause(sessionId: session.id, now: at(20))
        try ship(from: watch, to: phone, lastSent: at(0.1), now: at(20))

        let segments = try FocusRepository(context: phone).segments(forSession: session.id)
        #expect(segments.map(\.kind) == [.focus, .break])
        #expect(segments[0].endedAt == at(20) && segments[1].endedAt == nil)
    }

    @Test("bağlantısızken iki cihazda başlatma: birleşince tek açık oturum kalır")
    func conflictingStarts() throws {
        let watchSession = try FocusRepository(context: watch).start(now: at(0))
        let phoneSession = try FocusRepository(context: phone).start(now: at(10))
        try ship(from: watch, to: phone, now: at(15))

        let phoneRepo = FocusRepository(context: phone)
        #expect(try phoneRepo.findActive()?.id == phoneSession.id)
        let closed = try #require(try EntityStore<FocusSession>(context: phone).find(id: watchSession.id))
        #expect(closed.endedAt == at(10) && closed.updatedAt == at(15))
        #expect(try phoneRepo.segments(forSession: watchSession.id).allSatisfy { $0.endedAt == at(10) })

        // Onarım da geri gider: saat aynı sonuca varır.
        try ship(from: phone, to: watch, now: at(16))
        #expect(try FocusRepository(context: watch).findActive()?.id == phoneSession.id)
    }

    @Test("silme (tombstone) karşıya taşınır; eski sürüm yenisini ezmez")
    func tombstoneAndStaleUpdate() throws {
        let session = try FocusRepository(context: phone).start(now: at(0))
        try FocusRepository(context: phone).finish(sessionId: session.id, now: at(30))
        let stale = try FocusLinkRepository(context: phone).outgoing(lastSent: nil, echo: [:], now: at(30))
        let store = EntityStore<FocusSession>(context: phone)
        let local = try #require(try store.find(id: session.id))
        store.softDelete(local, now: at(40))
        try store.save()
        try ship(from: phone, to: watch, now: at(41))
        #expect(try EntityStore<FocusSession>(context: watch).all().isEmpty)

        // Gecikmiş eski küme gelir: silinmiş kaydı diriltmez.
        #expect(try FocusLinkRepository(context: watch).apply(stale, now: at(42)) == 0)
        #expect(try EntityStore<FocusSession>(context: watch).all().isEmpty)
    }

    @Test("gönderim: yalnızca son gönderimden sonra değişenler; ders adları yalnızca kullanılanlar")
    func outgoingSelection() throws {
        let subject = UUID()
        let repo = FocusRepository(context: phone)
        let first = try repo.start(subjectId: subject, now: at(0))
        try repo.finish(sessionId: first.id, now: at(10))
        let second = try repo.start(now: at(20))
        let batch = try FocusLinkRepository(context: phone).outgoing(
            lastSent: at(15), echo: [:], subjectNames: [subject: "TYT Matematik", UUID(): "Başka"], now: at(21))
        #expect(batch.sessions.map(\.id) == [second.id])
        #expect(batch.segments.count == 1)
        #expect(batch.subjectNames.isEmpty)

        let all = try FocusLinkRepository(context: phone).outgoing(
            lastSent: nil, echo: [:], subjectNames: [subject: "TYT Matematik"], now: at(21))
        #expect(all.subjectNames == [subject: "TYT Matematik"])
    }
}
