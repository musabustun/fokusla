import Foundation

/// iPhone ↔ Apple Watch ANLIK odak eşitlemesinin SAF sözleşmesi ve karar kuralları (Foundation dışında
/// bağımlılık yok; taşıma katmanı `WatchConnectivity` uygulama hedeflerindedir, bkz. `ios/WatchLink`).
///
/// Kalıcı veri tek kaynaktan akar: SwiftData + CloudKit (iPhone ve saat AYNI container'ı, AYNI modelleri
/// kullanır). CloudKit saniyeler sürebilir; bu yüzden telefon/saat her yerel değişiklikten sonra "bir an"
/// bildirimi (`Broadcast`) yollar. Bildirim ASLA depoya yazılmaz (aynı `id`'li çift kayıt oluşmasın);
/// yalnızca alıcı tarafın EKRANINDA, CloudKit henüz getirmediği durumu gösteren geçici bir katmandır.
/// Karar `resolve` ile verilir: yerel depo ile bildirim arasında DAHA YENİ olan kazanır; eşitlikte yerel.
public enum FocusLink {
    /// Bir andaki açık oturum (ekran için yeterli en küçük bilgi).
    public struct LiveState: Codable, Sendable, Equatable {
        public var sessionId: UUID
        public var state: FocusActivityCalc.State
        public var subjectName: String?

        public init(sessionId: UUID, state: FocusActivityCalc.State, subjectName: String? = nil) {
            self.sessionId = sessionId
            self.state = state
            self.subjectName = subjectName
        }
    }

    /// "Şu an durum bu" bildirimi. `live == nil` → açık oturum yok (bitti / hiç başlamadı).
    /// `stamp`: göndericinin deposundaki son değişikliğin zamanı (`updatedAt` en büyüğü).
    public struct Broadcast: Codable, Sendable, Equatable {
        public var stamp: Date
        public var live: LiveState?

        public init(stamp: Date, live: LiveState?) {
            self.stamp = stamp
            self.live = live
        }
    }

    /// Karşı cihazdaki oturumu BİTİR komutu (saatte "Bitir"; yalnızca oturum yerel depoda henüz YOKKEN
    /// gönderilir — başlatmak her zaman yerel yazmadır).
    public struct Command: Codable, Sendable, Equatable {
        public var sessionId: UUID
        /// Kullanıcının dokunduğu an; alıcı bunu `now` olarak kullanır (gecikme süreyi bozmasın).
        public var at: Date

        public init(sessionId: UUID, at: Date) {
            self.sessionId = sessionId
            self.at = at
        }
    }

    // MARK: - Karar

    /// Bu süreden eski bildirim yok sayılır (kapanıp açılan cihazda bayat katman kalmasın).
    public static let staleAfter: TimeInterval = 12 * 3600

    /// Ekranda gösterilecek durum. Yerel depo (`local`, son değişiklik `localStamp`) ile uzak bildirim
    /// karşılaştırılır; bildirim yalnızca STRİKT daha yeniyse ve bayat değilse kazanır.
    public static func resolve(
        local: LiveState?, localStamp: Date, remote: Broadcast?, now: Date
    ) -> LiveState? {
        guard let remote, remote.stamp > localStamp,
            now.timeIntervalSince(remote.stamp) < staleAfter
        else { return local }
        return remote.live
    }

    /// Komutun nereye gideceği: oturum yerel depoda açıksa yerelde uygula; değilse karşı cihaza ilet.
    public enum Route: Sendable, Equatable { case applyLocally, forwardToPeer }

    public static func route(commandFor sessionId: UUID, localActiveSessionId: UUID?) -> Route {
        localActiveSessionId == sessionId ? .applyLocally : .forwardToPeer
    }

    /// Alıcıda komutun uygulanacağı an: gönderenin anı, ama ASLA gelecekte değil (saat farkı) ve
    /// aşırı eski değil (kuyrukta bekleyen komut süreyi şişirmesin).
    public static let commandMaxAge: TimeInterval = 30

    public static func effectiveTime(of command: Command, received now: Date) -> Date {
        let floor = now.addingTimeInterval(-commandMaxAge)
        return Swift.min(Swift.max(command.at, floor), now)
    }

    // MARK: - Dokunsal geri bildirim

    public enum Cue: Sendable, Equatable {
        case started, paused, resumed, finished
    }

    /// Görünen durum değişince çalınacak ipucu (uzaktan gelen değişiklik de bileği titretsin).
    /// Değişiklik yoksa `nil`. Oturum kimliği değişirse yeni oturum başladı sayılır.
    public static func cue(from old: LiveState?, to new: LiveState?) -> Cue? {
        switch (old, new) {
        case (nil, nil): return nil
        case (nil, .some): return .started
        case (.some, nil): return .finished
        case let (.some(old), .some(new)):
            if old.sessionId != new.sessionId { return .started }
            switch (old.state.phase, new.state.phase) {
            case (.focus, .break): return .paused
            case (.break, .focus): return .resumed
            default: return nil
            }
        }
    }

    // MARK: - Taşıma biçimi (WCSession sözlüğü)

    public static let broadcastKey = "fokus.link.broadcast"
    public static let commandKey = "fokus.link.command"

    /// WCSession mesajı/bağlamı yalnızca property-list değerleri taşır: JSON `Data` tek anahtarda.
    public static func payload(_ broadcast: Broadcast) -> [String: Any]? {
        encode(broadcast, key: broadcastKey)
    }

    public static func payload(_ command: Command) -> [String: Any]? {
        encode(command, key: commandKey)
    }

    public static func broadcast(from payload: [String: Any]) -> Broadcast? {
        decode(Broadcast.self, from: payload, key: broadcastKey)
    }

    public static func command(from payload: [String: Any]) -> Command? {
        decode(Command.self, from: payload, key: commandKey)
    }

    private static func encode<T: Encodable>(_ value: T, key: String) -> [String: Any]? {
        (try? JSONEncoder().encode(value)).map { [key: $0] }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from payload: [String: Any], key: String) -> T? {
        (payload[key] as? Data).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}
