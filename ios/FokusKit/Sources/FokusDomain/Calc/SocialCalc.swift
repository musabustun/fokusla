import Foundation

/// Sosyal hesapları — web `domain/calc/social.ts` karşılığı. SAF fonksiyonlar: zaman `now` ile gelir,
/// yan etki yoktur. Süreler milisaniyedir (Double).
public enum SocialCalc {
    // MARK: - Sabitler

    public static let usernameMinLength = 3
    public static let usernameMaxLength = 20
    public static let inviteCodeLength = 6
    /// Durum bu süreden eskiyse (yayınlayan cihaz kapanmış olabilir) çevrimdışı sayılır.
    /// CloudKit gerçek zamanlı değildir; kalp atışı ~60 sn'de bir gelir (ARCHITECTURE 4.7).
    public static let presenceStaleAfterMs: Double = 10 * 60 * 1000

    private static let turkish = Locale(identifier: "tr_TR")

    // MARK: - Kullanıcı adı ve davet kodu

    /// Kullanıcı adını normalleştirir ve doğrular.
    /// Normalleştirme: baş/son boşluk kırpılır, baştaki TEK `@` atılır, `tr_TR` ile küçük harf.
    /// Kurallar: 3–20 karakter; yalnızca a–z, 0–9, `.` ve `_` (ASCII — Türkçe harf yok, `ı`/`İ` dahil);
    /// ilk karakter harf. Sıra: uzunluk (tooShort/tooLong) → karakter (invalidChars) → ilk harf.
    public static func validateUsername(_ raw: String) -> UsernameValidation {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutAt = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        let username = withoutAt.lowercased(with: turkish)
        let scalars = Array(username.unicodeScalars)
        if scalars.count < usernameMinLength { return .invalid(.tooShort) }
        if scalars.count > usernameMaxLength { return .invalid(.tooLong) }
        if !scalars.allSatisfy(isUsernameScalar) { return .invalid(.invalidChars) }
        guard let first = scalars.first, isLowercaseLetter(first) else {
            return .invalid(.mustStartWithLetter)
        }
        return .valid(username)
    }

    private static func isLowercaseLetter(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 0x61 && scalar.value <= 0x7A
    }

    private static func isDigit(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 0x30 && scalar.value <= 0x39
    }

    private static func isUsernameScalar(_ scalar: Unicode.Scalar) -> Bool {
        isLowercaseLetter(scalar) || isDigit(scalar) || scalar == "." || scalar == "_"
    }

    private static func isInviteCodeScalar(_ scalar: Unicode.Scalar) -> Bool {
        (scalar.value >= 0x41 && scalar.value <= 0x5A) || isDigit(scalar)
    }

    /// Davet kodunu normalleştirir: boşluk ve `-` atılır, büyük harf (yerel ayarsız).
    /// Geçerli kod tam 6 karakter A–Z/0–9'dur; değilse `nil`.
    public static func normalizeInviteCode(_ raw: String) -> String? {
        let kept = raw.unicodeScalars.filter {
            $0 != "-" && !CharacterSet.whitespacesAndNewlines.contains($0)
        }
        let code = String(String.UnicodeScalarView(kept)).uppercased()
        let scalars = Array(code.unicodeScalars)
        guard scalars.count == inviteCodeLength, scalars.allSatisfy(isInviteCodeScalar) else {
            return nil
        }
        return code
    }

    // MARK: - Canlı durum

    /// Tam ms'ye yuvarlanmış epoch (Date'in kayan nokta kalıntısı eşik karşılaştırmasını bozmasın).
    private static func epochMs(_ date: Date) -> Double {
        (date.timeIntervalSince1970 * 1000).rounded()
    }

    /// `now − date` (ms); negatif olabilir.
    private static func msSince(_ date: Date, _ now: Date) -> Double {
        epochMs(now) - epochMs(date)
    }

    /// Geçen süre (ms); başlangıç yoksa veya gelecekteyse (saat kayması) 0.
    private static func elapsedMs(since date: Date?, _ now: Date) -> Double {
        guard let date else { return 0 }
        return Swift.max(0, msSince(date, now))
    }

    /// Gösterilecek durum: presence yok → offline; `now − updatedAt > presenceStaleAfterMs` → offline;
    /// aksi halde `presence.state`.
    public static func effectivePresenceState(_ presence: SocialPresence?, now: Date) -> PresenceState {
        guard let presence else { return .offline }
        if msSince(presence.updatedAt, now) > presenceStaleAfterMs { return .offline }
        return presence.state
    }

