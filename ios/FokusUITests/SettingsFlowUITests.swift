import XCTest

/// Ayarlar modülü duman testleri: alan değiştir, tema değiştir, günlük hedef ayarla, hatırlatma aç,
/// tüm verileri sil (çift onay → onboarding'e dönüş). Bildirim servisi UI test modunda sahtedir.
@MainActor
final class SettingsFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-FokusUITestMode"]
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func skipOnboarding() {
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
    }

    private func openSettings() {
        let sidebar = element("sidebar")
        if sidebar.waitForExistence(timeout: 3) {
            let item = sidebar.buttons["Ayarlar"].exists ? sidebar.buttons["Ayarlar"] : sidebar.staticTexts["Ayarlar"]
            item.tap()
        } else {
            app.tabBars.buttons["Ayarlar"].tap()
        }
        XCTAssertTrue(element("screen.settings").waitForExistence(timeout: 5))
    }

    /// Öğe görünene kadar ekranı yukarı kaydırır.
    private func reveal(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier)
        var attempts = 0
        while !(target.exists && target.isHittable) && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(target.exists && target.isHittable, "\(identifier) görünmüyor", file: file, line: line)
    }

    /// Ekran görüntüsünü test sonucuna ekler; `FOKUS_SHOTS_DIR` verilirse PNG olarak da yazar.
    private func shot(_ name: String) {
        Thread.sleep(forTimeInterval: 1.0)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = ProcessInfo.processInfo.environment["FOKUS_SHOTS_DIR"] {
            let suffix = ProcessInfo.processInfo.environment["FOKUS_SHOTS_SUFFIX"] ?? ""
            let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name)\(suffix).png")
            try? screenshot.pngRepresentation.write(to: url)
        }
    }

    func testChangeFieldKeepsProfileAndUpdatesRow() {
        skipOnboarding()
        openSettings()
        XCTAssertTrue(element("settings.row.field").staticTexts["Sayısal"].waitForExistence(timeout: 5))
        shot("settings-top")
        element("settings.row.field").tap()
        XCTAssertTrue(element("settings.field.EA").waitForExistence(timeout: 5))
        shot("settings-field-sheet")
        element("settings.field.EA").tap()
        XCTAssertTrue(element("settings.row.field").staticTexts["Eşit Ağırlık"].waitForExistence(timeout: 5))
    }

    func testChangeDisplayName() {
        skipOnboarding()
        openSettings()
        element("settings.row.name").tap()
        let field = app.textFields["settings.name.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Ada")
        element("settings.name.save").tap()
        XCTAssertTrue(element("settings.row.name").staticTexts["Ada"].waitForExistence(timeout: 5))
    }

    func testChangeAppearance() {
        skipOnboarding()
        openSettings()
        reveal("settings.appearance")
        element("settings.appearance").tap()
        let dark = app.buttons["Koyu"]
        XCTAssertTrue(dark.waitForExistence(timeout: 5))
        dark.tap()
        XCTAssertTrue(element("settings.appearance").staticTexts["Koyu"].waitForExistence(timeout: 5)
            || (element("settings.appearance").label.contains("Koyu")))
        shot("settings-dark")
    }

    func testSetDailyGoalAndReminders() {
        skipOnboarding()
        openSettings()
        reveal("settings.goal")
        element("settings.goal").tap()
        let option = app.buttons["3 saat"]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        option.tap()
        XCTAssertTrue(
            element("settings.goal").staticTexts["3 saat"].waitForExistence(timeout: 5)
                || element("settings.goal").label.contains("3 saat"))

        reveal("settings.reminder.study")
        let toggle = app.switches["Çalışma hatırlatması"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        // Yük altında (paralel simülatör oturumları) ilk dokunuş kaçabilir: bir kez daha dene.
        if !element("settings.reminder.studyTime").waitForExistence(timeout: 8), (toggle.value as? String) != "1" {
            toggle.tap()
        }
        XCTAssertTrue(element("settings.reminder.studyTime").waitForExistence(timeout: 10))
        shot("settings-goal-reminders")
    }

    func testWipeAllDataReturnsToOnboarding() {
        skipOnboarding()
        openSettings()
        reveal("settings.wipe")
        element("settings.wipe").tap()
        XCTAssertTrue(element("settings.danger.continue").waitForExistence(timeout: 5))
        element("settings.danger.continue").tap()
        XCTAssertTrue(element("settings.danger.wipe").waitForExistence(timeout: 5))
        element("settings.danger.wipe").tap()
        XCTAssertTrue(element("onboarding.start").waitForExistence(timeout: 10))
    }

    func testWipeCanBeCancelledAtFirstStep() {
        skipOnboarding()
        openSettings()
        reveal("settings.wipe")
        element("settings.wipe").tap()
        XCTAssertTrue(element("settings.danger.cancel").waitForExistence(timeout: 5))
        element("settings.danger.cancel").tap()
        XCTAssertTrue(element("screen.settings").waitForExistence(timeout: 5))
        XCTAssertFalse(element("onboarding.start").exists)
    }

    /// Görsel kontrol turu: ekranın tamamını açık ve koyu temada kaydırarak görüntüler.
    func testVisualTourLightAndDark() {
        skipOnboarding()
        openSettings()
        for scheme in ["light", "dark"] {
            if scheme == "dark" {
                reveal("settings.appearance")
                element("settings.appearance").tap()
                app.buttons["Koyu"].tap()
                for _ in 0..<6 { app.swipeDown() }
            }
            for page in 0..<4 {
                shot("settings-\(scheme)-\(page)")
                app.swipeUp()
            }
            if scheme == "light" {
                for _ in 0..<6 { app.swipeDown() }
            }
        }
    }
}
