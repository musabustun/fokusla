import CryptoKit
import Foundation

/// Takvim günü anahtarı `YYYY-MM-DD` (YEREL gün). `Date`'e çevrilerek saklanmaz; web `ISODate`.
public typealias ISODate = String

/// Kimlik ve tarih yardımcıları — web `web/src/domain/ids.ts` karşılığı.
public enum Identifiers {
    /// Müfredat kataloğu kayıtlarının (Subject/Topic) UUID v5 ad alanı. ASLA DEĞİŞTİRME:
    /// web `CATALOG_NAMESPACE` ile aynıdır; her cihaz aynı `catalogKey` için aynı id'yi üretir.
    public static let catalogNamespace = UUID(uuidString: "2af57060-c631-4c67-8d55-0db8f6b7c869")!

    /// Yeni rastgele (v4) kimlik.
    public static func newId() -> UUID { UUID() }

    /// RFC 4122 UUID v5 (SHA-1, isim tabanlı, deterministik). Web `uuidV5` ile aynı sonucu verir.
    public static func uuidV5(name: String, namespace: UUID) -> UUID {
        var input = Data(withUnsafeBytes(of: namespace.uuid) { Array($0) })
        input.append(Data(name.utf8))
        var bytes = Array(Insecure.SHA1.hash(data: input).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    /// Katalog kaydının (`catalogKey`) tüm cihazlarda ve web'de aynı olan id'si.
    public static func catalogEntityId(_ catalogKey: String) -> UUID {
        uuidV5(name: catalogKey, namespace: catalogNamespace)
    }

    /// Web ile karşılaştırma/dışa aktarma için küçük harfli UUID dizgesi
    /// (Swift `uuidString` BÜYÜK harf üretir).
    public static func lowercasedString(_ id: UUID) -> String { id.uuidString.lowercased() }

    /// Verilen anın YEREL takvim günü (`YYYY-MM-DD`). Testlerde `calendar` ile saat dilimi sabitlenir.
    public static func isoDate(_ date: Date, calendar: Calendar = .current) -> ISODate {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
