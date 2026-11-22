import Foundation

/// İptal edilebilir zamanlayıcı tutamacı. `cancel()` tekrar çağrılabilir (idempotent).
@MainActor
public final class SocialCancellable {
    private var onCancel: (@MainActor () -> Void)?

    public init(onCancel: @escaping @MainActor () -> Void = {}) {
        self.onCancel = onCancel
    }

    public var isCancelled: Bool { onCancel == nil }

    public func cancel() {
        let handler = onCancel
        onCancel = nil
        handler?()
    }
}

/// `MockSocialService`'in zamanlayıcı soyutlaması (web'deki `setTimeout`/`setInterval` karşılığı).
/// Üretimde `TaskSocialScheduler`; testlerde elle ilerletilen bir sahte zamanlayıcı kullanılır.
@MainActor
public protocol SocialScheduler {
    /// `milliseconds` sonra `action`'ı bir kez çalıştırır.
    func after(milliseconds: Int, _ action: @escaping @MainActor () -> Void) -> SocialCancellable
    /// Her `milliseconds`'te bir `action`'ı çalıştırır (iptal edilene dek).
    func every(milliseconds: Int, _ action: @escaping @MainActor () -> Void) -> SocialCancellable
}

/// `Task` + `Task.sleep` tabanlı üretim zamanlayıcısı.
@MainActor
public struct TaskSocialScheduler: SocialScheduler {
    public init() {}

    public func after(
        milliseconds: Int, _ action: @escaping @MainActor () -> Void
    ) -> SocialCancellable {
        let task = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(max(0, milliseconds)))
            guard !Task.isCancelled else { return }
            action()
        }
        return SocialCancellable { task.cancel() }
    }

    public func every(
        milliseconds: Int, _ action: @escaping @MainActor () -> Void
    ) -> SocialCancellable {
        // Sıfır/negatif aralık sıkı döngüye yol açardı; hiçbir şey çalıştırma.
        guard milliseconds > 0 else { return SocialCancellable() }
        let task = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(milliseconds))
                guard !Task.isCancelled else { return }
                action()
            }
        }
        return SocialCancellable { task.cancel() }
    }
}
