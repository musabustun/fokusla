import XCTest

/// iMessage uzantısı mağaza görüntüleri (varsayılan koşuda ATLANIR): Mesajlar'daki örnek konuşmada
/// uygulama çekmecesinden Fokus uzantısını açar (hiçbir şey gönderilmez). Önkoşul: uygulama `-FokusDemoData -FokusDemoPersistent`
/// ile bir kez açılıp gerçek App Group deposu tohumlanmış olmalı. Üretim: `appstore/README.md`.
@MainActor
final class IMessageScreenshotsUITests: XCTestCase {
    private var messages: XCUIApplication!
    private var device: String { UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone" }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FOKUS_STORE_SHOTS"] == "1", "Yalnızca mağaza görseli üretiminde çalışır")
    }

    // MARK: Yardımcılar

    private func shoot(_ index: Int, _ name: String, settle: TimeInterval = 2.0) {
        Thread.sleep(forTimeInterval: settle)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "%@-imessage-%02d-%@", device, index, name)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Örnek konuşmayı açar, "+" ile uygulama çekmecesini açıp Fokus'u seçer (hiçbir şey gönderilmez).
    private func openFokusInDrawer() {
        messages = XCUIApplication(bundleIdentifier: "com.apple.MobileSMS")
        messages.terminate()
        messages.launch()
        let conversation = messages.cells.firstMatch
        XCTAssertTrue(conversation.waitForExistence(timeout: 30), "Örnek konuşma yok")
        conversation.tap()
        let plus = messages.buttons["ekle"].firstMatch
        XCTAssertTrue(plus.waitForExistence(timeout: 15))
        plus.tap()
        let fokus = messages.cells.matching(NSPredicate(format: "identifier CONTAINS 'com.musabustun.fokus.messages'")).firstMatch
        for _ in 0..<6 where !fokus.exists {
            messages.swipeUp()
            Thread.sleep(forTimeInterval: 1)
        }
        XCTAssertTrue(fokus.exists, "Fokus çekmecede yok")
        fokus.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 8)
    }

    // MARK: Ekran görüntüleri

    /// Uzantının içeriği Mesajlar'ın erişilebilirlik ağacında görünmeyebilir; önce etiketle, olmazsa
    /// ekranın oranlı konumuyla dokunur.
    private func tap(label: String, fallback: CGVector) {
        let element = messages.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
        if element.exists, element.isHittable {
            element.tap()
        } else {
            messages.coordinate(withNormalizedOffset: fallback).tap()
        }
    }

    func testCaptureMessagesExtension() throws {
        openFokusInDrawer()
        shoot(1, "compact")

        // Küçük görünümdeki "Bugünkü çalışmam" girişi uzantıyı genişletir ve çalışma kartını gösterir.
        tap(label: "Bugünkü çalışmam", fallback: CGVector(dx: 0.5, dy: 0.70))
        shoot(2, "study-card", settle: 3.5)

        tap(label: "Oda", fallback: CGVector(dx: 0.75, dy: 0.19))
        shoot(3, "room-invite", settle: 3.0)
    }
}
