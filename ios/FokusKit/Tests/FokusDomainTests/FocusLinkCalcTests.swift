import Foundation
import Testing

@testable import FokusDomain

// iPhone ↔ saat anlık eşitleme kuralları. `now` sabit; `Date()` yok.

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let sessionA = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
private let sessionB = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

private func live(
    _ id: UUID = sessionA, phase: FocusActivityCalc.Phase = .focus, since: TimeInterval = -600,
    goal: Int? = nil, dayStart: TimeInterval? = nil
) -> FocusLink.LiveState {
    FocusLink.LiveState(
        sessionId: id,
        state: FocusActivityCalc.State(
            phase: phase, timerStart: now.addingTimeInterval(since),
            sessionFocusStart: now.addingTimeInterval(since),
            dayFocusStart: dayStart.map { now.addingTimeInterval($0) }, goalMinutes: goal),
        subjectName: "TYT Türkçe")
}

@Suite("FocusLink.resolve")
struct FocusLinkResolveTests {
    @Test("uzak bildirim yerel depodan YENİYSE kazanır (telefonda duraklatıldı, CloudKit henüz gelmedi)")
    func remoteNewerWins() {
        let local = live(phase: .focus)
        let remote = FocusLink.Broadcast(stamp: now.addingTimeInterval(-5), live: live(phase: .break, since: -5))
        let result = FocusLink.resolve(
            local: local, localStamp: now.addingTimeInterval(-60), remote: remote, now: now)
        #expect(result?.state.phase == .break)
    }

    @Test("eşit damgada yerel kazanır (CloudKit aynı durumu getirdi)")
    func tieLocalWins() {
        let stamp = now.addingTimeInterval(-5)
        let result = FocusLink.resolve(
            local: live(phase: .break), localStamp: stamp,
            remote: FocusLink.Broadcast(stamp: stamp, live: live(phase: .focus)), now: now)
        #expect(result?.state.phase == .break)
    }

    @Test("yerel daha yeniyse (saatte bitirildi) eski bildirim yok sayılır")
    func localNewerWins() {
        let result = FocusLink.resolve(
            local: nil, localStamp: now.addingTimeInterval(-1),
            remote: FocusLink.Broadcast(stamp: now.addingTimeInterval(-30), live: live()), now: now)
        #expect(result == nil)
    }

    @Test("uzak 'açık oturum yok' bildirimi yereldeki eski açık oturumu kapatır")
    func remoteEndedWins() {
        let result = FocusLink.resolve(
            local: live(), localStamp: now.addingTimeInterval(-300),
            remote: FocusLink.Broadcast(stamp: now.addingTimeInterval(-2), live: nil), now: now)
        #expect(result == nil)
    }

    @Test("bayat bildirim (12 saatten eski) yok sayılır")
    func staleRemoteIgnored() {
        let old = now.addingTimeInterval(-FocusLink.staleAfter - 1)
        let result = FocusLink.resolve(
            local: nil, localStamp: .distantPast,
            remote: FocusLink.Broadcast(stamp: old, live: live()), now: now)
        #expect(result == nil)
    }

    @Test("bildirim yokken yerel durum döner")
    func noRemote() {
        let local = live()
        #expect(FocusLink.resolve(local: local, localStamp: now, remote: nil, now: now) == local)
    }
}

@Suite("FocusLink komut yönlendirme")
struct FocusLinkRouteTests {
    @Test("oturum yerelde açıksa yerelde uygulanır")
    func local() {
        #expect(FocusLink.route(commandFor: sessionA, localActiveSessionId: sessionA) == .applyLocally)
    }

    @Test("oturum yerelde yoksa ya da başkasıysa karşı cihaza iletilir", arguments: [nil, sessionB])
    func forward(localId: UUID?) {
        #expect(FocusLink.route(commandFor: sessionA, localActiveSessionId: localId) == .forwardToPeer)
    }

