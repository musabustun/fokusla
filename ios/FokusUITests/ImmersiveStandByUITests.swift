import XCTest

/// StandBy tarzı tam ekran: düzenleme modu (uzun basma / "Özelleştir"), kalıcı tercihler, sayfa
/// açma-kapama, müzik sayfası + köşe çipi (sahte Spotify) ve görsel kontrol ekran görüntüleri.
@MainActor
final class ImmersiveStandByUITests: FocusUITestCase {
    private var pageIndicator: XCUIElement { element("immersive.pageIndicator") }
    private var indicatorValue: String { pageIndicator.exists ? (pageIndicator.value as? String ?? "") : "" }

    // MARK: Düzenleyici + kalıcılık

    /// Uzun bas → düzenleyici; yazı `thin`, renk `matcha`, zemin `aura`; Bitti; yeniden başlatınca korunur.
    func testEditorPersistsClockStyleAccentAndBackdrop() {
        launch(seed: "running", immersivePage: "stopwatch")
        openEditorByLongPress()
        waitFor("immersive.editor.done")
        // Sekmeler arası geçiş.
        tap("immersive.editor.tab.clock")
        tap("immersive.editor.clock.thin")
        tap("immersive.editor.tab.color")
        tap("immersive.editor.accent.matcha")
        tap("immersive.editor.tab.backdrop")
        tap("immersive.editor.backdrop.aura")
        // Canlı tercih: seçili döşemeler `isSelected`.
        XCTAssertTrue(element("immersive.editor.backdrop.aura").isSelected)
        tap("immersive.editor.done")
        XCTAssertTrue(waitForDisappearance(of: element("immersive.editor")))
        waitFor("immersive.page.stopwatch")
        app.terminate()

        // Yeniden başlat: tercihler (App Group defaults) korunur.
        app = XCUIApplication()
        app.launchArguments = ["-FokusUITestMode", "-FokusUITestKeepImmersivePage", "-FokusUITestFocusSeed", "running"]
        app.launch()
        skipOnboardingAndOpenFocus()
        openEditorByLongPress()
        tap("immersive.editor.tab.clock")
        XCTAssertTrue(waitSelected("immersive.editor.clock.thin"), "Yazı stili korunmadı")
        tap("immersive.editor.tab.color")
        XCTAssertTrue(waitSelected("immersive.editor.accent.matcha"), "Renk korunmadı")
        tap("immersive.editor.tab.backdrop")
        XCTAssertTrue(waitSelected("immersive.editor.backdrop.aura"), "Zemin korunmadı")
        // Sonraki testlere sızmasın: varsayılana dön.
        tap("immersive.editor.reset")
        tap("immersive.editor.done")
    }

    /// Saat sayfasını kapat → gösterge "x / 5", saat sayfası kaydırmada yok.
    func testDisablingClockPageRemovesItFromPager() {
        launch(seed: "running", immersivePage: "stopwatch")
        XCTAssertTrue(waitForIndicator(suffix: "1 / 6"))
        openEditorByLongPress()
        tap("immersive.editor.tab.pages")
        tap("immersive.editor.page.clock")
        tap("immersive.editor.done")
        XCTAssertTrue(waitForDisappearance(of: element("immersive.editor")))
        XCTAssertTrue(waitForIndicator(suffix: "1 / 5"), "Gösterge: \(indicatorValue)")
        swipePage(left: true)
        waitFor("immersive.page.ring")
        XCTAssertFalse(element("immersive.page.clock").exists)
        XCTAssertTrue(indicatorValue.hasSuffix("2 / 5"), "Gösterge: \(indicatorValue)")
    }

    /// VoiceOver yolu: kontrol çubuğundaki "Özelleştir" düğmesi düzenleyiciyi açar.
    func testCustomizeButtonOpensEditor() {
        launch(seed: "running", immersivePage: "stopwatch")
        revealImmersiveControls(expecting: "immersive.customize")
        element("immersive.customize").tap()
        waitFor("immersive.editor")
        // Düzenlemede kontroller ve sayfa kaydırma kapalı; oturum sürer.
        XCTAssertFalse(element("immersive.pause").exists)
        XCTAssertFalse(element("immersive.minimize").exists)
        tap("immersive.editor.done")
        XCTAssertTrue(waitForDisappearance(of: element("immersive.editor")))
        waitFor("immersive.clock")
    }

    // MARK: Sayaç anlamı

    /// Moladan dönülmüş oturumda büyük sayaç "son devamdan beri"dir; ikincil satır oturum TOPLAMINI söyler.
    func testStopwatchSecondaryLineShowsSessionTotalAfterBreak() {
        launch(seed: "resumed", immersivePage: "stopwatch")
        waitFor("immersive.secondary")
        XCTAssertEqual(element("immersive.secondary").label, "Toplam")
        XCTAssertTrue(
            (element("immersive.secondary").value as? String ?? "").contains("dk"), "Toplam süre yok")
    }

    // MARK: Müzik

