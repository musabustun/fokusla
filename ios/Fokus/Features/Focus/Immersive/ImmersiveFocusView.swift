import FokusAudio
import FokusData
import FokusDesign
import FokusDomain
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "focus.immersive")

/// Yatay sayfa kaydırıcısının bir andaki ölçümü: kapsayıcı genişliği ve ofsetten türetilen sayfa sırası.
private struct ScrollSample: Equatable {
    var width: CGFloat
    var index: Int
}

/// Odak oturumu açıkken gösterilen StandBy benzeri tam ekran görünüm: yatay kaydırmalı kartlar
/// (`StandByPreferences` ile seçilen/sıralanan; kronometre, saat, halka, ders, özet, müzik, gece, ses),
/// dokununca beliren Mola ver / Devam et / Bitir kontrolleri. Uzun basınca (ya da "Özelleştir" düğmesiyle)
/// kilit ekranı benzeri düzenleme moduna geçer.
/// Kendi `@Query`'leriyle kurulur (yaşayan veri saniyelik `TimelineView` ile yenilenir) ve yazma
/// işlemlerini `FocusRepository` ile kendisi yapar; sunumu `ImmersiveCoverHost` yönetir.
struct ImmersiveFocusView: View {
    /// "Küçült": kapağı kapatır, normal Odak ekranına dönülür.
    let onMinimize: () -> Void
    /// Oturum bitti; özet sheet'i kapak tamamen kapanınca ana tarafça gösterilir.
    let onFinished: (FocusCalc.FocusSessionStats) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    /// Uygulamanın paleti (tam ekran paleti ezmeden ÖNCE): düzenleyici "Uygulama" seçeneği için.
    @Environment(\.fokusPalette) private var appPalette
    @Environment(\.musicRegistry) private var musicRegistry

