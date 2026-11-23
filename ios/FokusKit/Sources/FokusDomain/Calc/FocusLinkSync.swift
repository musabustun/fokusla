import Foundation

/// iPhone ↔ Apple Watch KAYIT eşlemesi (1.0.1). Saat deposu CloudKit'e bağlı değildir (watchOS'ta
/// `ubiquityIdentityToken` her zaman `nil`; Apple QA1935), bu yüzden odak oturumları iki cihaz arasında
/// `WatchConnectivity` ile TAM kayıt olarak taşınır ve alıcı tarafta `id` ile idempotent biçimde yazılır
/// (upsert). Telefon kaydı kendi deposuna yazınca CloudKit onu iPad'e de taşır.
///
/// Kurallar saf ve tablo testlidir:
/// - `mergeAction`: aynı `id`'de daha yeni `updatedAt` kazanır (son yazan kazanır); eşitlikte yerel kalır.
/// - `repairs`: birleşmeden sonra "aynı anda tek açık oturum, oturumda tek açık segment" değişmezini
///   geri kurar (iki cihazda bağlantısızken ayrı ayrı başlatma gibi çakışmalar).
/// - `shouldSend`: karşıya gönderilecek kayıtlar (son gönderimden sonra değişenler, yankı hariç).
extension FocusLink {
    // MARK: - Kayıtlar

    /// `FocusSession`'ın tüm alanları (taşıma için değer kopyası).
    public struct SessionRecord: Codable, Sendable, Equatable {
        public var id: UUID
        public var createdAt: Date
        public var updatedAt: Date
        public var deletedAt: Date?
        public var subjectId: UUID?
        public var topicId: UUID?
        public var startedAt: Date
        public var endedAt: Date?
        public var note: String?

        public init(
            id: UUID, createdAt: Date, updatedAt: Date, deletedAt: Date? = nil, subjectId: UUID? = nil,
            topicId: UUID? = nil, startedAt: Date, endedAt: Date? = nil, note: String? = nil
        ) {
            self.id = id
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
            self.subjectId = subjectId
            self.topicId = topicId
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.note = note
        }
    }

    /// `FocusSegment`'in tüm alanları.
    public struct SegmentRecord: Codable, Sendable, Equatable {
        public var id: UUID
        public var createdAt: Date
        public var updatedAt: Date
        public var deletedAt: Date?
        public var sessionId: UUID?
        public var kind: FocusSegmentKind
        public var startedAt: Date
        public var endedAt: Date?

        public init(
            id: UUID, createdAt: Date, updatedAt: Date, deletedAt: Date? = nil, sessionId: UUID?,
            kind: FocusSegmentKind, startedAt: Date, endedAt: Date? = nil
        ) {
            self.id = id
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.deletedAt = deletedAt
            self.sessionId = sessionId
            self.kind = kind
            self.startedAt = startedAt
            self.endedAt = endedAt
        }
    }

    /// Tek seferde taşınan kayıtlar. `subjectNames`: oturumlardaki derslerin adları (saatte ders kaydı
    /// yoktur; ad yalnızca gösterim önbelleğidir, depoya yazılmaz).
    public struct RecordBatch: Codable, Sendable, Equatable {
        public var sessions: [SessionRecord]
        public var segments: [SegmentRecord]
        public var subjectNames: [UUID: String]

        public init(
            sessions: [SessionRecord] = [], segments: [SegmentRecord] = [], subjectNames: [UUID: String] = [:]
        ) {
            self.sessions = sessions
            self.segments = segments
            self.subjectNames = subjectNames
        }

        public var isEmpty: Bool { sessions.isEmpty && segments.isEmpty }
        public var count: Int { sessions.count + segments.count }

        /// Kayıtların en yeni `updatedAt`'i (gönderim damgası); boşsa `nil`.
        public var latestUpdate: Date? {
            (sessions.map(\.updatedAt) + segments.map(\.updatedAt)).max()
        }
    }

    // MARK: - Birleştirme

    public enum MergeAction: Sendable, Equatable { case insert, update, skip }