    /// Canlı bugünkü toplam odak (ms): `todayFocusMs` + (etkin durum `.focusing` ise `now − updatedAt`).
    /// Presence yok → 0. Negatif fark (saat kayması) 0 sayılır. Bayatsa yalnızca `todayFocusMs`.
    public static func liveTodayFocusMs(_ presence: SocialPresence?, now: Date) -> Double {
        guard let presence else { return 0 }
        guard effectivePresenceState(presence, now: now) == .focusing else { return presence.todayFocusMs }
        return presence.todayFocusMs + elapsedMs(since: presence.updatedAt, now)
    }

    /// Sürmekte olan oturumun süresi (ms): `now − sessionStartedAt`; etkin durum offline ise 0.
    public static func liveSessionMs(_ presence: SocialPresence?, now: Date) -> Double {
        if effectivePresenceState(presence, now: now) == .offline { return 0 }
        return elapsedMs(since: presence?.sessionStartedAt, now)
    }

    /// Mevcut durumun (odak/mola) süresi (ms): `now − stateSince`; etkin durum offline ise 0.
    public static func liveStateMs(_ presence: SocialPresence?, now: Date) -> Double {
        if effectivePresenceState(presence, now: now) == .offline { return 0 }
        return elapsedMs(since: presence?.stateSince, now)
    }

    // MARK: - Kendi durumum (focus verisinden YALNIZCA OKUNARAK)

    /// Focus modülünün kayıtlarından kendi paylaşılacak durumumu üretir (focus verisine YAZMAZ).
    ///  - Aktif oturum yoksa: `.offline`, `sessionStartedAt`/`stateSince` nil.
    ///  - Aktif oturum varsa: oturumun açık segmenti (`endedAt == nil`; birden çoksa en geç başlayan)
    ///    `.focus` → `.focusing`, `.break` → `.onBreak`; açık segment yoksa `.onBreak` (duraklatılmış).
    ///    `stateSince` = açık segmentin `startedAt`'i (yoksa oturumun son segment bitişi, o da yoksa oturum başı).
    ///  - `todayFocusMs`: `.focus` segmentlerinin `now`'ın YEREL gününe (00:00 → now) düşen kısmı; açık
    ///    segment `now` ile kapatılmış sayılır; silinmiş (`deletedAt != nil`) segmentler atlanır; aynı
    ///    id'li segment bir kez sayılır (ilk gelen kazanır).
    ///  - `updatedAt` = `now`.
    public static func ownPresenceFromFocus(
        activeSession: FocusSessionSnapshot?,
        segments: [FocusSegmentSnapshot],
        now: Date,
        calendar: Calendar = .current
    ) -> SocialPresence {
        let live = liveUniqueSegments(segments)
        let todayFocusMs = focusMsOnLocalDay(live, now: now, calendar: calendar)
        guard let activeSession else {
            return SocialPresence(
                state: .offline, sessionStartedAt: nil, stateSince: nil,
                todayFocusMs: todayFocusMs, updatedAt: now)
        }
        let sessionSegments = live.filter { $0.sessionId == activeSession.id }
        let (state, stateSince) = activeState(activeSession, sessionSegments)
        return SocialPresence(
            state: state, sessionStartedAt: activeSession.startedAt, stateSince: stateSince,
            todayFocusMs: todayFocusMs, updatedAt: now)
    }

    /// Silinmemiş, id'ye göre tekilleştirilmiş segmentler (ilk kopya kazanır; silinme ona bakar).
    private static func liveUniqueSegments(_ segments: [FocusSegmentSnapshot]) -> [FocusSegmentSnapshot] {
        var seen = Set<UUID>()
        return segments.filter { seen.insert($0.id).inserted }.filter { $0.deletedAt == nil }
    }

    /// `.focus` segmentlerinin `now`'ın yerel gününe (00:00 → now) düşen toplamı (ms).
    private static func focusMsOnLocalDay(
        _ segments: [FocusSegmentSnapshot], now: Date, calendar: Calendar
    ) -> Double {
        let dayStart = epochMs(calendar.startOfDay(for: now))
        let nowMs = epochMs(now)
        return segments.filter { $0.kind == .focus }.reduce(0) { total, segment in
            let start = Swift.max(epochMs(segment.startedAt), dayStart)
            let end = Swift.min(segment.endedAt.map(epochMs) ?? nowMs, nowMs)
            return total + Swift.max(0, end - start)
        }
    }

    private static func activeState(
        _ session: FocusSessionSnapshot, _ sessionSegments: [FocusSegmentSnapshot]
    ) -> (state: PresenceState, stateSince: Date) {
        let open = sessionSegments.filter { $0.endedAt == nil }.max { $0.startedAt < $1.startedAt }
        if let open {
            return (open.kind == .focus ? .focusing : .onBreak, open.startedAt)
        }
        // Duraklatılmış: tüm segmentler kapalı → son bitişten beri mola.
        let lastEndedAt = sessionSegments.compactMap(\.endedAt).max()
        return (.onBreak, lastEndedAt ?? session.startedAt)
    }
}
