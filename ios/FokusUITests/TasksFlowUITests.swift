import XCTest

/// Görevler modülü duman testi: rutin ve ödev ekle → Bugün listesinde gör → tamamla → ayrıntı.
@MainActor
final class TasksFlowUITests: XCTestCase {
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

    private func openTasks() {
        let sidebar = element("sidebar")
        if sidebar.waitForExistence(timeout: 3) {
            let item = sidebar.buttons["Görevler"].exists ? sidebar.buttons["Görevler"] : sidebar.staticTexts["Görevler"]
            item.tap()
        } else {
            app.tabBars.buttons["Görevler"].tap()
        }
        XCTAssertTrue(element("screen.tasks").waitForExistence(timeout: 5))
    }

    private func addTask(title: String, kind: String? = nil) {
        element("tasks.add").tap()
        let titleField = app.textFields["task.form.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        if let kind { element("task.form.kind").buttons[kind].tap() }
        titleField.tap()
        titleField.typeText(title)
        element("task.form.save").tap()
        XCTAssertTrue(element("task.check.\(title)").waitForExistence(timeout: 5), "\(title) listede yok")
    }

    private func isDone(_ title: String) -> Bool {
        (element("task.check.\(title)").value as? String) == "Tamamlandı"
    }

    /// Ekran görüntüsünü test sonucuna ekler; `FOKUS_SHOTS_DIR` verilirse PNG olarak da yazar.
    private func shot(_ name: String, fullScreen: Bool = false) {
        let screenshot = fullScreen ? XCUIScreen.main.screenshot() : app.screenshot()
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

    func testAddRoutineAndAssignmentThenComplete() {
        skipOnboarding()
        openTasks()
        // Boş durum
        XCTAssertTrue(element("tasks.empty.add").waitForExistence(timeout: 5))

        addTask(title: "Paragraf sorusu")
        addTask(title: "Fizik föyü", kind: "Ödev")

        // Bugün listesinde ikisi de açık
        XCTAssertFalse(isDone("Paragraf sorusu"))
        XCTAssertFalse(isDone("Fizik föyü"))
        XCTAssertTrue(app.staticTexts["0/2"].exists)

        element("task.check.Paragraf sorusu").tap()
        element("task.check.Fizik föyü").tap()
        XCTAssertTrue(isDone("Paragraf sorusu"))
        XCTAssertTrue(isDone("Fizik föyü"))
        XCTAssertTrue(app.staticTexts["2/2"].exists)

        // Geri al
        element("task.check.Fizik föyü").tap()
        XCTAssertFalse(isDone("Fizik föyü"))
        XCTAssertTrue(app.staticTexts["1/2"].exists)

        // Ayrıntı: rutin istatistiği ve geri al
        element("task.open.Paragraf sorusu").tap()
        XCTAssertTrue(element("task.detail").waitForExistence(timeout: 5))
        XCTAssertTrue(element("task.detail.stats").exists)
        XCTAssertTrue(app.buttons["Geri al"].exists)
    }

    func testDeleteTask() {
        skipOnboarding()
        openTasks()
        addTask(title: "Silinecek")
        element("task.open.Silinecek").tap()
        XCTAssertTrue(element("task.detail.delete").waitForExistence(timeout: 5))
        element("task.detail.delete").tap()
        XCTAssertTrue(element("task.detail.confirmDelete").waitForExistence(timeout: 5))
        element("task.detail.confirmDelete").tap()
        XCTAssertTrue(element("tasks.empty.add").waitForExistence(timeout: 5))
        XCTAssertFalse(element("task.check.Silinecek").exists)
    }

    /// Görsel inceleme: yalnızca `FOKUS_SHOTS_DIR` verildiğinde çalışır.
    func testReviewScreenshots() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FOKUS_SHOTS_DIR"] != nil)
        skipOnboarding()
        openTasks()
        shot("tasks-empty")

        addTask(title: "50 paragraf sorusu")
        addTask(title: "Fizik ödev föyü 3", kind: "Ödev")
        element("task.check.50 paragraf sorusu").tap()
        shot("tasks-today")

        element("tasks.mode").buttons["Tümü"].tap()
        shot("tasks-all")
        element("tasks.mode").buttons["Bugün"].tap()

        element("task.open.50 paragraf sorusu").tap()
        XCTAssertTrue(element("task.detail").waitForExistence(timeout: 5))
        shot("tasks-detail")
        if element("task.detail.close").exists { element("task.detail.close").tap() }

        element("tasks.add").tap()
        XCTAssertTrue(element("task.form.title").waitForExistence(timeout: 5))
        element("task.form.frequency").buttons["Belirli günler"].tap()
        element("task.form.weekday.1").tap()
        element("task.form.weekday.3").tap()
        shot("tasks-form-routine")

        // iPad yatay: liste + yan ayrıntı paneli
        element("task.form.cancel").tap()
        let isPad = app.windows.firstMatch.frame.width >= 700
        if isPad {
            XCUIDevice.shared.orientation = .landscapeLeft
            XCTAssertTrue(element("tasks.add").waitForExistence(timeout: 5))
            element("task.open.50 paragraf sorusu").tap()
            XCTAssertTrue(element("task.detail").waitForExistence(timeout: 5))
            XCTAssertFalse(element("task.detail.close").exists, "Yatay iPad'de ayrıntı sheet değil yan panel olmalı")
            Thread.sleep(forTimeInterval: 1.5)  // döndürme animasyonu bitsin
            shot("tasks-split-landscape", fullScreen: true)
            XCUIDevice.shared.orientation = .portrait
        }
    }
}