    /// Gelen kayıt yerele ne yapar? Yerelde yoksa eklenir; gelen STRİKT daha yeniyse güncellenir;
    /// aksi halde (eşit ya da eski — yankı, gecikmiş kuyruk) yok sayılır.
    public static func mergeAction(localUpdatedAt: Date?, incomingUpdatedAt: Date) -> MergeAction {
        guard let localUpdatedAt else { return .insert }
        return incomingUpdatedAt > localUpdatedAt ? .update : .skip
    }

    // MARK: - Değişmez onarımı

    /// Onarım için oturumun en küçük görünümü.
    public struct SessionStub: Sendable, Equatable {
        public var id: UUID
        public var startedAt: Date
        public var endedAt: Date?

        public init(id: UUID, startedAt: Date, endedAt: Date?) {
            self.id = id
            self.startedAt = startedAt
            self.endedAt = endedAt
        }
    }

    public struct SegmentStub: Sendable, Equatable {
        public var id: UUID
        public var sessionId: UUID?
        public var startedAt: Date
        public var endedAt: Date?

        public init(id: UUID, sessionId: UUID?, startedAt: Date, endedAt: Date?) {
            self.id = id
            self.sessionId = sessionId
            self.startedAt = startedAt
            self.endedAt = endedAt
        }
    }

    /// Kapatılacak kayıtlar: `id` → kapanış anı.
    public struct Repairs: Sendable, Equatable {
        public var closeSessions: [UUID: Date]
        public var closeSegments: [UUID: Date]

        public init(closeSessions: [UUID: Date] = [:], closeSegments: [UUID: Date] = [:]) {
            self.closeSessions = closeSessions
            self.closeSegments = closeSegments
        }

        public var isEmpty: Bool { closeSessions.isEmpty && closeSegments.isEmpty }
    }

    /// Silinmemiş kayıtlarda değişmezleri geri kurar:
    /// 1. Birden fazla açık oturum varsa EN SON başlayan açık kalır; her eski oturum, kendisinden sonra
    ///    başlayan ilk açık oturumun başladığı anda kapanır (süreler iki kez sayılmaz).
    /// 2. Bir oturumda birden fazla açık segment varsa en son başlayan açık kalır; diğerleri bir
    ///    sonrakinin başladığı anda kapanır (iki cihazda aynı anda "mola" → tek mola).
    /// 3. Bitmiş (ya da 1. kuralla kapanan) oturumun açık segmentleri oturumun bittiği anda kapanır.
    /// Kapanış anı hiçbir zaman kaydın kendi başlangıcından önce olmaz. Eşit başlangıçta `id` sırası
    /// belirleyicidir (iki cihaz aynı sonuca varır).
    public static func repairs(sessions: [SessionStub], segments: [SegmentStub]) -> Repairs {
        var result = Repairs()
        let openSessions = sessions.filter { $0.endedAt == nil }.sorted(by: isEarlier)
        for (index, session) in openSessions.enumerated() where index < openSessions.count - 1 {
            result.closeSessions[session.id] = Swift.max(session.startedAt, openSessions[index + 1].startedAt)
        }

        var sessionEnds: [UUID: Date] = [:]
        for session in sessions {
            if let end = result.closeSessions[session.id] ?? session.endedAt { sessionEnds[session.id] = end }
        }
        let openSegments = Dictionary(grouping: segments.filter { $0.endedAt == nil }, by: \.sessionId)
        for (sessionId, group) in openSegments {
            let ordered = group.sorted(by: isEarlier)
            let sessionEnd = sessionId.flatMap { sessionEnds[$0] }
            for (index, segment) in ordered.enumerated() {
                if index < ordered.count - 1 {
                    var close = ordered[index + 1].startedAt
                    if let sessionEnd { close = Swift.min(close, sessionEnd) }
                    result.closeSegments[segment.id] = Swift.max(segment.startedAt, close)
                } else if let sessionEnd {
                    result.closeSegments[segment.id] = Swift.max(segment.startedAt, sessionEnd)
                }
            }
        }
        return result
    }

    private static func isEarlier(_ lhs: SessionStub, _ rhs: SessionStub) -> Bool {
        lhs.startedAt == rhs.startedAt ? lhs.id.uuidString < rhs.id.uuidString : lhs.startedAt < rhs.startedAt
    }

