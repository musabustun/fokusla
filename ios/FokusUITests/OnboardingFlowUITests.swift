import XCTest

@MainActor
final class OnboardingFlowUITests: XCTestCase {
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

    private func goToAccountStep() {
        XCTAssertTrue(element("onboarding.start").waitForExistence(timeout: 10))
        element("onboarding.start").tap()
        XCTAssertTrue(element("onboarding.field.SAY").waitForExistence(timeout: 5))
        element("onboarding.field.SAY").tap()
        XCTAssertTrue(element("onboarding.continue").waitForExistence(timeout: 5))
        element("onboarding.continue").tap()
        // Temanı seç: varsayılan palet (Kahve) seçili gelir; Devam.
        XCTAssertTrue(element("palette.coffee").waitForExistence(timeout: 5))
        element("onboarding.continue").tap()
    }

    func testOnboardingThenShell() {
        goToAccountStep()
        XCTAssertTrue(element("onboarding.skip").waitForExistence(timeout: 5))
        element("onboarding.skip").tap()
        XCTAssertTrue(element("screen.today").waitForExistence(timeout: 10))

        let sidebar = element("sidebar")
        if sidebar.waitForExistence(timeout: 3) {
            for label in ["Bugün", "Odak", "Analiz", "Kitaplar", "Görevler", "Sosyal", "Ayarlar"] {
                XCTAssertTrue(
                    sidebar.staticTexts[label].exists || sidebar.buttons[label].exists,
                    "Kenar çubuğunda \(label) yok"
                )
            }
        } else {
            for label in ["Bugün", "Odak", "Analiz", "Görevler", "Ayarlar"] {
                XCTAssertTrue(app.tabBars.buttons[label].exists, "Tab bar'da \(label) yok")
            }
            XCTAssertFalse(app.tabBars.buttons["Kitaplar"].exists)
            element("today.shortcut.books").tap()
            XCTAssertTrue(element("screen.books").waitForExistence(timeout: 5))
        }
    }

    func testContinueDisabledUntilFieldChosen() {
        XCTAssertTrue(element("onboarding.start").waitForExistence(timeout: 10))
        element("onboarding.start").tap()
        XCTAssertTrue(element("onboarding.continue").waitForExistence(timeout: 5))
        XCTAssertFalse(element("onboarding.continue").isEnabled)
        XCTAssertTrue(element("onboarding.field.EA").waitForExistence(timeout: 5))
        element("onboarding.field.EA").tap()
        XCTAssertTrue(element("onboarding.continue").isEnabled)
    }

    func testThemeStepListsAllPalettesAndSelects() {
        XCTAssertTrue(element("onboarding.start").waitForExistence(timeout: 10))
        element("onboarding.start").tap()
        element("onboarding.field.SAY").tap()
        element("onboarding.continue").tap()
        for palette in ["coffee", "mono", "strawberry", "matcha", "blueberry", "lemonade"] {
            XCTAssertTrue(element("palette.\(palette)").waitForExistence(timeout: 5), "\(palette) yok")
        }
        element("palette.matcha").tap()
        XCTAssertTrue(element("palette.matcha").isSelected)
        XCTAssertFalse(element("palette.coffee").isSelected)
    }

    func testSignInWithAppleButtonPresentOnLastStep() {
        goToAccountStep()
        XCTAssertTrue(element("onboarding.signInWithApple").waitForExistence(timeout: 5))
        XCTAssertTrue(element("onboarding.skip").exists)
    }
}
