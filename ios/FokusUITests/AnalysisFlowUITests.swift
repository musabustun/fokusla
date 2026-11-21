import XCTest

@MainActor
final class AnalysisFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(seed: Bool = false, dark: Bool? = nil) {
        app = XCUIApplication()
        app.launchArguments = ["-FokusUITestMode"]
        if seed { app.launchArguments += ["-FokusUITestAnalysisSeed", "1"] }
        if let dark { app.launchArguments += ["-fokus.theme", dark ? "dark" : "light"] }
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func first(prefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    private func attachScreenshot(_ name: String) {
        // Yatay/dikey ham raster için ekran görüntüsü kısa bir beklemeden sonra alınır.
        Thread.sleep(forTimeInterval: 1.0)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func finishOnboarding() {
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

    private func openAnalysis() {
        let sidebar = element("sidebar")
        if sidebar.waitForExistence(timeout: 3) {
            sidebar.staticTexts["Analiz"].tap()
        } else {
            app.tabBars.buttons["Analiz"].tap()
        }
        XCTAssertTrue(element("screen.analysis").waitForExistence(timeout: 10))
        XCTAssertTrue(first(prefix: "analysis.subject.").waitForExistence(timeout: 10))
    }

    private func type(_ text: String, into identifier: String) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "\(identifier) yok")
        // Dokunuş klavye odağını almayabilir (özellikle ardışık alanlarda): odak gelene dek en çok 4 deneme.
        for _ in 0..<4 {
            field.tap()
            if field.value(forKey: "hasKeyboardFocus") as? Bool == true { break }
            Thread.sleep(forTimeInterval: 0.6)
        }
        field.typeText(text)
    }

    private func hasText(_ fragment: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }

    // MARK: - Testler

    /// Konu sayfasından test ekle → konu analizinde net görünür (D 12, Y 4 → net 11,00).
    func testAddTestShowsNetInTopicAnalysis() {
        launch()
        finishOnboarding()
        openAnalysis()

        first(prefix: "analysis.subject.").tap()
        let topicRow = first(prefix: "analysis.topic.")
        XCTAssertTrue(topicRow.waitForExistence(timeout: 5))
        topicRow.tap()

        XCTAssertTrue(element("analysis.addFirstTest").waitForExistence(timeout: 5))
        element("analysis.addFirstTest").tap()
        XCTAssertTrue(element("analysis.testSheet").waitForExistence(timeout: 5))

        type("20", into: "analysis.field.questionCount")
        type("12", into: "analysis.field.correct")
        type("4", into: "analysis.field.wrong")
        // Boş otomatik: 20 − 12 − 4 = 4; önizleme neti gösterir.
        XCTAssertTrue(hasText("Net: 11,00").waitForExistence(timeout: 5))
        app.buttons["analysis.save"].tap()

        XCTAssertTrue(element("analysis.summary.net").waitForExistence(timeout: 5))
        XCTAssertTrue(hasText("11,00").waitForExistence(timeout: 5), "Net 11,00 görünmeli")
        XCTAssertTrue(hasText("12D 4Y 4B").waitForExistence(timeout: 5), "Test satırı görünmeli")
        attachScreenshot("analysis-topic-after-add")
    }

    /// Geçersiz form kaydedilmez ve hata gösterir.
    func testInvalidFormShowsErrorAndDoesNotSave() {
        launch()
        finishOnboarding()
        openAnalysis()
        element("analysis.addFirstTest").tap()
        XCTAssertTrue(element("analysis.testSheet").waitForExistence(timeout: 5))
        app.buttons["analysis.save"].tap()
        XCTAssertTrue(hasText("Ders seçmelisin.").waitForExistence(timeout: 5))
        XCTAssertTrue(element("analysis.testSheet").exists)
    }

    /// Kullanıcı dersi ekle → listede görünür.
    func testAddCustomSubject() {
        launch()
        finishOnboarding()
        openAnalysis()
        element("analysis.addSubject").tap()
        XCTAssertTrue(element("analysis.subjectSheet").waitForExistence(timeout: 5))
        type("Problemler", into: "analysis.field.name")
        app.buttons["analysis.save"].tap()
        XCTAssertTrue(element("analysis.subjectSheet").waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Problemler"].waitForExistence(timeout: 5))
    }

    /// iPad yatayda ders listesi ve ayrıntı yan yana; ders seçimi ayrıntıyı açar. (iPhone'da atlanır.)
    func testIPadLandscapeShowsSplitView() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "Yalnızca iPad")
        launch(seed: true, dark: true)
        finishOnboarding()
        openAnalysis()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(element("analysis.sidebar").waitForExistence(timeout: 10), "Yatayda ders listesi yan panelde olmalı")
        first(prefix: "analysis.subject.").tap()
        XCTAssertTrue(element("analysis.subjectDetail").waitForExistence(timeout: 5))
        XCTAssertTrue(element("analysis.sidebar").exists, "Ders seçilince liste yan yana kalmalı")
        attachScreenshot("analysis-ipad-split-dark")
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Ekran görüntüleri (örnek veriyle)

    private func captureFlow(_ mode: String) {
        attachScreenshot("analysis-overview-\(mode)")

        app.swipeUp()
        attachScreenshot("analysis-overview-scrolled-\(mode)")
        app.swipeDown()

        first(prefix: "analysis.subject.").tap()
        XCTAssertTrue(element("analysis.subjectDetail").waitForExistence(timeout: 5))
        attachScreenshot("analysis-subject-\(mode)")

        let topicRow = first(prefix: "analysis.topic.")
        XCTAssertTrue(topicRow.waitForExistence(timeout: 5))
        topicRow.tap()
        XCTAssertTrue(element("analysis.topicDetail").waitForExistence(timeout: 5))
        attachScreenshot("analysis-topic-\(mode)")

        element("analysis.addTest").tap()
        XCTAssertTrue(element("analysis.testSheet").waitForExistence(timeout: 5))
        attachScreenshot("analysis-sheet-\(mode)")
    }

    func testScreenshotsDark() {
        launch(seed: true, dark: true)
        finishOnboarding()
        openAnalysis()
        captureFlow("dark")
    }

    func testScreenshotsLightAndWeakestTopics() {
        launch(seed: true, dark: false)
        finishOnboarding()
        openAnalysis()
        XCTAssertTrue(element("analysis.trend").waitForExistence(timeout: 5))
        XCTAssertTrue(first(prefix: "analysis.weak.").waitForExistence(timeout: 5), "En zayıf konu görünmeli")
        captureFlow("light")
    }
}