    @Test("komut zamanı gelecek ve aşırı eski değerlere sıkıştırılır")
    func effectiveTime() {
        let fresh = FocusLink.Command(kind: .pause, sessionId: sessionA, at: now.addingTimeInterval(-3))
        let future = FocusLink.Command(kind: .pause, sessionId: sessionA, at: now.addingTimeInterval(90))
        let old = FocusLink.Command(kind: .pause, sessionId: sessionA, at: now.addingTimeInterval(-3600))
        #expect(FocusLink.effectiveTime(of: fresh, received: now) == now.addingTimeInterval(-3))
        #expect(FocusLink.effectiveTime(of: future, received: now) == now)
        #expect(FocusLink.effectiveTime(of: old, received: now) == now.addingTimeInterval(-FocusLink.commandMaxAge))
    }
}

@Suite("FocusLink dokunsal ipuçları")
struct FocusLinkCueTests {
    @Test("durum geçişi → ipucu")
    func transitions() {
        #expect(FocusLink.cue(from: nil, to: nil) == nil)
        #expect(FocusLink.cue(from: nil, to: live()) == .started)
        #expect(FocusLink.cue(from: live(), to: nil) == .finished)
        #expect(FocusLink.cue(from: live(phase: .focus), to: live(phase: .break)) == .paused)
        #expect(FocusLink.cue(from: live(phase: .break), to: live(phase: .focus)) == .resumed)
        #expect(FocusLink.cue(from: live(), to: live(since: -1)) == nil)
        #expect(FocusLink.cue(from: live(sessionA), to: live(sessionB)) == .started)
    }

    @Test("uzun mola hatırlatması mola başlangıcından 30 dk sonra; süresi dolmuşsa ya da odaktaysa yok")
    func longBreak() {
        let due = FocusLink.longBreakReminder(live(phase: .break, since: -60), now: now)
        #expect(due == now.addingTimeInterval(-60 + 30 * 60))
        #expect(FocusLink.longBreakReminder(live(phase: .break, since: -31 * 60), now: now) == nil)
        #expect(FocusLink.longBreakReminder(live(phase: .focus), now: now) == nil)
        #expect(FocusLink.longBreakReminder(nil, now: now) == nil)
    }

    @Test("hedef zamanı: odakta ve hedef açıkken bugünkü toplamın hedefe varacağı an")
    func goalReached() {
        // Bugün 50 dk odaklandı, hedef 60 dk → 10 dk sonra.
        let state = live(goal: 60, dayStart: -50 * 60)
        #expect(FocusLink.goalReachedDate(state, now: now) == now.addingTimeInterval(10 * 60))
        #expect(FocusLink.goalReachedDate(live(goal: 60, dayStart: -61 * 60), now: now) == nil)
        #expect(FocusLink.goalReachedDate(live(phase: .break, goal: 60, dayStart: -50 * 60), now: now) == nil)
        #expect(FocusLink.goalReachedDate(live(goal: nil), now: now) == nil)
    }
}

@Suite("FocusLink taşıma biçimi")
struct FocusLinkPayloadTests {
    @Test("bildirim ve komut JSON gidiş-dönüşte aynen korunur")
    func roundTrip() throws {
        let broadcast = FocusLink.Broadcast(stamp: now, live: live(goal: 120, dayStart: -900))
        let decoded = FocusLink.broadcast(from: try #require(FocusLink.payload(broadcast)))
        #expect(decoded == broadcast)

        let command = FocusLink.Command(kind: .finish, sessionId: sessionA, at: now)
        #expect(FocusLink.command(from: try #require(FocusLink.payload(command))) == command)

        let ended = FocusLink.Broadcast(stamp: now, live: nil)
        #expect(FocusLink.broadcast(from: try #require(FocusLink.payload(ended))) == ended)
    }

    @Test("bozuk ya da yabancı sözlük çözülmez")
    func invalid() {
        #expect(FocusLink.broadcast(from: [:]) == nil)
        #expect(FocusLink.broadcast(from: [FocusLink.broadcastKey: Data([1, 2, 3])]) == nil)
        #expect(FocusLink.command(from: [FocusLink.broadcastKey: "x"]) == nil)
    }
}
