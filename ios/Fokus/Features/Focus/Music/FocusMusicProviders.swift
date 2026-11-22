import FokusAudio
import Foundation

/// Uygulamanın müzik sağlayıcıları. Normalde yalnızca Spotify; DEBUG + `-FokusUITestMode` +
/// `-FokusUITestSpotify connected|disconnected` ile UI testleri sahte sağlayıcı kullanır.
enum FocusMusicProviders {
    static let uiTestArgument = "-FokusUITestSpotify"

    @MainActor
    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) -> [any MusicProvider] {
        #if DEBUG
        if let fake = fakeProvider(arguments: arguments) { return [fake] }
        #endif
        return [SpotifyMusicProvider.make()]
    }

    #if DEBUG
    @MainActor
    private static func fakeProvider(arguments: [String]) -> FakeMusicProvider? {
        guard arguments.contains("-FokusUITestMode"),
            let index = arguments.firstIndex(of: uiTestArgument), arguments.indices.contains(index + 1)
        else { return nil }
        switch arguments[index + 1] {
        case "connected": return FakeMusicProvider(.connected)
        case "disconnected": return FakeMusicProvider(.disconnected)
        default: return nil
        }
    }
    #endif
}