    func testMusicPageAndChipWhenSpotifyConnected() {
        launch(seed: "running", immersivePage: "stopwatch", extraArguments: ["-FokusUITestSpotify", "connected"])
        XCTAssertTrue(waitForIndicator(suffix: "1 / 7"), "Gösterge: \(indicatorValue)")
        // Köşe çipi kronometre sayfasında görünür; dokununca müzik sayfasına gider.
        waitFor("immersive.nowPlayingChip")
        element("immersive.nowPlayingChip").tap()
        waitFor("immersive.page.music")
        XCTAssertTrue(waitForDisappearance(of: element("immersive.nowPlayingChip")), "Çip müzik sayfasında gizli olmalı")
        XCTAssertEqual(element("immersive.nowPlaying.title").label, "Odak Müziği — Sakin Piyano")
        XCTAssertEqual(element("immersive.nowPlaying.artist").label, "Fokus Sessions")
        attachScreenshot("standby-music-portrait-dark")

        let playPause = element("immersive.nowPlaying.playPause")
        XCTAssertEqual(playPause.label, "Duraklat")
        playPause.tap()
        XCTAssertTrue(waitLabel(of: "immersive.nowPlaying.playPause", equals: "Oynat"))
        element("immersive.nowPlaying.playPause").tap()
        XCTAssertTrue(waitLabel(of: "immersive.nowPlaying.playPause", equals: "Duraklat"))
    }

    func testNoMusicPageOrChipWhenSpotifyDisconnected() {
        launch(seed: "running", immersivePage: "stopwatch", extraArguments: ["-FokusUITestSpotify", "disconnected"])
        XCTAssertTrue(waitForIndicator(suffix: "1 / 6"), "Gösterge: \(indicatorValue)")
        XCTAssertFalse(element("immersive.nowPlayingChip").exists)
        XCTAssertFalse(element("immersive.page.music").exists)
    }

    // MARK: Ekran görüntüleri

    /// Düzenleyicinin her sekmesi (koyu) + birkaçı açık temada.
    func testEditorScreenshots() {
        for theme in ["dark", "light"] {
            launch(seed: "running", theme: theme, immersivePage: "clock")
            openEditorByLongPress()
            for tab in theme == "dark" ? ["pages", "clock", "color", "backdrop"] : ["pages", "clock"] {
                tap("immersive.editor.tab.\(tab)")
                Thread.sleep(forTimeInterval: 0.5)
                attachScreenshot("standby-editor-\(tab)-\(theme)")
            }
            app.terminate()
        }
    }

    /// Gece kırmızısı (zorla açık): kronometre ve gece sayfası; açık temada kronometre.
    func testNightRedScreenshots() {
        launch(
            seed: "running", theme: "dark", immersivePage: "stopwatch",
            extraArguments: ["-FokusUITestStandBy", #"{"nightMode":"on"}"#])
        waitFor("immersive.page.stopwatch")
        Thread.sleep(forTimeInterval: 1)
        attachScreenshot("standby-night-red-stopwatch-dark")
        revealImmersiveControls(expecting: "immersive.pause")
        attachScreenshot("standby-night-red-controls-dark")
        app.terminate()

        launch(
            seed: "running", theme: "dark", immersivePage: "night",
            extraArguments: ["-FokusUITestStandBy", #"{"nightMode":"on"}"#])
        waitFor("immersive.page.night")
        Thread.sleep(forTimeInterval: 1)
        attachScreenshot("standby-night-red-night-dark")
        app.terminate()

        launch(
            seed: "running", theme: "light", immersivePage: "stopwatch",
            extraArguments: ["-FokusUITestStandBy", #"{"clockStyle":"thin","backdrop":"aura","tintedDigits":true}"#])
        waitFor("immersive.page.stopwatch")
        Thread.sleep(forTimeInterval: 1)
        attachScreenshot("standby-thin-aura-stopwatch-light")
    }

    /// Müzik sayfası ve köşe çipi: yatay + açık tema.
    func testMusicScreenshots() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        launch(
            seed: "running", theme: "light", immersivePage: "stopwatch",
            extraArguments: ["-FokusUITestSpotify", "connected"])
        waitFor("immersive.nowPlayingChip")
        attachScreenshot("standby-chip-stopwatch-light")
        element("immersive.nowPlayingChip").tap()
        waitFor("immersive.page.music")
        Thread.sleep(forTimeInterval: 0.6)
        attachScreenshot("standby-music-portrait-light")
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCUIDevice.shared.orientation = .landscapeLeft
            Thread.sleep(forTimeInterval: 1.5)
            attachScreenshot("standby-music-landscape-light")
        }
    }

    // MARK: Yardımcılar

    private func openEditorByLongPress() {
        let root = element("immersive.root")
        XCTAssertTrue(root.waitForExistence(timeout: 8), "immersive.root yok")
        root.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).press(forDuration: 1.2)
        waitFor("immersive.editor")
    }

    private func swipePage(left: Bool) {
        let root = element("immersive.root")
        let start = root.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.85 : 0.15, dy: 0.4))
        let end = root.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.15 : 0.85, dy: 0.4))
        let before = indicatorValue
        start.press(forDuration: 0.05, thenDragTo: end)
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", before), object: pageIndicator)
        _ = XCTWaiter().wait(for: [changed], timeout: 4)
        Thread.sleep(forTimeInterval: 0.3)
    }

    private func waitForIndicator(suffix: String, timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if pageIndicator.exists, indicatorValue.hasSuffix(suffix) { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
    }

    private func waitSelected(_ identifier: String, timeout: TimeInterval = 5) -> Bool {
        let target = element(identifier)
        guard target.waitForExistence(timeout: timeout) else { return false }
        let selected = NSPredicate(format: "isSelected == true")
        return XCTWaiter().wait(
            for: [XCTNSPredicateExpectation(predicate: selected, object: target)], timeout: timeout) == .completed
    }

    private func waitLabel(of identifier: String, equals label: String, timeout: TimeInterval = 5) -> Bool {
        let match = NSPredicate(format: "label == %@", label)
        return XCTWaiter().wait(
            for: [XCTNSPredicateExpectation(predicate: match, object: element(identifier))], timeout: timeout)
            == .completed
    }
}
