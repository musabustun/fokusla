import CloudKit
import FokusData
import Observation
import UIKit

/// Sistemden (Mesajlar, Safari, QR) gelen CloudKit davetini Sosyal kabul edene kadar tutar.
@MainActor
@Observable
final class SocialInviteInbox {
    static let shared = SocialInviteInbox()

    struct Pending: Identifiable {
        let id = UUID()
        let invite: SocialInvite
    }

    var pending: Pending?

    func receive(_ invite: SocialInvite) { pending = Pending(invite: invite) }
}

/// SwiftUI yaşam döngüsünde CloudKit daveti yalnız sahne temsilcisine gelir. Pencereyi SwiftUI kurar.
final class FokusSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let metadata = connectionOptions.cloudKitShareMetadata { receive(metadata) }
    }

    func windowScene(
        _ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        receive(cloudKitShareMetadata)
    }

    private func receive(_ metadata: CKShare.Metadata) {
        SocialInviteInbox.shared.receive(SocialInvite(metadata: metadata))
    }
}

extension FokusAppDelegate {
    func application(
        _ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = FokusSceneDelegate.self
        return configuration
    }
}
