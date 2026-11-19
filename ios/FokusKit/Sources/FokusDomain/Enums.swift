// Domain enum'ları — raw value'lar web `web/src/domain/types.ts` ile BİREBİR aynıdır
// (docs/ARCHITECTURE.md 4.3). SwiftData modelleri raw string saklar (`fieldRaw` gibi);
// bu enum'lar hesaplanan özelliklerle sunulur. Raw value DEĞİŞTİRİLMEZ (CloudKit şeması).

/// YKS puan türü / alanı.
public enum YksField: String, CaseIterable, Codable, Sendable, Hashable {
    case say = "SAY"
    case ea = "EA"
    case soz = "SOZ"
    case dil = "DIL"

    /// Kullanıcıya görünen kısa ad (`SÖZ`, `DİL`).
    public var shortLabel: String {
        switch self {
        case .say: "SAY"
        case .ea: "EA"
        case .soz: "SÖZ"
        case .dil: "DİL"
        }
    }

    /// Kullanıcıya görünen tam ad.
    public var label: String {
        switch self {
        case .say: "Sayısal"
        case .ea: "Eşit Ağırlık"
        case .soz: "Sözel"
        case .dil: "Dil"
        }
    }

    /// Alan seçimi açıklaması (web `FIELD_DESCRIPTIONS`, ÖSYM 2026-YKS Kılavuzu Tablo 1E).
    public var summary: String {
        switch self {
        case .say:
            "TYT ile birlikte AYT Matematik ve Fen Bilimleri (Fizik, Kimya, Biyoloji) testlerine girersin."
        case .ea:
            "TYT ile birlikte AYT Matematik ile Edebiyat, Tarih-1 ve Coğrafya-1 testlerine girersin."
        case .soz:
            "TYT ile birlikte AYT Edebiyat-Sosyal Bilimler-1 ve Sosyal Bilimler-2 testlerine girersin."
        case .dil:
            "TYT ile birlikte AYT yerine Yabancı Dil Testi (YDT) sınavına girersin."
        }
    }
}

/// Sınav oturumu.
public enum ExamType: String, CaseIterable, Codable, Sendable, Hashable {
    case tyt = "TYT"
    case ayt = "AYT"
    case ydt = "YDT"
}

/// Kitap türü.
public enum BookKind: String, CaseIterable, Codable, Sendable, Hashable {
    case lecture, questionBank, practiceExam, other
}

/// Kitap ilerleme birimi.
public enum BookUnit: String, CaseIterable, Codable, Sendable, Hashable {
    case page, test, section
}

/// Odak segmenti türü.
public enum FocusSegmentKind: String, CaseIterable, Codable, Sendable, Hashable {
    case focus
    case `break`
}

/// Görev türü.
public enum TaskKind: String, CaseIterable, Codable, Sendable, Hashable {
    case routine, assignment
}

/// Rutin tekrarı sıklığı (`RecurrenceRule.frequency`).
public enum RecurrenceFrequency: String, CaseIterable, Codable, Sendable, Hashable {
    case daily, weekly
}

/// Arkadaşlık durumu.
public enum FriendStatus: String, CaseIterable, Codable, Sendable, Hashable {
    case pending, accepted, blocked
}
