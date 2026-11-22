import Foundation
import Testing

@testable import FokusAudio

private let redirect = URL(string: "fokus://spotify-callback")!

@Suite("SpotifyAuthCallback")
struct SpotifyAuthCallbackTests {
    @Test(
        "geri dönüş bağlantısı şema ve host ile eşleşir",
        arguments: [
            ("fokus://spotify-callback", true),
            ("fokus://spotify-callback/?access_token=abc", true),
            ("FOKUS://Spotify-Callback#access_token=abc", true),
            ("fokus://baska", false),
            ("https://spotify-callback", false),
            ("spotify:", false),
        ])
    func matches(raw: String, expected: Bool) throws {
        let url = try #require(URL(string: raw))
        #expect(SpotifyAuthCallback.matches(url, redirect: redirect) == expected)
    }

    @Test("parça (#) ve sorgu (?) biçiminden token ayrıştırılır")
    func tokenFromFragmentAndQuery() throws {
        let fragment = try #require(URL(string: "fokus://spotify-callback#access_token=tok%2B1&token_type=Bearer"))
        let query = try #require(URL(string: "fokus://spotify-callback/?access_token=tok2"))
        #expect(SpotifyAuthCallback.parse(fragment, redirect: redirect) == .token("tok+1"))
        #expect(SpotifyAuthCallback.parse(query, redirect: redirect) == .token("tok2"))
    }

    @Test(
        "hata parametreleri uygun MusicProviderError'a eşlenir",
        arguments: [
            ("fokus://spotify-callback#error=access_denied", MusicProviderError.authorizationDenied),
            ("fokus://spotify-callback?error_description=User%20cancelled", .authorizationDenied),
            ("fokus://spotify-callback?error=INVALID_CLIENT&error_description=Invalid%20redirect%20URI", .unknown),
            ("fokus://spotify-callback", .unknown),
            ("fokus://spotify-callback?access_token=", .unknown),
        ])
    func failures(raw: String, expected: MusicProviderError) throws {
        let url = try #require(URL(string: raw))
        #expect(SpotifyAuthCallback.parse(url, redirect: redirect) == .failure(expected))
    }

    @Test("token hata parametrelerinden önceliklidir")
    func tokenWins() {
        let result = SpotifyAuthCallback.interpret(["access_token": "t", "error": "access_denied"])
        #expect(result == .token("t"))
    }

    @Test("başka bir bağlantı için nil döner")
    func foreignURL() throws {
        let url = try #require(URL(string: "fokus://odak"))
        #expect(SpotifyAuthCallback.parse(url, redirect: redirect) == nil)
    }
}

@Suite("SpotifyErrorMapping")
struct SpotifyErrorMappingTests {
    @Test(
        "komut hatası: Premium ifadeleri premiumRequired, bağlantı kopması connectionLost, gerisi commandFailed",
        arguments: [
            (SpotifyRemoteFailure(code: -2001, description: "Premium required"), MusicProviderError.premiumRequired),
            (SpotifyRemoteFailure(code: -2001, description: "Command not allowed for free user"), .premiumRequired),
            (SpotifyRemoteFailure(code: -2001, description: "Operation RESTRICTED"), .premiumRequired),
            (SpotifyRemoteFailure(code: -1002, description: "terminated"), .connectionLost),
            (SpotifyRemoteFailure(code: -2001, description: "Request failed"), .commandFailed),
            (SpotifyRemoteFailure(code: -2000, description: ""), .commandFailed),
        ])
    func command(failure: SpotifyRemoteFailure, expected: MusicProviderError) {
        #expect(SpotifyErrorMapping.commandError(failure) == expected)
    }

    @Test(
        "bağlantı hatası: SDK kodlarına göre",
        arguments: [
            (SpotifyRemoteFailure(code: -1000, description: ""), MusicProviderError.connectionLost),
            (SpotifyRemoteFailure(code: -1001, description: ""), .connectionLost),
            (SpotifyRemoteFailure(code: -1002, description: ""), .connectionLost),
            (SpotifyRemoteFailure(code: -1, description: "boom"), .unknown),
            (SpotifyRemoteFailure(code: -1001, description: "Premium required"), .premiumRequired),
        ])
    func connection(failure: SpotifyRemoteFailure, expected: MusicProviderError) {
        #expect(SpotifyErrorMapping.connectionError(failure) == expected)
    }

    @Test("NSError'dan özet üretilir")
    func fromNSError() {
        let error = NSError(domain: "x", code: -2001, userInfo: [NSLocalizedDescriptionKey: "Premium required"])
        let failure = SpotifyRemoteFailure(error)
        #expect(failure.code == -2001)
        #expect(SpotifyErrorMapping.isPremiumRelated(failure))
    }
}

@Suite("SpotifyConnectionPolicy")
struct SpotifyConnectionPolicyTests {
    @Test(
        "öne gelince sessiz bağlanma kararı",
        arguments: [
            (true, true, false, false, SpotifyConnectionPolicy.ActivationAction.silentConnect),
            (false, true, false, false, .none),
            (true, false, false, false, .none),
            (true, true, true, false, .none),
            (true, true, false, true, .none),
        ])
    func activation(
        wants: Bool, token: Bool, connected: Bool, inFlight: Bool,
        expected: SpotifyConnectionPolicy.ActivationAction
    ) {
        let action = SpotifyConnectionPolicy.activationAction(
            wantsConnection: wants, hasToken: token, isConnected: connected, isAttemptInFlight: inFlight)
        #expect(action == expected)
    }

    @Test(
        "başarısız denemede yetkilendirme yalnızca kullanıcı denemesinde ve bir kez yenilenir",
        arguments: [
            (true, false, SpotifyConnectionPolicy.FailureDecision.reauthorize),
            (true, true, .fail),
            (false, false, .fail),
            (false, true, .fail),
        ])
    func failure(
        userInitiated: Bool, alreadyReauthorized: Bool, expected: SpotifyConnectionPolicy.FailureDecision
    ) {
        let decision = SpotifyConnectionPolicy.decisionAfterConnectionFailure(
            isUserInitiated: userInitiated, alreadyReauthorized: alreadyReauthorized)
        #expect(decision == expected)
    }
}
