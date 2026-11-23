import XCTest

/// Odak tam ekran (StandBy benzeri) görünümü: açılış, sayfalar, kontroller, küçült/yeniden aç, bitir,
/// uzun mola uyarısı ve görsel kontrol matrisi.
@MainActor
final class ImmersiveFocusUITests: FocusUITestCase {
    /// Varsayılan görünür sayfalar (müzik bağlı değilken): `StandByPreferences.defaultPages` eksi `music`.
    private static let pages = ["stopwatch", "clock", "ring", "summary", "night", "sound"]

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private var pageIndicator: XCUIElement { element("immersive.pageIndicator") }

    // MARK: Akış

    /// Başlat → tam ekran → mola → devam → küçült → "Tam ekran" → yeniden aç → bitir → özet.
    func testImmersiveFlowStartPauseResumeMinimizeReopenFinish() {
        launch(immersivePage: "stopwatch")
        tap("focus.start")
        waitFor("immersive.root")
        waitFor("immersive.page.stopwatch")
        XCTAssertEqual(element("immersive.phase").label.lowercased(), "odak")
        // Kronometre akar.
        let ticked = NSPredicate(format: "value != %@", "00:00")
        expectation(for: ticked, evaluatedWith: element("immersive.clock"))
        waitForExpectations(timeout: 6)
        attachScreenshot("immersive-running")

        tapImmersive("immersive.pause")
        waitFor("immersive.resume")
        XCTAssertEqual(element("immersive.phase").label.lowercased(), "mola")
        attachScreenshot("immersive-break")

        tapImmersive("immersive.resume")
        waitFor("immersive.pause")
        XCTAssertEqual(element("immersive.phase").label.lowercased(), "odak")

        minimizeImmersive()
        XCTAssertEqual(phase.lowercased(), "odak", "Küçültünce oturum sürmeli")
        tap("focus.immersive.open")
        waitFor("immersive.root")

        tapImmersive("immersive.finish")
        waitFor("focus.summary")
        XCTAssertTrue(waitForDisappearance(of: element("immersive.root")))
        XCTAssertTrue(element("focus.summary.focus").exists)
        attachScreenshot("immersive-summary-sheet")
        tap("focus.summary.done")
        waitFor("focus.start")
        XCTAssertEqual(phase.lowercased(), "hazır")
        XCTAssertFalse(element("focus.immersive.open").exists)
    }

    /// Küçültülmüş durum yeni oturumda sıfırlanır: yeni oturum yine tam ekran açar.
    func testNewSessionAlwaysOpensImmersiveAfterMinimize() {
        launch(immersivePage: "stopwatch")
        tap("focus.start")
        waitFor("immersive.root")
        minimizeImmersive()
        tap("focus.finish")
        waitFor("focus.summary")
        tap("focus.summary.done")
        tap("focus.start")
        waitFor("immersive.root")
    }

    // MARK: Sayfalar

    func testSwipesThroughAllPagesAndRemembersLastPage() {
        launch(seed: "running", immersivePage: "stopwatch", extraArguments: ["-FokusUITestKeepImmersivePage"])
        waitFor("immersive.root")
        for (index, page) in Self.pages.enumerated() {
            waitFor("immersive.page.\(page)")
            XCTAssertTrue(
                (pageIndicator.value as? String ?? "").hasSuffix("\(index + 1) / \(Self.pages.count)"),
                "Gösterge: \(pageIndicator.value ?? "nil")")
            if page == "summary" {
                XCTAssertEqual(element("immersive.summary.count").value as? String, "1")
                XCTAssertTrue((element("immersive.summary.today").value as? String ?? "").contains("dk"))
            }
            if index < Self.pages.count - 1 { swipePage(.left) }
        }
        // Son sayfada (ses): yatay kaydırma geri döner.
        swipePage(.right)
        waitFor("immersive.page.night")
        swipePage(.left)
        waitFor("immersive.page.sound")
        attachScreenshot("immersive-page-sound")
        app.terminate()

        // Yeniden başlatınca son seçilen sayfa (argüman olmadan) hatırlanır.
        app = XCUIApplication()
        app.launchArguments = ["-FokusUITestMode", "-FokusUITestKeepImmersivePage", "-FokusUITestFocusSeed", "running"]
        app.launch()
        skipOnboardingAndOpenFocus()
        waitFor("immersive.page.sound")
        // Sonraki testlere sızmasın: başa dön.
        for _ in 0..<(Self.pages.count - 1) { swipePage(.right) }
        waitFor("immersive.page.stopwatch")
    }

    func testNightPageShowsOnlyTimeAndRevealsControlsOnTap() {
        launch(seed: "running", immersivePage: "night")
        waitFor("immersive.page.night")
        XCTAssertTrue(element("immersive.clock").exists)
        XCTAssertNotEqual(element("immersive.clock").value as? String, "00:00")
        // Gece sayfasında ek öğe yok: bugünkü toplam/özet satırları görünmez.
        XCTAssertFalse(element("immersive.todayTotal").exists)
        XCTAssertFalse(element("immersive.summary.today").exists)
        // Kontroller dokununca belirir ve gizliyken yok.
        XCTAssertFalse(element("immersive.pause").exists)
        revealImmersiveControls(expecting: "immersive.pause")
        attachScreenshot("immersive-night-controls")
    }

