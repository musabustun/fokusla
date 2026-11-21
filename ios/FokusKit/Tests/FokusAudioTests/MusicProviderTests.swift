import Testing

@testable import FokusAudio

@Suite("MusicSectionMode")
struct MusicSectionModeTests {
    @Test(
        "kullanılabilirlik ve bağlantıya göre bölüm kipi",
        arguments: [
            (MusicProviderAvailability.notConfigured, MusicConnectionState.disconnected, MusicSectionMode.openLink),
            (.appNotInstalled, .disconnected, .openLink),
            (.notConfigured, .connected, .openLink),
            (.available, .disconnected, .connect),
            (.available, .connecting, .connect),
            (.available, .failed(.premiumRequired), .connect),
            (.available, .connected, .controls),
        ])
    func mode(
        availability: MusicProviderAvailability, connection: MusicConnectionState, expected: MusicSectionMode
    ) {
        #expect(MusicSectionMode.mode(availability: availability, connection: connection) == expected)
    }

    @Test("her hata Türkçe ve boş olmayan bir mesaj taşır")
    func errorMessages() {
        let all: [MusicProviderError] = [
            .notConfigured, .appNotInstalled, .authorizationDenied, .connectionLost, .premiumRequired,
            .commandFailed, .unknown,
        ]
        for error in all { #expect(!error.userMessage.isEmpty) }
        #expect(MusicProviderError.premiumRequired.userMessage.contains("Premium"))
    }
}
