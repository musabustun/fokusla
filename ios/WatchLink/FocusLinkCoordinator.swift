import FokusData
import FokusDomain
import Foundation
import Observation
import SwiftData

/// iPhone ↔ saat anlık odak eşitlemesi (iki hedefe de derlenir). Depo tek doğruluk kaynağıdır; bu sınıf
/// (1) yerel durumu `FocusLink.Broadcast` olarak karşı cihaza yollar, (2) karşıdan gelen bildirimi
/// `remote` olarak tutar (depoya YAZILMAZ — çift kayıt oluşmasın), (3) oturum karşı cihazdayken
/// pause/resume/finish komutunu iletir ya da gelen komutu yerel depoda uygular.
/// Karar kuralları saf ve testlidir: `FokusDomain/FocusLink`.
@MainActor
@Observable
final class FocusLinkCoordinator {
    static let shared = FocusLinkCoordinator()

    /// Karşı cihazın son bildirimi (bellekte; uygulama açılınca bağlamdan yeniden okunur).
    private(set) var remote: FocusLink.Broadcast?
    /// Uzak bildirim ya da komut sonucu ekranın yenilenmesi gerektiğinde çağrılır.
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private let transport = FocusLinkTransport()
    @ObservationIgnored private var isStarted = false

    struct LocalView {
        var live: FocusLink.LiveState?
        /// Depodaki son odak değişikliği (`updatedAt` en büyüğü); hiç kayıt yoksa `.distantPast`.
        var stamp: Date
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        transport.onBroadcast = { [weak self] broadcast in
            self?.remote = broadcast
            self?.onChange?()
        }
        transport.onCommand = { [weak self] command in await self?.receive(command) ?? false }
        transport.onActivated = { [weak self] in self?.publish() }
        transport.activate()
    }

    // MARK: - Durum

    func localView(now: Date = .now) throws -> LocalView {
        let snapshot = try FokusSystem.snapshot(now: now)
        let live = snapshot.activeSessionId.flatMap { id in
            snapshot.activity.map {
                FocusLink.LiveState(sessionId: id, state: $0, subjectName: snapshot.activeSubjectLabel)
            }
        }
        return LocalView(live: live, stamp: try latestChange())
    }

    /// Ekranda gösterilecek açık oturum: yerel depo ile uzak bildirimden yeni olan.
    func resolvedLive(now: Date = .now) -> FocusLink.LiveState? {
        guard let view = try? localView(now: now) else { return nil }
        return FocusLink.resolve(local: view.live, localStamp: view.stamp, remote: remote, now: now)
    }

    private func latestChange() throws -> Date {
        let context = try FokusSystem.context()
        var sessions = FetchDescriptor<FocusSession>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        sessions.fetchLimit = 1
        var segments = FetchDescriptor<FocusSegment>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        segments.fetchLimit = 1
        let latest = [try context.fetch(sessions).first?.updatedAt, try context.fetch(segments).first?.updatedAt]
        return latest.compactMap { $0 }.max() ?? .distantPast
    }

    // MARK: - Gönderme / komut

    /// Yerel durumu karşı cihaza bildirir (yerel her değişiklikten sonra çağrılır).
    func publish(now: Date = .now) {
        guard let view = try? localView(now: now) else { return }
        transport.send(FocusLink.Broadcast(stamp: view.stamp, live: view.live))
    }

    /// Kullanıcının gördüğü oturuma komut: yerel depoda açıksa yerelde uygular, değilse karşı cihaza iletir.
    @discardableResult
    func perform(_ kind: FocusLink.Command.Kind, now: Date = .now) async -> Bool {
        guard let view = try? localView(now: now),
            let live = FocusLink.resolve(local: view.live, localStamp: view.stamp, remote: remote, now: now)
        else { return false }
        let command = FocusLink.Command(kind: kind, sessionId: live.sessionId, at: now)
        let handled: Bool
        switch FocusLink.route(commandFor: live.sessionId, localActiveSessionId: view.live?.sessionId) {
        case .applyLocally:
            handled = apply(command, at: now)
            publish(now: now)
        case .forwardToPeer:
            handled = await transport.send(command)
        }
        onChange?()
        return handled
    }

    /// Karşı cihazdan gelen komut: oturum burada açıksa uygulanır (başarı yanıtı döner).
    private func receive(_ command: FocusLink.Command) -> Bool {
        let now = Date.now
        guard let view = try? localView(now: now), view.live?.sessionId == command.sessionId else { return false }
        let handled = apply(command, at: FocusLink.effectiveTime(of: command, received: now))
        publish(now: now)
        onChange?()
        return handled
    }

    private func apply(_ command: FocusLink.Command, at now: Date) -> Bool {
        do {
            let repository = FocusRepository(context: try FokusSystem.context())
            switch command.kind {
            case .pause: try repository.pause(sessionId: command.sessionId, now: now)
            case .resume: try repository.resume(sessionId: command.sessionId, now: now)
            case .finish: try repository.finish(sessionId: command.sessionId, now: now)
            }
            FokusSystem.reloadWidgets()
            return true
        } catch {
            return false
        }
    }
}
