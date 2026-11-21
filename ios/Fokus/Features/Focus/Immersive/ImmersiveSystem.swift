import OSLog
import SwiftUI
import UIKit

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "immersive")

/// iPhone yön kilidi: normalde yalnızca dikey; tam ekran odak açıkken dikey + yatay (baş aşağı hariç).
/// iPad her zaman tüm yönleri destekler. `FokusAppDelegate` maskeyi buradan okur.
@MainActor
enum ImmersiveOrientation {
    private(set) static var isImmersiveActive = false

    static func supportedMask(idiom: UIUserInterfaceIdiom) -> UIInterfaceOrientationMask {
        guard idiom == .phone else { return .all }
        return isImmersiveActive ? .allButUpsideDown : .portrait
    }

    /// Tam ekran açılınca `true`, kapanınca `false`. Kapanışta cihaz yataydaysa dikeye döner.
    static func setImmersiveActive(_ active: Bool) {
        guard active != isImmersiveActive else { return }
        isImmersiveActive = active
        guard let scene = windowScene else { return }
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        guard !active, UIDevice.current.userInterfaceIdiom == .phone else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
            logger.error("Dikey yöne dönülemedi: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static var windowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

/// Tam ekran açıkken ekranın sönmesini engeller; kapanışta ESKİ değeri geri yazar. Çağrılar
/// idempotenttir: `.onDisappear` ve sunum kapanış geri çağrısı ikisi de `deactivate` çağırabilir.
@MainActor
enum ImmersiveScreenAwake {
    private static var previous: Bool?

    static func activate() {
        guard previous == nil else { return }
        previous = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
    }

    static func deactivate() {
        guard let previous else { return }
        UIApplication.shared.isIdleTimerDisabled = previous
        self.previous = nil
    }
}

/// `FokusApp`'e `@UIApplicationDelegateAdaptor` ile bağlanır; yalnızca yön kilidini yönetir.
@MainActor
final class FokusAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        ImmersiveOrientation.supportedMask(idiom: UIDevice.current.userInterfaceIdiom)
    }
}
