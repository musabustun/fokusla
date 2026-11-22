import XCTest

/// Sosyal modülü duman testleri (sahte servis, `-FokusUITestMode`): önizleme girişi → kullanıcı adı →
/// oda oluştur / katıl / ayrıl; arkadaş isteği; geçersiz kod; açık/koyu ekran görüntüleri.
@MainActor
final class SocialFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Yardımcılar

    private func launch(theme: String? = nil) {
        app = XCUIApplication()
        var arguments = ["-FokusUITestMode"]
        if let theme { arguments += ["-fokus.theme", theme] }
        app.launchArguments = arguments
        app.launch()
        skipOnboardingAndOpenSocial()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func skipOnboardingAndOpenSocial() {
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
            let row = sidebar.staticTexts["Sosyal"].exists ? sidebar.staticTexts["Sosyal"] : sidebar.buttons["Sosyal"]
            row.tap()
        } else {
            tap("today.shortcut.social")
        }
        XCTAssertTrue(element("screen.social").waitForExistence(timeout: 5))
    }

    private func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "\(identifier) yok", file: file, line: line)
        target.tap()
    }

    private func waitFor(_ identifier: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(identifier).waitForExistence(timeout: timeout), "\(identifier) yok", file: file, line: line)
    }

    private func waitForAbsence(_ identifier: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        let gone = NSPredicate(format: "exists == false")
        let result = XCTWaiter().wait(for: [expectation(for: gone, evaluatedWith: element(identifier))], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(identifier) hâlâ var", file: file, line: line)
    }

    /// Alanı doldurur ve klavyede "Git"e basarak formu gönderir.
    private func typeAndSubmit(_ text: String, into identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = element(identifier)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "\(identifier) yok", file: file, line: line)
        field.tap()
        field.typeText(text + "\n")
    }

    private func attachScreenshot(_ name: String) {
        Thread.sleep(forTimeInterval: 1.0)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Önizleme oturumu aç → kullanıcı adı seç → hazır ekran.
    private func signInToPreview(username: String = "ben.yks") {
        waitFor("social.gate")
        tap("social.gate.preview")
        waitFor("social.username")
        typeAndSubmit(username, into: "social.username.field")
        waitFor("social.home")
    }

    // MARK: Testler

    func testGateExplainsAndPreviewLeadsToUsernameThenHome() {
        launch()
        waitFor("social.gate.signIn")
        waitFor("social.gate.preview")
        XCTAssertTrue(app.staticTexts["Birlikte çalışmak için giriş yap"].exists)
        attachScreenshot("social-gate")

        tap("social.gate.preview")
        waitFor("social.username")
        // Geçersiz ad: hata görünür, ilerlemez.
        typeAndSubmit("1ab", into: "social.username.field")
        waitFor("social.username.field.error")
        XCTAssertFalse(element("social.home").exists)
        // Alınmış ad.
        let field = element("social.username.field")
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3))
        field.typeText("elif.say\n")
        waitFor("social.username.field.error")
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        field.typeText("ben.yks\n")
        waitFor("social.home")
        waitFor("social.friend.elif.say")
        waitFor("social.friend.mert_ayt")
        waitFor("social.request.accept.zeynep2027")
    }

    func testCreateRoomThenFriendJoinsThenLeave() {
        launch()
        signInToPreview()
        waitFor("social.lobby")

        tap("social.room.create")
        waitFor("social.createRoom")
        tap("social.room.submit")
        waitForAbsence("social.createRoom")

        waitFor("social.room")
        XCTAssertEqual(element("social.room.title").label, "Birlikte çalışalım")
        waitFor("social.member.ben.yks")
        // İlk çevrimiçi arkadaş kısa süre sonra odaya katılır.
        waitFor("social.member.elif.say", timeout: 10)
        XCTAssertTrue(element("social.member.ben.yks").label.contains("ev sahibi"))
        attachScreenshot("social-room-host")

        tap("social.room.leave")
        waitFor("social.lobby")
        XCTAssertFalse(element("social.room").exists)
    }

    func testJoinFriendRoomAndLeave() {
        launch()
        signInToPreview()

        tap("social.room.join.mock-room-sabah")
        waitFor("social.room")
        XCTAssertEqual(element("social.room.title").label, "Sabah kampı")
        waitFor("social.member.elif.say")
        waitFor("social.member.mert_ayt")
        waitFor("social.member.ben.yks")
        XCTAssertTrue(element("social.member.ben.yks").label.contains("(sen)"))
        XCTAssertTrue(element("social.member.elif.say").label.contains("ev sahibi"))

        tap("social.room.leave")
        waitFor("social.lobby")
        waitFor("social.room.join.mock-room-sabah")
    }

    func testJoinByCodeShowsErrorForUnknownCodeThenJoins() {
        launch()
        signInToPreview()

        tap("social.room.join")
        waitFor("social.joinRoom")
        typeAndSubmit("XXXXXX", into: "social.joinCode.field")
        waitFor("social.joinCode.field.error")
        XCTAssertTrue(element("social.joinRoom").exists)

        let field = element("social.joinCode.field")
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6))
        field.typeText("tytmat\n")
        waitForAbsence("social.joinRoom")
        waitFor("social.room")
        XCTAssertEqual(element("social.room.title").label, "TYT Matematik")
        tap("social.room.leave")
        waitFor("social.lobby")
    }

    func testAcceptRequestAddFriendAndRemoveFriend() {
        launch()
        signInToPreview()

        // Gelen isteği kabul et → arkadaş listesine girer.
        tap("social.request.accept.zeynep2027")
        waitFor("social.friend.zeynep2027")
        waitForAbsence("social.request.accept.zeynep2027")

        // Kullanıcı adıyla istek gönder → "Yanıt bekleniyor", kısa süre sonra kabul edilir.
        tap("social.friends.add")
        waitFor("social.addFriend")
        typeAndSubmit("deniz_ea", into: "social.addFriend.field")
        waitForAbsence("social.addFriend")
        waitFor("social.friend.deniz_ea", timeout: 10)

        // Arkadaşlıktan çıkar.
        tap("social.friend.deniz_ea")
        waitFor("social.friendSheet")
        tap("social.friendSheet.remove")
        waitForAbsence("social.friend.deniz_ea")
    }

    func testAddFriendRejectsUnknownAndSelfUsernames() {
        launch()
        signInToPreview()

        tap("social.friends.add")
        waitFor("social.addFriend")
        typeAndSubmit("kimse_yok", into: "social.addFriend.field")
        waitFor("social.addFriend.field.error")
        XCTAssertTrue(element("social.addFriend").exists)
    }

    func testScreenshotRoomDark() {
        launch(theme: "dark")
        signInToPreview()
        tap("social.room.join.mock-room-sabah")
        waitFor("social.room")
        attachScreenshot("social-room-dark")

        // iPad: yatayda iki sütun düzeni.
        if element("sidebar").exists {
            XCUIDevice.shared.orientation = .landscapeLeft
            waitFor("social.room")
            attachScreenshot("social-room-landscape")
            XCUIDevice.shared.orientation = .portrait
        }
    }
}
