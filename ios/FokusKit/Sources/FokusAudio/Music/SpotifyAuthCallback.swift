import Foundation

/// Spotify yetkilendirmesinden uygulamaya dönen bağlantının (`fokus://spotify-callback…`) saf ayrıştırması.
/// SDK'dan bağımsızdır; birim testlidir. Token yalnızca bellekte taşınır, hiçbir yere yazılmaz.
public enum SpotifyAuthCallback: Equatable, Sendable {
    case token(String)
    case failure(MusicProviderError)

    /// `url` beklenen geri dönüş bağlantısına (şema + host) ait mi?
    public static func matches(_ url: URL, redirect: URL) -> Bool {
        guard let scheme = url.scheme, let redirectScheme = redirect.scheme,
            scheme.caseInsensitiveCompare(redirectScheme) == .orderedSame
        else { return false }
        return (url.host ?? "").caseInsensitiveCompare(redirect.host ?? "") == .orderedSame
    }

    /// Sorgu (`?a=b`) ve parça (`#a=b`) parametrelerini birleştirir; Spotify ikisinden birini kullanabilir.
    public static func parameters(from url: URL) -> [String: String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return [:] }
        var result: [String: String] = [:]
        var fragmentComponents = URLComponents()
        fragmentComponents.query = components.fragment
        for item in (fragmentComponents.queryItems ?? []) + (components.queryItems ?? []) {
            if let value = item.value { result[item.name] = value }
        }
        return result
    }

    /// `access_token` varsa token; yoksa `error_description` / `error` metnine göre hata.
    public static func interpret(_ parameters: [String: String]) -> SpotifyAuthCallback {
        if let token = parameters["access_token"], !token.isEmpty { return .token(token) }
        let reason = [parameters["error_description"], parameters["error"]]
            .compactMap { $0?.lowercased() }
            .first { !$0.isEmpty }
        guard let reason else { return .failure(.unknown) }
        let denialMarkers = ["denied", "cancel", "declin", "refus"]
        return denialMarkers.contains { reason.contains($0) }
            ? .failure(.authorizationDenied) : .failure(.unknown)
    }

    /// Bağlantı bizim geri dönüşümüzse sonucu, değilse `nil` döner.
    public static func parse(_ url: URL, redirect: URL) -> SpotifyAuthCallback? {
        guard matches(url, redirect: redirect) else { return nil }
        return interpret(parameters(from: url))
    }
}
