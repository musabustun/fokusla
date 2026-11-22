import XCTest

/// App Store ham ekran görüntüleri (varsayılan test koşusunda ATLANIR).
/// Üretim: `appstore/scripts/capture_screenshots.sh` (kendi simülatörlerinde, `TEST_RUNNER_FOKUS_STORE_SHOTS=1` ile).
/// Demo veri: `-FokusUITestMode -FokusDemoData` (`StoreListingDemoData`); ekranlar `XCTAttachment` olarak
/// `<aygıt>-<sıra>-<ad>` adıyla kaydedilir ve `xcresulttool` ile dışa aktarılır.
@MainActor
final class StoreScreenshotsUITests: XCTestCase {
    private var app: XCUIApplication!
    private var device: String { UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone" }
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FOKUS_STORE_SHOTS"] == "1", "Yalnızca mağaza görseli üretiminde çalışır")
    }

    // MARK: Yardımcılar

    private func launch(theme: String, openSession: Bool = false, immersivePage: String? = nil) {
        app = XCUIApplication()
        var arguments = ["-FokusUITestMode", "-FokusDemoData", "-fokus.theme", theme, "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        if openSession { arguments += ["-FokusDemoOpenSession"] }
        if let immersivePage { arguments += ["-FokusUITestImmersivePage", immersivePage] }
        app.launchArguments = arguments
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waitFor(_ identifier: String, timeout: TimeInterval = 10) {
        XCTAssertTrue(element(identifier).waitForExistence(timeout: timeout), "\(identifier) yok")
    }

    /// iPhone: tab bar; iPad: kenar çubuğu. `books` iPhone'da Bugün → "Diğer" kısayolundan açılır.
    private func open(_ title: String, screen: String) {
        waitFor("screen.today")
        if screen == "today" { return }
        let sidebar = element("sidebar")
        if isPad, sidebar.waitForExistence(timeout: 3) {
            let row = sidebar.staticTexts[title].exists ? sidebar.staticTexts[title] : sidebar.buttons[title]
            row.tap()
        } else if screen == "books" {
            let link = element("today.shortcut.books")
            for _ in 0..<4 where !link.isHittable { app.swipeUp() }
            link.tap()
        } else {
            app.tabBars.buttons[title].tap()
        }
        waitFor("screen.\(screen)")
    }

    private func shoot(_ index: Int, _ name: String, settle: TimeInterval = 1.8) {
        Thread.sleep(forTimeInterval: settle)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "%@-%02d-%@", device, index, name)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: Koyu tema

    func testDarkMainScreens() {
        launch(theme: "dark")
        open("Bugün", screen: "today")
        shoot(1, "today-dark")
        app.swipeUp()
        shoot(11, "today-dark-scrolled")
        app.swipeDown()
        open("Odak", screen: "focus")
        shoot(2, "focus-dark")
        open("Analiz", screen: "analysis")
        shoot(5, "analysis-dark")
        open("Görevler", screen: "tasks")
        shoot(7, "tasks-dark")
        open("Kitaplar", screen: "books")
        shoot(6, "books-dark")
    }

    // MARK: Tam ekran odak (açık oturum)

    func testImmersivePages() {
        for (index, page) in [(3, "stopwatch"), (4, "ring"), (8, "summary"), (9, "sound")] {
            launch(theme: "dark", openSession: true, immersivePage: page)
            waitFor("immersive.root", timeout: 15)
            waitFor("immersive.page.\(page)")
            shoot(index, "immersive-\(page)-dark", settle: 2.5)
            app.terminate()
        }
    }

    // MARK: Açık tema

    func testLightScreens() {
        launch(theme: "light")
        open("Bugün", screen: "today")
        shoot(21, "today-light")
        open("Analiz", screen: "analysis")
        shoot(22, "analysis-light")
        open("Görevler", screen: "tasks")
        shoot(23, "tasks-light")
    }
}
