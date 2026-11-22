import Foundation

@testable import FokusData

/// Testler için elle ilerletilen sahte zamanlayıcı (web'deki `vi.useFakeTimers` karşılığı).
/// `advance(milliseconds:)` vadesi gelen eylemleri sırayla, deterministik çalıştırır.
@MainActor
final class ManualSocialScheduler: SocialScheduler {
    private struct Entry {
        let id: Int
        var dueMs: Int
        let intervalMs: Int?
        let action: @MainActor () -> Void
    }

    private var entries: [Entry] = []
    private var nextId = 0
    private(set) var currentMs = 0

    /// Etkin (iptal edilmemiş, henüz çalışmamış/tekrarlayan) zamanlayıcı sayısı.
    var pendingCount: Int { entries.count }

    func after(milliseconds: Int, _ action: @escaping @MainActor () -> Void) -> SocialCancellable {
        add(dueIn: milliseconds, interval: nil, action)
    }

    func every(milliseconds: Int, _ action: @escaping @MainActor () -> Void) -> SocialCancellable {
        add(dueIn: milliseconds, interval: milliseconds, action)
    }

    private func add(
        dueIn milliseconds: Int, interval: Int?, _ action: @escaping @MainActor () -> Void
    ) -> SocialCancellable {
        let id = nextId
        nextId += 1
        entries.append(Entry(id: id, dueMs: currentMs + milliseconds, intervalMs: interval, action: action))
        return SocialCancellable { [weak self] in self?.entries.removeAll { $0.id == id } }
    }

    func advance(milliseconds: Int) {
        let target = currentMs + milliseconds
        while let next = entries.filter({ $0.dueMs <= target }).min(by: { ($0.dueMs, $0.id) < ($1.dueMs, $1.id) }) {
            currentMs = next.dueMs
            if let interval = next.intervalMs, interval > 0 {
                if let index = entries.firstIndex(where: { $0.id == next.id }) { entries[index].dueMs += interval }
            } else {
                entries.removeAll { $0.id == next.id }
            }
            next.action()
        }
        currentMs = target
    }
}
