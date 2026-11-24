import FokusDomain
import Foundation

/// UI testleri ve önizleme için: aynı sahte sunucuda, GERÇEK `CloudSocialService` kurallarıyla yaşayan birkaç
/// örnek kişi. Ağ yoktur; Release'te kullanılmaz.
///  - `elif.say`: gelen istekleri kabul eder, odaktadır, "Sabah kampı" odasının sahibidir.
///  - `zeynep2027`: kullanıcı adımı alınca bana istek gönderir.
@MainActor
public final class SocialDemoWorld {
    /// Kullanıcının servisi.
    public let service: CloudSocialService
    private let elif: CloudSocialService
    private let zeynep: CloudSocialService
    private var loop: Task<Void, Never>?
    private var didZeynepAsk = false

    public init(sessionProvider: @escaping @MainActor () async -> String?, pollMs: Int = 1000) {
        let server = InMemorySocialServer()
        func make(_ user: String, _ session: @escaping @MainActor () async -> String?) -> CloudSocialService {
            CloudSocialService(
                sessionProvider: session, cloud: InMemorySocialCloud(userId: user, server: server), pollMs: pollMs)
        }
        service = make("ben", sessionProvider)
        elif = make("elif", { "elif" })
        zeynep = make("zeynep", { "zeynep" })
    }

    /// Örnek kişileri hazırlar ve küçük bir döngüyle yaşatır.
    public func start(step: Duration = .milliseconds(500)) {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            await self?.prepare()
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(for: step)
            }
        }
    }

    public func stop() {
        loop?.cancel()
        loop = nil
    }

    public func prepare() async {
        for (person, name) in [(elif, "elif.say"), (zeynep, "zeynep2027")] where person.snapshot.status != .ready {
            await person.refresh()
            _ = try? await person.claimUsername(name)
        }
        let now = Date()
        try? await elif.publishPresence(SocialPresence(
            state: .focusing, sessionStartedAt: now.addingTimeInterval(-1500), stateSince: now.addingTimeInterval(-1500),
            todayFocusMs: 5_400_000, updatedAt: now))
        if elif.snapshot.room == nil { _ = try? await elif.createRoom(name: "Sabah kampı") }
    }

    public func tick() async {
        await elif.refresh()
        for request in elif.snapshot.requests where request.direction == .incoming {
            try? await elif.respondToRequest(id: request.id, accept: true)
        }
        guard !didZeynepAsk, let username = service.snapshot.profile?.username else { return }
        didZeynepAsk = (try? await zeynep.sendFriendRequest(.username(username))) != nil
    }
}
