import XCTest

/// Sosyal duman testleri: GERÇEK `CloudSocialService` + bellek içi sahte sunucu (`SocialDemoWorld`). Örnek kişiler:
/// `zeynep2027` bana istek gönderir, `elif.say` isteğimi kabul eder ve "Sabah kampı" odasının sahibidir.
@MainActor
final class SocialFlowUITests: XCTestCase {
    private static let demoTimeout: TimeInterval = 15

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Yardımcılar

    private func launch(signedIn: Bool = true, theme: String? = nil) {
        app = XCUIApplication()
        var arguments = ["-FokusUITestMode"]
        if signedIn { arguments.append("-FokusUITestSocialSignedIn") }
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
            scrollTo("today.shortcut.social")
            tap("today.shortcut.social")
        }
        XCTAssertTrue(element("screen.social").waitForExistence(timeout: 5))
    }

    private func scrollTo(_ identifier: String) {
        for _ in 0..<6 where !element(identifier).isHittable { app.swipeUp() }
    }

    private func tap(_ identifier: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "\(identifier) yok", file: file, line: line)
        if !target.isHittable { scrollTo(identifier) }
        target.tap()
    }

    private func waitFor(_ identifier: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(identifier).waitForExistence(timeout: timeout), "\(identifier) yok", file: file, line: line)
    }

    private func waitForAbsence(_ identifier: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(identifier).waitForNonExistence(timeout: timeout), "\(identifier) hâlâ var", file: file, line: line)
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

    private func chooseUsername(_ username: String = "ben.yks") {
        waitFor("social.username", timeout: 10)
        typeAndSubmit(username, into: "social.username.field")
        waitFor("social.home", timeout: 10)
    }

    private func befriendElif() {
        tap("social.friends.add")
        waitFor("social.addFriend")
        typeAndSubmit("elif.say", into: "social.addFriend.field")
        waitForAbsence("social.addFriend")
        waitFor("social.friend.elif.say", timeout: Self.demoTimeout)
    }

    // MARK: Testler

    func testGateExplainsSignIn() {
        launch(signedIn: false)
        waitFor("social.gate.signIn")
        XCTAssertTrue(app.staticTexts["Birlikte çalışmak için giriş yap"].exists)
        XCTAssertFalse(element("social.gate.preview").exists)
        attachScreenshot("social-gate")
    }

    func testUsernameValidationThenHomeAndIncomingRequest() {
        launch()
        waitFor("social.username", timeout: 10)
        typeAndSubmit("1ab", into: "social.username.field")
        waitFor("social.username.field.error")
        XCTAssertFalse(element("social.home").exists)
        // Alınmış ad.
        let field = element("social.username.field")
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3))
        field.typeText("elif.say\n")
        waitFor("social.username.field.error")
        XCTAssertFalse(element("social.home").exists)
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        field.typeText("ben.yks\n")
        waitFor("social.home", timeout: 10)

        // Gelen isteği kabul et → arkadaş listesine girer.
        tap("social.request.accept.zeynep2027", timeout: Self.demoTimeout)
        waitFor("social.friend.zeynep2027", timeout: Self.demoTimeout)
        waitForAbsence("social.request.accept.zeynep2027")
        attachScreenshot("social-home")
    }

    func testRequestByUsernameThenJoinFriendRoomAndLeaveThenRemove() {
        launch()
        chooseUsername()
        befriendElif()

        // Arkadaşın odasına katıl ve çık.
        XCTAssertTrue(app.staticTexts["Sabah kampı"].waitForExistence(timeout: Self.demoTimeout))
        let join = app.buttons["Sabah kampı odasına katıl"]
        XCTAssertTrue(join.waitForExistence(timeout: 5))
        join.tap()
        waitFor("social.room", timeout: 10)
        XCTAssertEqual(element("social.room.title").label, "Sabah kampı")
        waitFor("social.member.elif.say")
        waitFor("social.member.ben.yks")
        XCTAssertTrue(element("social.member.elif.say").label.contains("ev sahibi"))
        XCTAssertTrue(element("social.member.ben.yks").label.contains("(sen)"))
        attachScreenshot("social-room")
        tap("social.room.leave")
        waitFor("social.lobby", timeout: 10)

        tap("social.friend.elif.say")
        waitFor("social.friendSheet")
        tap("social.friendSheet.remove")
        waitForAbsence("social.friend.elif.say")
    }

    func testUnknownUsernameAndInviteLink() {
        launch()
        chooseUsername()
        tap("social.friends.add")
        waitFor("social.addFriend")
        typeAndSubmit("kimse_yok", into: "social.addFriend.field")
        waitFor("social.addFriend.field.error")

        app.buttons["Bağlantı"].tap()
        tap("social.addFriend.createInvite")
        waitFor("social.addFriend.invite.share", timeout: 10)
        attachScreenshot("social-invite-link")

        app.buttons["Davetim var"].tap()
        typeAndSubmit("https://example.com/share/x", into: "social.pasteInvite.field")
        waitFor("social.pasteInvite.field.error")
        tap("social.addFriend.cancel")

        // Kullanılmamış bağlantı geri çekilebilir.
        tap("social.invite.cancel", timeout: 10)
        waitForAbsence("social.invite.cancel")
    }

    func testCreateRoomShareAndClose() {
        launch(theme: "dark")
        chooseUsername()
        tap("social.room.create")
        waitFor("social.createRoom")
        tap("social.room.submit")
        waitForAbsence("social.createRoom")
        waitFor("social.room")
        XCTAssertEqual(element("social.room.title").label, "Birlikte çalışalım")
        tap("social.room.share")
        waitFor("social.room.invite.share")
        attachScreenshot("social-room-share-dark")
        tap("social.roomShare.cancel")
        tap("social.room.leave")
        waitFor("social.lobby", timeout: 10)
    }

    func testDeleteSocialProfileReturnsToUsername() {
        launch()
        chooseUsername()
        tap("social.profile.delete")
        let confirm = app.buttons["Kalıcı olarak sil"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        waitFor("social.username", timeout: 10)
    }
}
