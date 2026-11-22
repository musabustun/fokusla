import XCTest

/// Bugün modülü duman testi: boş durum, görev tamamlama, "Odak başlat" ile Odak'a geçiş.
@MainActor
final class TodayFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(seed: String? = nil) {
        app = XCUIApplication()
        app.launchArguments = ["-FokusUITestMode"] + (seed.map { ["-FokusUITestTodaySeed", $0] } ?? [])
        app.launch()
        skipOnboarding()
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

    /// Öğe ekranda dokunulabilir olana dek yukarı kaydırır.
    private func scrollIntoView(_ target: XCUIElement) {
        var attempts = 0
        while !target.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(target.isHittable, "\(target) ekrana getirilemedi")
    }

    private func isDone(_ title: String) -> Bool {
        (element("today.task.\(title)").value as? String) == "Tamamlandı"
    }

    private func shot(_ name: String) {
        let screenshot = app.screenshot()
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

    func testEmptyStateShowsMotivatingPrompts() {
        launch()
        XCTAssertTrue(element("today.focus.start").exists)
        XCTAssertTrue(element("today.focus.total").exists)
        XCTAssertTrue(element("today.focus.goalHint").exists)
        XCTAssertTrue(element("today.tasks.empty").exists)
        XCTAssertTrue(element("today.tests.empty").exists)
        XCTAssertTrue(element("today.books.empty").exists)
        XCTAssertFalse(element("today.focus.active").exists)
    }

    func testCompleteAndUndoTask() {
        launch(seed: "tasks")
        let routine = element("today.task.Paragraf 20 soru")
        XCTAssertTrue(routine.waitForExistence(timeout: 5))
        scrollIntoView(routine)
        XCTAssertFalse(isDone("Paragraf 20 soru"))
        XCTAssertEqual(element("today.tasks.progress").label, "1 görevin 0 tanesi tamamlandı")

        routine.tap()
        XCTAssertTrue(isDone("Paragraf 20 soru"))
        XCTAssertEqual(element("today.tasks.progress").label, "1 görevin 1 tanesi tamamlandı")
        XCTAssertTrue(element("today.tasks.allDone").exists)

        routine.tap()
        XCTAssertFalse(isDone("Paragraf 20 soru"))
        XCTAssertFalse(element("today.tasks.allDone").exists)
    }

    func testStartFocusOpensFocusScreen() {
        launch()
        element("today.focus.start").tap()
        XCTAssertTrue(element("screen.focus").waitForExistence(timeout: 5))
    }

    /// Görsel inceleme: yalnızca `FOKUS_SHOTS_DIR` verildiğinde çalışır.
    func testReviewScreenshots() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FOKUS_SHOTS_DIR"] != nil)
        launch(seed: "full")
        XCTAssertTrue(element("today.tasks").waitForExistence(timeout: 5))
        shot("today-full-1")
        app.swipeUp()
        shot("today-full-2")
        app.swipeUp()
        shot("today-full-3")
    }

    func testReviewEmptyScreenshots() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FOKUS_SHOTS_DIR"] != nil)
        launch()
        shot("today-empty-1")
        app.swipeUp()
        shot("today-empty-2")
        app.swipeUp()
        shot("today-empty-3")
    }
}
