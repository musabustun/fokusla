import CloudKit
import Foundation

/// Kabul edilmeyi bekleyen davet: yapıştırılan/okutulan adres ya da sistemin verdiği paylaşım bilgisi.
public struct SocialInvite: Sendable {
    enum Source: Sendable {
        case url(URL)
        case metadata(CKShare.Metadata)
    }

    let source: Source

    public init(url: URL) { source = .url(url) }

    /// Tek kullanımlık bağlantının kimliği yalnızca bu nesnede taşınır; adrese çevrilmez.
    public init(metadata: CKShare.Metadata) { source = .metadata(metadata) }

    /// Yapıştırılan metindeki ilk geçerli iCloud paylaşım adresi.
    public init?(text: String) {
        let match = text.components(separatedBy: .whitespacesAndNewlines)
            .lazy.compactMap { URL(string: $0) }.first(where: Self.isShareURL)
        guard let match else { return nil }
        source = .url(match)
    }

    /// Dışarıdan gelen metin güvenilmezdir: yalnız https + icloud.com paylaşım yolu kabul edilir.
    static func isShareURL(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host()?.lowercased() else { return false }
        let isCloudHost = host == "icloud.com" || host.hasSuffix(".icloud.com") || host == "icloud.com.cn"
            || host.hasSuffix(".icloud.com.cn")
        return isCloudHost && url.path().hasPrefix("/share/")
    }
}
