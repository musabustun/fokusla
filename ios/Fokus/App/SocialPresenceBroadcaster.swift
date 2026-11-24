import FokusData
import FokusDomain
import Foundation
import OSLog
import SwiftData
import UIKit

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "social")

/// Kendi odak durumumu sosyal servise yayınlar: veri kaydedilince (başla/mola/devam/bitir; Live Activity, Siri ve
/// saat dahil) ve ön plandayken ~60 sn'de bir. Odak verisini YALNIZCA OKUR. Giriş yoksa, profil hazır değilse ya da
/// "Sosyalde görün" kapalıysa servis hiçbir şey paylaşmaz.
@MainActor
final class SocialPresenceBroadcaster {
    static let shared = SocialPresenceBroadcaster()

    private static let heartbeat: Duration = .seconds(60)
    private static let debounce: Duration = .milliseconds(800)

    private var service: (any SocialService)?
    private var container: ModelContainer?
    private var loop: Task<Void, Never>?
    private var pending: Task<Void, Never>?
    private var lastKey: String?

    func start(service: any SocialService, container: ModelContainer) {
        guard self.service == nil else { return }
        self.service = service
        self.container = container
        NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { SocialPresenceBroadcaster.shared.dataDidChange() }
        }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.publish()
                try? await Task.sleep(for: Self.heartbeat)
            }
        }
    }

    /// Ön plana gelince arkadaşların ve kabul edilen davetlerin güncel hâlini çeker.
    func sceneDidBecomeActive() {
        guard let service, service.snapshot.status != .loading else { return }
        Task {
            await service.refresh()
            await publish()
        }
    }

    private func dataDidChange() {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled, let self, let presence = self.currentPresence() else { return }
            let key = SocialOwnPresence.changeKey(presence)
            guard key != self.lastKey else { return }
            await self.publishInBackgroundTask()
        }
    }

    /// Kayıt arka planda geldiyse (kilit ekranından bitirme) ağ isteğinin tamamlanması için süre ister.
    private func publishInBackgroundTask() async {
        let application = UIApplication.shared
        var taskId = UIBackgroundTaskIdentifier.invalid
        taskId = application.beginBackgroundTask(withName: "social-presence") {
            application.endBackgroundTask(taskId)
            taskId = .invalid
        }
        await publish()
        if taskId != .invalid { application.endBackgroundTask(taskId) }
    }

    private func publish() async {
        guard let service else { return }
        switch service.snapshot.status {
        case .loading, .unreachable: await service.refresh()
        default: break
        }
        guard service.snapshot.status == .ready, let presence = currentPresence() else { return }
        do {
            try await service.publishPresence(presence)
            lastKey = SocialOwnPresence.changeKey(presence)
        } catch {
            // Bir sonraki kalp atışı yeniden dener.
            logger.error("Durum yayınlanamadı: \(String(describing: error), privacy: .public)")
        }
    }

    private func currentPresence(now: Date = .now) -> SocialPresence? {
        guard let container else { return nil }
        do {
            return try SocialOwnPresence.load(context: container.mainContext, now: now)
        } catch {
            logger.error("Odak kayıtları okunamadı: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
