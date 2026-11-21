import XCTest

/// Odak modülü duman testleri: başlat → mola → devam → bitir, uzun mola uyarısı, geçmiş/istatistik.
@MainActor
final class FocusFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Yardımcılar

    private func launch(seed: String? = nil, theme: String? = nil) {
        app = XCUIApplication()
        var arguments = ["-FokusUITestMode"]
        if let seed { arguments += ["-FokusUITestFocusSeed", seed] }
        if let theme { arguments += ["-fokus.theme", theme] }
        app.launchArguments = arguments
        app.launch()
        skipOnboardingAndOpenFocus()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func skipOnboardingAndOpenFocus() {
        XCTAssertTrue(element("onboarding.start").waitForExistence(timeout: 10))
        element("onboarding.start").tap()
        XCTAssertTrue(element("onboarding.field.SAY").waitForExistence(timeout: 5))
        element("onboarding.field.SAY").tap()
        element("onboarding.continue").tap()
        XCTAssertTrue(element("palette.coffee").waitForExistence(timeout: 5))
        element("onboarding.continue").tap()
        XCTAssertTrue(element("onboarding.skip").waitForExistence(timeout: 5))
        element("onboarding.skip").tap()
        XCTAssertTrue(element("screen.today").waitForExistence(timeout: 10))

        let sidebar = element("sidebar")
        if sidebar.waitForExistence(timeout: 3) {
            let row = sidebar.staticTexts["Odak"].exists ? sidebar.staticTexts["Odak"] : sidebar.buttons["Odak"]
            row.tap()
        } else {
            app.tabBars.buttons["Odak"].tap()
        }
        XCTAssertTrue(element("screen.focus").waitForExistence(timeout: 5))
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = element(identifier)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "\(identifier) yok", file: file, line: line)
        button.tap()
    }

    private func waitFor(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(identifier).waitForExistence(timeout: 5), "\(identifier) yok", file: file, line: line)
    }

    private var phase: String { element("focus.phase").label }

    // MARK: Testler

    func testStartPauseResumeFinish() {
        launch()
        XCTAssertEqual(phase.lowercased(), "hazır")
        XCTAssertEqual(element("focus.clock").value as? String, "00:00")
        XCTAssertTrue(app.staticTexts["Henüz tamamlanmış oturum yok"].exists)

        tap("focus.start")
        waitFor("focus.pause")
        XCTAssertFalse(element("focus.start").exists)
        XCTAssertEqual(phase.lowercased(), "odak")
        // Kronometre akar: iki saniye sonra 00:00 olmamalı.
        let ticked = NSPredicate(format: "value != %@", "00:00")
        expectation(for: ticked, evaluatedWith: element("focus.clock"))
        waitForExpectations(timeout: 6)
        attachScreenshot("focus-running")

        tap("focus.pause")
        waitFor("focus.resume")
        XCTAssertEqual(phase.lowercased(), "mola")
        waitFor("focus.sessionTotal")
        attachScreenshot("focus-break")

        tap("focus.resume")
        waitFor("focus.pause")
        XCTAssertEqual(phase.lowercased(), "odak")

        tap("focus.finish")
        waitFor("focus.summary")
        XCTAssertTrue(element("focus.summary.focus").exists)
        attachScreenshot("focus-summary")
        tap("focus.summary.done")
        waitFor("focus.start")
        XCTAssertEqual(phase.lowercased(), "hazır")
        XCTAssertEqual(element("focus.history.row").exists, true)
    }

    func testLongBreakAlertOffersResumeAndFinish() {
        launch(seed: "longbreak")
        waitFor("focus.longBreak")
        XCTAssertTrue(app.staticTexts["Molan uzadı"].exists)
        XCTAssertEqual(phase.lowercased(), "mola")
        attachScreenshot("focus-long-break")

        tap("focus.resume")
        waitFor("focus.pause")
        XCTAssertFalse(element("focus.longBreak").exists)
        XCTAssertEqual(phase.lowercased(), "odak")
    }

    func testHistoryAndStatsAreShown() {
        launch(seed: "history")
        waitFor("focus.averageFocus")
        waitFor("focus.averageBreak")
        waitFor("focus.weekChart")
        XCTAssertTrue(element("focus.history.row").waitForExistence(timeout: 5))
        XCTAssertNotEqual(element("focus.averageFocus").value as? String, "0 sn")
        XCTAssertEqual(element("focus.averageBreak").value as? String, "8 dk")
        attachScreenshot("focus-idle-with-history")
    }

    /// Görsel kontrol: koyu ve açık temada boşta/odakta ekran görüntüleri.
    func testScreenshotsLightAndDark() {
        for theme in ["dark", "light"] {
            launch(seed: "history", theme: theme)
            waitFor("focus.start")
            attachScreenshot("focus-idle-\(theme)")
            tap("focus.start")
            waitFor("focus.pause")
            attachScreenshot("focus-running-\(theme)")
            app.terminate()
        }
    }

    /// iPad: yatayda kronometre ile istatistik yan yana, dikeyde (dar detay sütunu) alt alta.
    func testIPadLayoutAdaptsToOrientation() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "Yalnızca iPad")
        defer { XCUIDevice.shared.orientation = .portrait }
        launch(seed: "history", theme: "dark")
        waitFor("focus.start")
        XCUIDevice.shared.orientation = .landscapeLeft
        waitFor("focus.averageFocus")
        XCTAssertGreaterThan(element("focus.averageFocus").frame.minX, element("focus.clock").frame.maxX)
        attachScreenshot("focus-ipad-landscape")

        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 2)
        waitFor("focus.start")
        let stacked = NSPredicate { _, _ in
            self.element("focus.averageFocus").frame.minY > self.element("focus.start").frame.maxY
        }
        expectation(for: stacked, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        attachScreenshot("focus-ipad-portrait")
    }
}