    @Query(filter: #Predicate<FocusSession> { $0.deletedAt == nil }, sort: \FocusSession.startedAt, order: .reverse)
    private var sessions: [FocusSession]
    @Query(filter: #Predicate<FocusSegment> { $0.deletedAt == nil })
    private var segments: [FocusSegment]
    @Query(filter: #Predicate<Subject> { $0.deletedAt == nil })
    private var subjects: [Subject]
    @Query(filter: #Predicate<Topic> { $0.deletedAt == nil })
    private var topics: [Topic]

    @Query(filter: #Predicate<UserProfile> { $0.deletedAt == nil }, sort: \UserProfile.createdAt)
    private var profiles: [UserProfile]

    @AppStorage(ImmersiveStorage.pageKey) private var pageRaw = ImmersiveStorage.defaultPage.rawValue
    @AppStorage(StandByPreferences.storageKey, store: ImmersiveStorage.preferencesDefaults)
    private var preferencesData = Data()
    @State private var isEditing = false
    @State private var controls = ImmersiveControlsVisibility()
    /// Yatay kaydırıcının konumu (`scrollPosition`); `pageRaw` ile iki yönlü eşlenir.
    @State private var scrolledPage: StandByPage?
    /// Başlangıç kaydırması oturduktan sonra gerçek kaydırma konumu sayfayı belirler.
    @State private var tracksScroll = false
    /// Boyut değişiminden sonra kaydırıcıyı mevcut sayfaya oturtan görev (yenisi eskisini iptal eder).
    @State private var reanchorTask: Task<Void, Never>?
    /// Oturum biterken kapak kapanma animasyonunda 00:00'a düşmesin diye son açık anın görüntüsü.
    @State private var lastActive: ImmersiveSnapshot?
    @State private var errorMessage: String?
    /// Köşe çipi yerinde kontrol kartına genişlemiş mi?
    @State private var isChipExpanded = false
    /// Kart açıkken her etkileşimde artar: otomatik daralma süresini yeniler.
    @State private var chipRevision = 0

    /// Boyut değişiminden sonra düzenin (sayfa genişlikleri) oturması için bekleme.
    private static let layoutSettleDelay: Duration = .milliseconds(350)
    private static let saveError = "İşlem kaydedilemedi. Lütfen tekrar dene."
    /// Açık müzik kartı bu süre etkileşim olmazsa çipe daralır.
    private static let chipAutoCollapseDelay: Duration = .seconds(6)

    private var preferences: StandByPreferences { StandByPreferences.decoded(from: preferencesData) }

    private var preferencesBinding: Binding<StandByPreferences> {
        Binding(get: { preferences }, set: { preferencesData = $0.encoded() })
    }

    private var music: ImmersiveMusic { ImmersiveMusic(registry: musicRegistry) }

    /// Görünür sayfalar (müzik yalnızca bağlı ve çalıyorken).
    private var pages: [StandByPage] { preferences.visiblePages(isMusicConnected: music.isAvailable) }

    /// Geçerli sayfa; saklanan sayfa görünür listede değilse ilk görünür sayfa.
    private var page: StandByPage {
        let list = pages
        if let stored = StandByPage(rawValue: pageRaw), list.contains(stored) { return stored }
        return list[0]
    }

    private var pageBinding: Binding<StandByPage> {
        Binding(get: { page }, set: { pageRaw = $0.rawValue })
    }

    private var activeSession: FocusSession? {
        sessions.filter { $0.endedAt == nil }.max { $0.startedAt < $1.startedAt }
    }

    private var subjectInfo: ImmersiveSubjectInfo? {
        guard let activeSession,
            let subject = subjects.first(where: { $0.id == activeSession.subjectId })
        else { return nil }
        let topic = topics.first { $0.id == activeSession.topicId }
        return ImmersiveSubjectInfo(exam: subject.exam.rawValue, name: subject.name, topic: topic?.name)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let live = ImmersiveSnapshot.make(
                sessions: sessions.map(\.snapshot), segments: segments.map(\.snapshot), now: timeline.date)
            let snapshot = live.phase == .idle ? (lastActive ?? live) : live
            layout(snapshot: snapshot, now: timeline.date)
                .onChange(of: live, initial: true) { _, new in
                    if new.phase != .idle { lastActive = new }
                }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            ImmersiveScreenAwake.activate()
            ImmersiveOrientation.setImmersiveActive(true)
        }
        .onDisappear {
            ImmersiveScreenAwake.deactivate()
            ImmersiveOrientation.setImmersiveActive(false)
        }
    }

    // MARK: Yerleşim

    private func digitColor(for phase: FocusTimerPhase) -> FokusColor {
        if phase == .break { return FokusColor(.success) }
        return preferences.tintedDigits ? FokusColor(.accentInk) : FokusColor(.label)
    }

    private func layout(snapshot: ImmersiveSnapshot, now: Date) -> some View {
        let prefs = preferences
        let pinned = ImmersiveControlsVisibility.isPinned(
            isVoiceOverRunning: voiceOverEnabled, isLongBreak: snapshot.isLongBreak)
        let showsControls = controls.isShown(pinned: pinned) && snapshot.phase != .idle && !isEditing
        let isNightPage = page == .night
        let isNightTint = prefs.nightMode.isActive(at: now)
        let reserve = ImmersiveLayout.indicatorReserve + (pinned ? ImmersiveLayout.pinnedControlsReserve : 0)
        // Okuyucu güvenli alana UYAR (yoksa `safeAreaInsets` hep 0 olur ve içerik Dynamic Island'ın altına
        // kayar); yalnızca içteki ZStack kenardan kenara uzanır.
        return GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let fullSize = CGSize(
                width: proxy.size.width + insets.leading + insets.trailing,
                height: proxy.size.height + insets.top + insets.bottom)
            let context = ImmersivePageContext(
                snapshot: snapshot, subject: subjectInfo, now: now, insets: insets, bottomReserve: reserve,
                clockStyle: prefs.clockStyle, digitColor: digitColor(for: snapshot.phase), isNight: isNightTint,
                dailyGoalMinutes: profiles.first?.dailyFocusGoalMinutes, music: music, preferences: prefs)
            ZStack {
                StandByBackdropView(isNightPage ? .black : prefs.backdrop).ignoresSafeArea()
                if isEditing {
                    editor(context: context, size: fullSize)
                        .transition(.opacity)
                } else {
                    pager(context)
                    overlay(
                        snapshot: snapshot, insets: insets, showsControls: showsControls, isNight: isNightPage,
                        showsChip: showsNowPlayingChip(prefs))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .standByNightTint(isNightTint)
            .ignoresSafeArea()
        }
        .environment(\.fokusPalette, prefs.palette(appPalette: appPalette))
        .background(.fkBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("immersive.root")
        .accessibilityAction(named: "Özelleştir") { enterEditing() }
        .sensoryFeedback(.impact, trigger: isEditing) { _, new in new }
        .animation(reduceMotion ? nil : FokusMotion.baseAnimation, value: isEditing)
        // Düzenleme sırasında otomatik gizleme çalışmaz; kontroller zaten gizlidir.
        .task(id: [controls.revision, pinned ? 1 : 0, isEditing ? 1 : 0]) {
            guard controls.isRevealed, !pinned, !isEditing else { return }
            try? await Task.sleep(for: ImmersiveControlsVisibility.autoHideDelay)
            guard !Task.isCancelled else { return }
            controls.hide()
        }
    }

    /// Köşe çipi yalnızca müzik widget'ı OLMAYAN sayfalarda (widget varsa kontroller zaten sayfada).
    private func showsNowPlayingChip(_ prefs: StandByPreferences) -> Bool {
        !isEditing && prefs.showsChip(on: page, isMusicAvailable: music.isAvailable)
    }

    // MARK: Düzenleme modu

    private func enterEditing() {
        controls.hide()
        // Kaydırıcı sökülürken ofset 0'a düşer; izleme açık kalırsa bu "ilk sayfa" gibi okunup saklı sayfayı
        // ezerdi. Dönüşte `pager.onAppear` izlemeyi yeniden açar.
        tracksScroll = false
        reanchorTask?.cancel()
        isEditing = true
    }

    private func exitEditing() { isEditing = false }

    /// Mevcut kart küçültülmüş canlı önizleme olarak üstte, düzenleyici tepsi altta (yatayda yanda).
    private func editor(context: ImmersivePageContext, size: CGSize) -> some View {
        let isWide = size.width > size.height * 1.15
        let panel = StandByEditorPanel(
            preferences: preferencesBinding, appPalette: appPalette, isMusicAvailable: music.isAvailable,
            onDone: exitEditing, onReset: { preferencesData = StandByPreferences.default.encoded() })
        let preview = editingPreview(context: context.forPreview(), fullSize: size)
        return Group {
            if isWide {
                HStack(spacing: FokusSpacing.lg) {
                    preview
                    panel.frame(width: min(size.width * 0.45, 420))
                }
            } else {
                VStack(spacing: FokusSpacing.md) {
                    preview
                    panel
                }
            }
        }
        .padding(.top, max(context.insets.top, FokusSpacing.lg))
        .padding(.bottom, max(context.insets.bottom, FokusSpacing.md))
        .padding(.leading, max(context.insets.leading, FokusSpacing.lg))
        .padding(.trailing, max(context.insets.trailing, FokusSpacing.lg))
    }

    /// Kilit ekranı düzenleyicisi gibi: sayfa TAM ekran boyutunda dizilir, sonra ayrılan alana sığacak
    /// kadar küçültülür (kırpılmaz). Çerçeve ve köşe yarıçapı ölçekten bağımsız görünür.
    private func editingPreview(context: ImmersivePageContext, fullSize: CGSize) -> some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / max(fullSize.width, 1), proxy.size.height / max(fullSize.height, 1), 1)
            let shape = RoundedRectangle(cornerRadius: FokusRadius.xl / max(scale, 0.1), style: .continuous)
            pageView(page, context: context)
                .frame(width: fullSize.width, height: fullSize.height)
                .background(page == .night ? Color.black : Color.clear)
                .clipShape(shape)
                .overlay(shape.strokeBorder(.fkSeparatorStrong, lineWidth: 1 / max(scale, 0.1)))
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .allowsHitTesting(false)
        }
    }

    // MARK: Sayfa kaydırıcı

    /// Boyut/sayfa listesi değişince kaydırıcıyı mevcut sayfaya oturtur (yenisi eskisini iptal eder).
    private func reanchor(_ proxy: ScrollViewProxy) {
        tracksScroll = false
        reanchorTask?.cancel()
        reanchorTask = Task { @MainActor in
            proxy.scrollTo(page, anchor: .leading)
            try? await Task.sleep(for: Self.layoutSettleDelay)
            guard !Task.isCancelled else { return }
            proxy.scrollTo(page, anchor: .leading)
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            tracksScroll = true
        }
    }

    private func pager(_ context: ImmersivePageContext) -> some View {
        // `TabView(.page)` yerine sayfalı yatay `ScrollView`: UIKit sayfa kaydırıcısı kısa dokunuşları
        // (XCUITest ve hızlı parmak dokunuşları) yutuyordu; ScrollView içeriğinde dokunuş güvenilir.
        let visible = pages
        return ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(visible) { item in
                        pageView(item, context: context)
                            .containerRelativeFrame(.horizontal)
                            .clipped()
                            .contentShape(Rectangle())
                            // Her dokunuş kontrolleri gösterir/süreyi yeniler; çocuk düğmeler/kaydırıcılar
                            // kendi dokunuşunu korur.
                            .onTapGesture { controls.reveal() }
                            .id(item)
                            .accessibilityHidden(item != page)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrolledPage)
            .scrollIndicators(.hidden)
            .ignoresSafeArea()
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5).onEnded { _ in enterEditing() })
            // `scrollPosition` ilk sunumda saklı sayfayı uygulamaz; açılışta animasyonsuz oraya git.
            // Düzenlemeden dönüşte kaydırıcı yeniden kurulur: izleme önce kapanır.
            // Düzenlemeden dönüşte de aynı güvenilir yol: izleme kapanır, kaydırıcı sayfaya oturtulur (iki kez,
            // düzen sakinleşince), sonra izleme açılır. Aksi halde ilk (0) ofset saklı sayfayı ezip kronometreye
            // atlıyordu.
            .onAppear {
                tracksScroll = false
                if pageRaw != page.rawValue { pageRaw = page.rawValue }
                scrolledPage = page
                proxy.scrollTo(page, anchor: .leading)
                reanchor(proxy)
            }
            // Kaydırma → saklanan sayfa (gösterge, erişilebilirlik, hatırlama). Sayfa, gerçek kaydırma
            // konumundan türetilir (`scrollPosition` bağlaması hızlı kaydırmalarda güncellenmeyebiliyor).
            .onScrollGeometryChange(for: ScrollSample.self) { geometry in
                ScrollSample(
                    width: geometry.containerSize.width,
                    index: geometry.containerSize.width > 0
                        ? Int((geometry.contentOffset.x / geometry.containerSize.width).rounded()) : 0)
            } action: { old, new in
                // Genişlik değişti (açılışta düzen oturması, iPhone dönüşü, iPad yeniden boyutlama): ofset
                // eski genişlikteki piksel değerinde kalır ve yanlış sayfa gibi okunurdu. Sayfa DEĞİŞMEZ:
                // izleme durur, kaydırıcı yeni genişlikte mevcut sayfaya oturtulur, düzen sakinleşince
                // izleme yeniden başlar.
                if new.width != old.width {
                    reanchor(proxy)
                    return
                }
                // Açılıştaki ilk konum (0) saklı sayfayı ezmesin: başlangıç kaydırması oturana dek yok say.
                guard tracksScroll else { return }
                let list = pages
                guard list.indices.contains(new.index) else { return }
                let target = list[new.index]
                if target.rawValue != pageRaw {
                    scrolledPage = target
                    pageRaw = target.rawValue
                }
            }
            // Dışarıdan değişim (gösterge ayarı, köşe çipi vb.) → kaydırma konumu.
            .onChange(of: pageRaw) { _, new in
                guard let target = StandByPage(rawValue: new), pages.contains(target), scrolledPage != target
                else { return }
                // Programatik geçiş (köşe çipi, gösterge): boyut değişimindeki güvenilir yeniden oturtma
                // yolu kullanılır (izleme kapanır, `scrollTo`, düzen oturunca izleme açılır). Animasyonlu
                // `scrollTo`/`scrollPosition` yazımı ara sayfaları `pageRaw`'a geri yazıp sayfayı eski
                // yerine döndürüyordu.
                scrolledPage = target
                reanchor(proxy)
            }
            // Görünür sayfa listesi değişti (müzik bağlandı/koptu): geçerli sayfayı koru, yoksa ilkine düş.
            .onChange(of: visible) { _, _ in
                if pageRaw != page.rawValue { pageRaw = page.rawValue }
                scrolledPage = page
                reanchor(proxy)
            }
        }
    }

