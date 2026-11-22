import Foundation

/// `MockSocialService`'in kalıcılık soyutlaması (web `KeyValueStorage`). Hiçbir işlem fırlatmaz.
public protocol SocialStorage: Sendable {
    func load() -> Data?
    func save(_ data: Data)
    func clear()
}

/// `UserDefaults` üzerinde tek anahtarlı depo (üretim).
public final class UserDefaultsSocialStorage: SocialStorage, @unchecked Sendable {
    public static let defaultKey = "fokus.social.mock.v1"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = UserDefaultsSocialStorage.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> Data? { defaults.data(forKey: key) }
    public func save(_ data: Data) { defaults.set(data, forKey: key) }
    public func clear() { defaults.removeObject(forKey: key) }
}

/// Bellek içi depo (testler / önizleme). NSLock ile iş parçacığı güvenlidir.
public final class InMemorySocialStorage: SocialStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?

    public init(data: Data? = nil) {
        self.data = data
    }

    public func load() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return data
    }

    public func save(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        self.data = data
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        data = nil
    }
}
