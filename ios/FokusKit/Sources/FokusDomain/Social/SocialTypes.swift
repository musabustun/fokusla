import Foundation

// Sosyal modülünün saf değer tipleri (web `domain/types.ts` > PresenceState/SocialPresence ve
// `domain/calc/social.ts` tipleri). Hesaplar `Calc/SocialCalc.swift`'tedir. Süreler milisaniye (Double).

/// Arkadaşın/kendimin canlı odak durumu. Raw value'lar web ile BİREBİR aynıdır.
public enum PresenceState: String, CaseIterable, Codable, Sendable, Hashable {
    case focusing
    case onBreak
    case offline
}

/// Başkalarıyla paylaşılan TEK çalışma bilgisi: durum ve süreler. Ders/test/kitap içeriği asla yok.
public struct SocialPresence: Codable, Sendable, Hashable {
    public var state: PresenceState
    /// Sürmekte olan oturumun başlangıcı; çevrimdışıysa `nil`.
    public var sessionStartedAt: Date?
    /// Mevcut durumun (odak/mola) başlangıcı; çevrimdışıysa `nil`.
    public var stateSince: Date?
    /// `updatedAt` anına kadar bugün biriken odak süresi (ms).
    public var todayFocusMs: Double
    public var updatedAt: Date
    /// Durumun geçerli sayılacağı son an. Telefon kilitliyken kalp atışı durduğu için odakta/molada ileri bir
    /// an yazılır; `nil` ise `SocialCalc.presenceStaleAfterMs` kuralı geçerlidir.
    public var expiresAt: Date?

    public init(
        state: PresenceState, sessionStartedAt: Date?, stateSince: Date?,
        todayFocusMs: Double, updatedAt: Date, expiresAt: Date? = nil
    ) {
        self.state = state
        self.sessionStartedAt = sessionStartedAt
        self.stateSince = stateSince
        self.todayFocusMs = todayFocusMs
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
    }
}

/// Kullanıcı adı neden geçersiz? (`taken` tekillik kontrolüdür; `SocialService` döner.)
public enum UsernameProblem: String, Sendable, Hashable, CaseIterable {
    case tooShort, tooLong, invalidChars, mustStartWithLetter
}

/// `SocialCalc.validateUsername` sonucu.
public enum UsernameValidation: Sendable, Hashable {
    case valid(String)
    case invalid(UsernameProblem)
}
