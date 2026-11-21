import XCTest

/// Kitaplar modülü duman testleri: kitap ekle → ilerleme gir → yüzde güncellenir; geçersiz girdi;
/// arşivle / sil; ayrıca açık/koyu temada ekran görüntüleri (`-FokusUITestBooksSeed demo`).
@MainActor
final class BooksFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Yardımcılar

    private func launch(seed: Bool = false, theme: String? = nil) {
        app = XCUIApplication()
        var arguments = ["-FokusUITestMode"]
        if seed { arguments += ["-FokusUITestBooksSeed", "demo"] }
        if let theme { arguments += ["-fokus.theme", theme] }
        app.launchArguments = arguments
        app.launch()
        skipOnboardingAndOpenBooks()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// iPad (kenar çubuğu var) mı, iPhone mu?
    private var isSidebarLayout: Bool { element("sidebar").exists }

    private func skipOnboardingAndOpenBooks() {
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

        // iPhone: Bugün kısayolu; iPad: kenar çubuğu.
        let sidebar = element("sidebar")
        if sidebar.waitForExistence(timeout: 3) {
            let row = sidebar.staticTexts["Kitaplar"].exists ? sidebar.staticTexts["Kitaplar"] : sidebar.buttons["Kitaplar"]
            row.tap()
        } else {
            tap("today.shortcut.books")
        }
        XCTAssertTrue(element("screen.books").waitForExistence(timeout: 5))
    }

    private func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "\(identifier) yok", file: file, line: line)
        target.tap()
    }

    private func type(_ text: String, into identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = element(identifier)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "\(identifier) yok", file: file, line: line)
        field.tap()
        field.typeText(text)
    }

    /// Kaydet'e dokunur; iPad'de klavye tuş önizlemesi ilk dokunuşu yutabildiği için sayfa kapanmadıysa
    /// bir kez daha dener. `sheetIdentifier` kapanması beklenen sayfadır.
    private func tapSave(_ identifier: String, closing sheetIdentifier: String, file: StaticString = #filePath, line: UInt = #line) {
        for attempt in 1...3 {
            tap(identifier, file: file, line: line)
            let sheet = element(sheetIdentifier)
            let gone = NSPredicate(format: "exists == false")
            if XCTWaiter().wait(for: [expectation(for: gone, evaluatedWith: sheet)], timeout: 3) == .completed { return }
            if attempt == 3 { XCTFail("\(sheetIdentifier) kapanmadı", file: file, line: line) }
        }
    }

    private func attachScreenshot(_ name: String) {
        // Sayfa/animasyon otursun (özellikle yatay ve sheet geçişleri).
        Thread.sleep(forTimeInterval: 1.0)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForLabel(
        _ identifier: String, equals expected: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "\(identifier) yok", file: file, line: line)
        let matches = NSPredicate(format: "label == %@", expected)
        let result = XCTWaiter().wait(for: [expectation(for: matches, evaluatedWith: target)], timeout: 5)
        XCTAssertEqual(
            result, .completed, "\(identifier): beklenen '\(expected)', bulunan '\(target.label)'", file: file,
            line: line)
    }

    /// Başlığı içeren kitap satırı.
    private func row(titled title: String) -> XCUIElement {
        app.buttons.matching(identifier: "book.row").matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
    }

    /// iPhone'da listeden satıra dokunup detayı açar; iPad'de satır seçilir (yan panel).
    private func openDetail(ofRow row: XCUIElement) {
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(element("book.detail.percent").waitForExistence(timeout: 5))
    }

    /// iPhone'da itilmiş detaydan listeye döner (iPad'de gerekmez).
    private func backToListIfNeeded() {
        guard !isSidebarLayout else { return }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element("books.tab").waitForExistence(timeout: 5))
    }

    // MARK: Testler

    func testAddBookEnterProgressUpdatesPercent() {
        launch(theme: "dark")

        tap("books.addFirst")
        type("UI Test Kitabı", into: "book.form.title")
        type("100", into: "book.form.total")
        attachScreenshot("form")
        tapSave("book.form.save", closing: "book.form")

        // iPad'de yeni kitap otomatik seçilir; iPhone'da listeden açılır.
        if !element("book.detail.percent").waitForExistence(timeout: 3) {
            openDetail(ofRow: row(titled: "UI Test Kitabı"))
        }
        waitForLabel("book.detail.percent", equals: "%0")

        tap("book.detail.addProgress")
        type("40", into: "book.progress.reached")
        attachScreenshot("progress-sheet")
        tapSave("book.progress.save", closing: "book.progress")

        waitForLabel("book.detail.percent", equals: "%40")
        waitForLabel("book.detail.position", equals: "Test 40")

        // Toplamı aşan ilerleme (150 / 100): yüzde %100'de sınırlanır, kitap tamamlandı olur.
        tap("book.detail.addProgress")
        let reached = element("book.progress.reached")
        XCTAssertTrue(reached.waitForExistence(timeout: 5))
        reached.tap()
        reached.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "150")
        tapSave("book.progress.save", closing: "book.progress")
        waitForLabel("book.detail.percent", equals: "%100")
    }

    func testInvalidInputShowsErrors() {
        launch(theme: "dark")

        tap("books.addFirst")
        tap("book.form.save")
        waitForLabel("book.form.error", equals: "Kitap adı boş olamaz.")

        type("Hatalı Toplam", into: "book.form.title")
        type("0", into: "book.form.total")
        // iPad'de klavye tuş önizlemesi ilk dokunuşu yutabilir: hata metni değişene dek en çok 3 deneme.
        let expected = "Toplam pozitif bir tam sayı olmalı."
        for _ in 1...3 where element("book.form.error").label != expected {
            tap("book.form.save")
            _ = XCTWaiter().wait(
                for: [expectation(for: NSPredicate(format: "label == %@", expected), evaluatedWith: element("book.form.error"))],
                timeout: 2)
        }
        waitForLabel("book.form.error", equals: expected)

        tap("book.form.cancel")
        XCTAssertFalse(element("book.row").waitForExistence(timeout: 1), "iptal kitap eklememeli")
    }

    func testArchiveMovesBookToFinished() {
        launch(seed: true, theme: "dark")
        let title = "TYT Matematik Soru Bankası"

        openDetail(ofRow: row(titled: title))
        tap("book.detail.archive")
        backToListIfNeeded()

        // Arşivlenen kitap "Devam eden"den çıkar, "Biten"de görünür.
        XCTAssertFalse(row(titled: title).waitForExistence(timeout: 1))
        element("books.tab").buttons["Biten"].tap()
        XCTAssertTrue(row(titled: title).waitForExistence(timeout: 5))
    }

    func testDeleteBookRemovesItFromList() {
        launch(seed: true, theme: "dark")
        let title = "Kimya Soru Bankası"

        openDetail(ofRow: row(titled: title))
        tap("book.detail.delete")
        let confirm = app.buttons["Sil"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        // iPhone'da silinen kitabın ekranı kendiliğinden kapanır (listeye döner); iPad'de panel boşalır.
        XCTAssertTrue(element("books.tab").waitForExistence(timeout: 5), "silince liste görünmeli")
        XCTAssertFalse(row(titled: title).waitForExistence(timeout: 2))
    }

    func testScreenshotsDark() { captureScreenshots(theme: "dark") }
    func testScreenshotsLight() { captureScreenshots(theme: "light") }

    private func captureScreenshots(theme: String) {
        launch(seed: true, theme: theme)
        XCTAssertTrue(app.buttons.matching(identifier: "book.row").firstMatch.waitForExistence(timeout: 5))
        attachScreenshot("\(theme)-list")

        openDetail(ofRow: row(titled: "TYT Matematik Soru Bankası"))
        attachScreenshot("\(theme)-detail")
        app.swipeUp()
        attachScreenshot("\(theme)-detail-scrolled")
    }
}