    func testRingPageShowsTodayTotal() {
        launch(seed: "running", immersivePage: "ring")
        waitFor("immersive.page.ring")
        waitFor("immersive.todayTotal")
        XCTAssertTrue((element("immersive.todayTotal").value as? String ?? "").contains("dk"))
        XCTAssertNotEqual(element("immersive.clock").value as? String, "00:00")
    }

    // MARK: Uzun mola

    func testLongBreakAlertIsShownFullScreenOnEveryPage() {
        launch(seed: "longbreak", immersivePage: "stopwatch")
        waitFor("immersive.root")
        for page in ["stopwatch", "clock", "ring", "summary", "night"] {
            if page != "stopwatch" { goToPage(page) }
            waitFor("immersive.longBreak")
            XCTAssertTrue(app.staticTexts["Molan uzadı"].exists)
            // Uzun molada kontroller kaybolmaz: dokunmadan "Devam et" erişilebilir.
            waitFor("immersive.resume")
        }
        attachScreenshot("immersive-long-break")
        tap("immersive.resume")
        waitFor("immersive.pause")
        XCTAssertFalse(element("immersive.longBreak").exists)
    }

    // MARK: Yön

    func testPhoneRotatesToLandscapeOnlyInImmersive() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "Yön kilidi yalnızca iPhone")
        defer { XCUIDevice.shared.orientation = .portrait }
        launch(immersivePage: "stopwatch")
        tap("focus.start")
        waitFor("immersive.root")
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = NSPredicate { _, _ in
            let frame = self.app.windows.firstMatch.frame
            return frame.width > frame.height
        }
        expectation(for: landscape, evaluatedWith: nil)
        waitForExpectations(timeout: 6)
        attachScreenshot("immersive-landscape")

        // Küçültünce uygulama yeniden dikeye döner.
        XCUIDevice.shared.orientation = .portrait
        minimizeImmersive()
        let portrait = NSPredicate { _, _ in
            let frame = self.app.windows.firstMatch.frame
            return frame.height > frame.width
        }
        expectation(for: portrait, evaluatedWith: nil)
        waitForExpectations(timeout: 6)
    }

    // MARK: Görsel kontrol matrisi

    /// 6 sayfa × (dikey, yatay) × (koyu, açık) ekran görüntüsü. Ağır: `-only-testing` ile çağrılır.
    /// iPad'de yalnızca iki sayfa (kronometre, saat) yatayda, iki temada alınır.
    func testScreenshotMatrix() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        let pages = isPad ? ["stopwatch", "clock"] : Self.pages
        let orientations: [(String, UIDeviceOrientation)] =
            isPad ? [("landscape", .landscapeLeft)] : [("portrait", .portrait), ("landscape", .landscapeLeft)]
        for theme in ["dark", "light"] {
            for page in pages {
                launch(seed: "running", theme: theme, immersivePage: page)
                waitFor("immersive.page.\(page)")
                for (name, orientation) in orientations {
                    XCUIDevice.shared.orientation = orientation
                    Thread.sleep(forTimeInterval: 1.5)
                    waitFor("immersive.page.\(page)")
                    attachScreenshot("matrix-\(page)-\(name)-\(theme)")
                    if page == "stopwatch" {
                        // Kontroller görünürken de bir kare.
                        element("immersive.root").tap()
                        Thread.sleep(forTimeInterval: 0.6)
                        attachScreenshot("matrix-\(page)-\(name)-\(theme)-controls")
                    }
                }
                XCUIDevice.shared.orientation = .portrait
                app.terminate()
            }
        }
    }

    // MARK: Yardımcılar

    private enum SwipeDirection { case left, right }

    private func swipePage(_ direction: SwipeDirection) {
        // Orta yükseklikten kaydır: kenar hareketlerine (geri/ana ekran) takılmaz.
        let root = element("immersive.root")
        let start = root.coordinate(withNormalizedOffset: CGVector(dx: direction == .left ? 0.85 : 0.15, dy: 0.4))
        let end = root.coordinate(withNormalizedOffset: CGVector(dx: direction == .left ? 0.15 : 0.85, dy: 0.4))
        let before = pageIndicator.value as? String
        start.press(forDuration: 0.05, thenDragTo: end)
        // Sabit bekleme yerine sayfa göstergesinin değişmesini bekle: yük altındaki simülatörde
        // (iPhone Air) kaydırma animasyonu 0,5 sn'den uzun sürebilir. Sayfa değişmezse (uçta sekme)
        // süre dolar ve çağıran kendi doğrulamasını yapar; doğrulamalar gevşetilmedi.
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", before ?? ""), object: pageIndicator)
        _ = XCTWaiter().wait(for: [changed], timeout: 4)
        Thread.sleep(forTimeInterval: 0.3)
    }

    private func goToPage(_ page: String) {
        for _ in 0..<5 {
            if element("immersive.page.\(page)").exists && (pageIndicator.value as? String ?? "").contains(
                title(of: page)) { return }
            let current = (pageIndicator.value as? String) ?? ""
            let currentIndex = Self.pages.firstIndex { current.contains(title(of: $0)) } ?? 0
            let target = Self.pages.firstIndex(of: page) ?? 0
            swipePage(target > currentIndex ? .left : .right)
        }
    }

    private func title(of page: String) -> String {
        switch page {
        case "stopwatch": "Kronometre"
        case "clock": "Saat"
        case "ring": "Hedef halkası"
        case "night": "Gece"
        case "summary": "Bugünün özeti"
        default: "Ses ve müzik"
        }
    }
}