    /// Sayfa; müzik widget'ı seçiliyse iki bölgeli düzenin içinde (içerik + müzik kontrolleri).
    @ViewBuilder
    private func pageView(_ item: StandByPage, context: ImmersivePageContext) -> some View {
        if context.showsMusicWidget(on: item) {
            ImmersiveMusicSplit(context: context) { content(item, context: $0) }
        } else {
            content(item, context: context.reservingChipRow(on: item))
        }
    }

    @ViewBuilder
    private func content(_ item: StandByPage, context: ImmersivePageContext) -> some View {
        switch item {
        case .stopwatch: ImmersiveStopwatchPage(context: context)
        case .clock: ImmersiveClockPage(context: context)
        case .ring: ImmersiveRingPage(context: context)
        case .subject: ImmersiveSubjectPage(context: context)
        case .summary: ImmersiveSummaryPage(context: context)
        case .music: ImmersiveMusicPage(context: context)
        case .night: ImmersiveNightPage(context: context)
        case .sound: ImmersiveSoundPage(context: context)
        }
    }

    private func overlay(
        snapshot: ImmersiveSnapshot, insets: EdgeInsets, showsControls: Bool, isNight: Bool, showsChip: Bool
    ) -> some View {
        let animation = reduceMotion ? nil : FokusMotion.baseAnimation
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: FokusSpacing.sm) {
                if showsChip, let info = music.info {
                    nowPlayingChip(info: info)
                }
                Spacer(minLength: 0)
                // Gizliyken görünüm ağacında YOK (opaklık 0 değil): erişilebilirlik ağacında ve
                // dokunma testinde de görünmez/dokunulamaz olur. Müzik kartı açıkken üst düğmeler gizlenir.
                if showsControls && !isChipExpanded {
                    ImmersiveCustomizeButton(action: enterEditing).transition(.opacity)
                    ImmersiveMinimizeButton(action: onMinimize).transition(.opacity)
                }
            }
            .padding(.top, max(insets.top, FokusSpacing.lg))
            Spacer(minLength: 0)
            VStack(spacing: FokusSpacing.md) {
                if snapshot.isLongBreak { ImmersiveLongBreakBadge(isDimmed: isNight) }
                if showsControls {
                    ImmersiveControlsBar(
                        phase: snapshot.phase, isLongBreak: snapshot.isLongBreak,
                        // Her eylem kontrolleri yeniden açık tutar: kullanıcı sonucu (ör. "Devam et") görür.
                        actions: FocusTimerActions(
                            start: {},
                            pause: { controls.reveal(); pause() },
                            resume: { controls.reveal(); resume() },
                            finish: finish)
                    )
                    .transition(.opacity)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .fokusTextStyle(.subheadline)
                        .foregroundStyle(.fkDanger)
                        .accessibilityIdentifier("immersive.error")
                }
                ImmersivePageIndicator(
                    pages: pages, page: pageBinding,
                    tone: snapshot.phase == .break ? FokusColor(.success) : FokusColor(.label),
                    isDimmed: isNight)
            }
            .padding(.bottom, max(insets.bottom, FokusSpacing.md))
        }
        .padding(.leading, max(insets.leading, FokusSpacing.xl))
        .padding(.trailing, max(insets.trailing, FokusSpacing.xl))
        .modifier(ImmersiveNightScheme(isNight: isNight))
        .animation(animation, value: showsControls)
        .background { chipDismissLayer }
        // Sayfa/düzenleme/müzik durumu değişince kart çipe döner; açıkken etkileşim yoksa kendiliğinden daralır.
        .onChange(of: page) { _, _ in collapseChip() }
        .onChange(of: isEditing) { _, _ in collapseChip() }
        .onChange(of: showsChip) { _, shown in if !shown { collapseChip() } }
        .task(id: [chipRevision, isChipExpanded ? 1 : 0]) {
            guard isChipExpanded else { return }
            try? await Task.sleep(for: Self.chipAutoCollapseDelay)
            guard !Task.isCancelled else { return }
            collapseChip()
        }
    }

    // MARK: Müzik çipi (yerinde genişler)

    /// Köşe çipi: dokununca AYRI EKRANA GİTMEDEN yerinde kontrol kartına genişler.
    private func nowPlayingChip(info: NowPlayingInfo) -> some View {
        let expansion = Binding(
            get: { isChipExpanded },
            set: { newValue in
                isChipExpanded = newValue
                chipRevision += 1
                if newValue { controls.hide() }
            })
        let music = music
        return NowPlayingExpandableChip(
            info: info, errorMessage: music.errorMessage, isExpanded: expansion,
            onPrevious: { chipRevision += 1; music.previous() },
            onPlayPause: { chipRevision += 1; music.playPause() },
            onNext: { chipRevision += 1; music.next() }
        )
        .zIndex(1)
    }

    /// Kart açıkken kartın dışına dokunmak kartı kapatır (sayfa kaydırması/uzun basma etkilenmez: katman yalnızca
    /// kart açıkken vardır ve dokunuşu yutar).
    @ViewBuilder private var chipDismissLayer: some View {
        if isChipExpanded {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { collapseChip() }
                .accessibilityHidden(true)
        }
    }

    private func collapseChip() {
        guard isChipExpanded else { return }
        isChipExpanded = false
    }

    // MARK: Eylemler

    private func pause() {
        guard let id = activeSession?.id else { return }
        perform(announcement: "Mola başladı") { try $0.pause(sessionId: id) }
    }

    private func resume() {
        guard let id = activeSession?.id else { return }
        perform(announcement: "Odağa devam edildi") { try $0.resume(sessionId: id) }
    }

    private func finish() {
        guard let id = activeSession?.id else { return }
        perform(announcement: "Oturum bitti") { repository in
            if let stats = try repository.finish(sessionId: id) { onFinished(stats) }
        }
    }

    /// Yazma işlemini çalıştırır; hata olursa kullanıcıya mesaj gösterir (sessizce yutmaz).
    private func perform(announcement: String, _ action: (FocusRepository) throws -> Void) {
        do {
            try action(FocusRepository(context: modelContext))
            errorMessage = nil
            AccessibilityNotification.Announcement(announcement).post()
        } catch {
            logger.error("Tam ekran odak işlemi kaydedilemedi: \(error.localizedDescription, privacy: .public)")
            errorMessage = Self.saveError
        }
    }
}
