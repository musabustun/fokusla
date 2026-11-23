import Foundation

/// Sunucusuz ortak odak odası: tüm durum mesajın bağlantısındadır
/// (`fokus://room?v=1&id=<uuid>&t=<başlangıç unix sn>&m=<dk>&p=<uuid>,<ad>…`). Biri "Katıl" deyip
/// güncellenmiş mesajı gönderince aynı `MSSession` mesajı yenilenir; ilk katılımcı odayı kuran kişidir.
public struct RoomInvite: Equatable, Sendable {
    public struct Participant: Equatable, Sendable, Identifiable {
        public var id: UUID
        public var name: String

        public init(id: UUID, name: String) {
            self.id = id
            self.name = name
        }
    }

    public enum Phase: Equatable, Sendable {
        /// Başlamasına kalan süre (sn).
        case upcoming(secondsLeft: TimeInterval)
        /// Bitmesine kalan süre (sn).
        case live(secondsLeft: TimeInterval)
        case ended
    }

    public enum JoinResult: Equatable, Sendable {
        case joined(RoomInvite)
        /// Zaten üyeydi; yalnızca adı güncellendi.
        case alreadyJoined(RoomInvite)
        case full
        case ended
    }

    /// URL boyutunu sınırlamak için katılımcı üst sınırı.
    public static let maxParticipants = 8
    public static let durationRange = 15...180
    /// Davet ekranının sunduğu süreler (dk).
    public static let durationOptions = [15, 25, 30, 45, 50, 60, 90, 120]
    public static let fallbackName = "Katılımcı"

    public var id: UUID
    public var startsAt: Date
    public var durationMinutes: Int
    public var participants: [Participant]

    public init(id: UUID, startsAt: Date, durationMinutes: Int, participants: [Participant]) {
        self.id = id
        self.startsAt = startsAt
        self.durationMinutes = durationMinutes
        self.participants = participants
    }

    public var endsAt: Date { startsAt.addingTimeInterval(TimeInterval(durationMinutes) * 60) }
    public var host: Participant? { participants.first }

    public func phase(now: Date) -> Phase {
        if now < startsAt { return .upcoming(secondsLeft: startsAt.timeIntervalSince(now)) }
        if now < endsAt { return .live(secondsLeft: endsAt.timeIntervalSince(now)) }
        return .ended
    }

    /// Katılımı uygular; GİRDİYİ DEĞİŞTİRMEZ, güncellenmiş kopya döndürür.
    public func joining(_ participant: Participant, now: Date) -> JoinResult {
        guard phase(now: now) != .ended else { return .ended }
        let name = ShareLink.sanitizedName(participant.name) ?? Self.fallbackName
        let cleaned = Participant(id: participant.id, name: name)
        if let index = participants.firstIndex(where: { $0.id == participant.id }) {
            var updated = self
            updated.participants[index] = cleaned
            return .alreadyJoined(updated)
        }
        guard participants.count < Self.maxParticipants else { return .full }
        var updated = self
        updated.participants.append(cleaned)
        return .joined(updated)
    }

    /// Balonun altındaki özet satırı.
    public var summaryText: String {
        let names = participants.map(\.name)
        switch names.count {
        case 0: return "\(durationMinutes) dk ortak odak"
        case 1: return "\(names[0]) ile \(durationMinutes) dk birlikte çalışalım"
        case 2...3: return "\(names.joined(separator: ", ")) · \(durationMinutes) dk ortak odak"
        default:
            return "\(names.prefix(3).joined(separator: ", ")) +\(names.count - 3) · \(durationMinutes) dk ortak odak"
        }
    }

    // MARK: - Bağlantı

    public var url: URL {
        var items: [(String, String)] = [
            ("v", String(ShareLink.version)), ("id", id.uuidString),
            ("t", String(Int(startsAt.timeIntervalSince1970))), ("m", String(durationMinutes)),
        ]
        for participant in participants.prefix(Self.maxParticipants) {
            items.append(("p", "\(participant.id.uuidString),\(participant.name)"))
        }
        return ShareLink.makeURL(host: "room", items: items)
    }

    /// Dışarıdan gelen bağlantıyı çözer ve doğrular (güvenilmez girdi).
    public init(url: URL) throws {
        let items = try ShareLink.parse(url, host: "room")
        func first(_ key: String) -> String? { items.first { $0.key == key }?.value }
        guard let id = first("id").flatMap(UUID.init(uuidString:)) else { throw ShareLinkError.invalid("id") }
        guard let seconds = first("t").flatMap(TimeInterval.init), seconds > 0, seconds < 4_102_444_800 else {
            throw ShareLinkError.invalid("t")
        }
        guard let minutes = first("m").flatMap(Int.init), Self.durationRange.contains(minutes) else {
            throw ShareLinkError.invalid("m")
        }
        var participants: [Participant] = []
        for item in items where item.key == "p" && participants.count < Self.maxParticipants {
            let pieces = item.value.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard pieces.count == 2, let personId = UUID(uuidString: String(pieces[0])),
                !participants.contains(where: { $0.id == personId })
            else { continue }
            participants.append(
                Participant(id: personId, name: ShareLink.sanitizedName(String(pieces[1])) ?? Self.fallbackName))
        }
        guard !participants.isEmpty else { throw ShareLinkError.invalid("p") }
        self.init(
            id: id, startsAt: Date(timeIntervalSince1970: seconds), durationMinutes: minutes,
            participants: participants)
    }
}