    private static func isEarlier(_ lhs: SegmentStub, _ rhs: SegmentStub) -> Bool {
        lhs.startedAt == rhs.startedAt ? lhs.id.uuidString < rhs.id.uuidString : lhs.startedAt < rhs.startedAt
    }

    // MARK: - Gönderim seçimi

    /// İlk eşlemede (hiç gönderilmemişse) geriye dönük taşınan pencere: son 8 gün (haftalık istatistik
    /// için 7 gün + bugün).
    public static let initialWindow: TimeInterval = 8 * 24 * 3600

    /// Tek mesajdaki en fazla kayıt (WCSession mesaj boyutu ~65 KB; bir kayıt ~300 bayt JSON).
    public static let maxRecordsPerBatch = 120

    /// Kayıt bu taraftan gönderilmeli mi?
    /// - Karşıdan aynen alınan sürüm (`echo[id] == updatedAt`) geri yollanmaz.
    /// - `lastSent` varsa: `updatedAt > lastSent`.
    /// - Yoksa (ilk eşleme): pencere içinde başlamış ya da hâlâ açık olanlar.
    public static func shouldSend(
        id: UUID, updatedAt: Date, startedAt: Date, isOpen: Bool, lastSent: Date?, echo: [UUID: Date], now: Date
    ) -> Bool {
        if echo[id] == updatedAt { return false }
        if let lastSent { return updatedAt > lastSent }
        return isOpen || startedAt >= now.addingTimeInterval(-initialWindow)
    }

    /// Büyük bir kümeyi mesaj boyutuna uygun parçalara böler. Oturumlar segmentlerinden ÖNCE gelir;
    /// kayıtlar `updatedAt` sırasıyla dizilir.
    public static func chunked(_ batch: RecordBatch, limit: Int = maxRecordsPerBatch) -> [RecordBatch] {
        if batch.isEmpty { return [] }
        guard batch.count > limit, limit > 0 else { return [batch] }
        let sessions = batch.sessions.sorted { $0.updatedAt < $1.updatedAt }
        let segments = batch.segments.sorted { $0.updatedAt < $1.updatedAt }
        var parts: [RecordBatch] = []
        var current = RecordBatch()
        func flushIfFull() {
            if current.count >= limit {
                parts.append(current)
                current = RecordBatch()
            }
        }
        for record in sessions {
            current.sessions.append(record)
            if let subjectId = record.subjectId, let name = batch.subjectNames[subjectId] {
                current.subjectNames[subjectId] = name
            }
            flushIfFull()
        }
        for record in segments {
            current.segments.append(record)
            flushIfFull()
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    // MARK: - Tercihler (telefon → saat)

    /// Telefonda seçilen görünüm tercihleri. Saat bunları kendi `UserDefaults`'una yazar; `@AppStorage`
    /// okuyan ekranlar (tema) anında güncellenir. Uygulama bağlamı ile gider: en yenisi kazanır ve saat
    /// uygulaması kapalıyken gelse de açılışta okunur.
    public struct Preferences: Codable, Sendable, Equatable {
        /// `FokusPalette` raw value'su (`fokus.palette`); bilinmiyorsa `nil`.
        public var palette: String?

        public init(palette: String?) {
            self.palette = palette
        }
    }

    public static let preferencesKey = "fokus.link.preferences"

    public static func payload(_ preferences: Preferences) -> [String: Any]? {
        (try? JSONEncoder().encode(preferences)).map { [preferencesKey: $0] }
    }

    public static func preferences(from payload: [String: Any]) -> Preferences? {
        (payload[preferencesKey] as? Data).flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) }
    }

    // MARK: - Taşıma biçimi

    public static let recordsKey = "fokus.link.records"

    public static func payload(_ batch: RecordBatch) -> [String: Any]? {
        (try? JSONEncoder().encode(batch)).map { [recordsKey: $0] }
    }

    public static func records(from payload: [String: Any]) -> RecordBatch? {
        (payload[recordsKey] as? Data).flatMap { try? JSONDecoder().decode(RecordBatch.self, from: $0) }
    }
}
