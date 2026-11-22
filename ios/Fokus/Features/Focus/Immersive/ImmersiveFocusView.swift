import FokusData
import FokusDesign
import FokusDomain
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "focus.immersive")

/// Odak oturumu açıkken gösterilen StandBy benzeri tam ekran görünüm: yatay kaydırmalı beş sayfa
/// (kronometre, halka, gece, özet, ses), dokununca beliren Mola ver / Devam et / Bitir kontrolleri.
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

    @Query(filter: #Predicate<FocusSession> { $0.deletedAt == nil }, sort: \FocusSession.startedAt, order: .reverse)
    private var sessions: [FocusSession]
    @Query(filter: #Predicate<FocusSegment> { $0.deletedAt == nil })
    private var segments: [FocusSegment]
    @Query(filter: #Predicate<Subject> { $0.deletedAt == nil })
    private var subjects: [Subject]
    @Query(filter: #Predicate<Topic> { $0.deletedAt == nil })
    private var topics: [Topic]

    @AppStorage(ImmersivePage.storageKey) private var pageRaw = ImmersivePage.default.rawValue
    @State private var controls = ImmersiveControlsVisibility()
    /// Yatay kaydırıcının konumu (`scrollPosition`); `pageRaw` ile iki yönlü eşlenir.
    @State private var scrolledPage: ImmersivePage?
    /// Başlangıç kaydırması oturduktan sonra gerçek kaydırma konumu sayfayı belirler.
    @State private var tracksScroll = false
    /// Oturum biterken kapak kapanma animasyonunda 00:00'a düşmesin diye son açık anın görüntüsü.
    @State private var lastActive: ImmersiveSnapshot?
    @State private var errorMessage: String?

    private static let saveError = "İşlem kaydedilemedi. Lütfen tekrar dene."

    private var page: ImmersivePage { ImmersivePage(rawValue: pageRaw) ?? .default }

    private var pageBinding: Binding<ImmersivePage> {
        Binding(get: { page }, set: { pageRaw = $0.rawValue })
    }

    private var activeSession: FocusSession? {
        sessions.filter { $0.endedAt == nil }.max { $0.startedAt < $1.startedAt }
    }

    private var sessionLabel: String? {
        guard let activeSession,
            let subject = subjects.first(where: { $0.id == activeSession.subjectId })
        else { return nil }
        let topic = topics.first { $0.id == activeSession.topicId }
        return [subject.exam.rawValue, subject.name, topic?.name].compactMap { $0 }.joined(separator: " · ")
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

    private func layout(snapshot: ImmersiveSnapshot, now: Date) -> some View {
        let pinned = ImmersiveControlsVisibility.isPinned(
            isVoiceOverRunning: voiceOverEnabled, isLongBreak: snapshot.isLongBreak)
        let showsControls = controls.isShown(pinned: pinned) && snapshot.phase != .idle
        let isNight = page == .night
        let reserve = ImmersiveLayout.indicatorReserve + (pinned ? ImmersiveLayout.pinnedControlsReserve : 0)
        return GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let context = ImmersivePageContext(
                snapshot: snapshot, sessionLabel: sessionLabel, now: now, insets: insets, bottomReserve: reserve)
            ZStack {
                pager(context)
                overlay(snapshot: snapshot, insets: insets, showsControls: showsControls, isNight: isNight)
            }
        }
        .ignoresSafeArea()
        .background(.fkBackground)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("immersive.root")
        .task(id: controls.timerKey(pinned: pinned)) {
            guard controls.isRevealed, !pinned else { return }
            try? await Task.sleep(for: ImmersiveControlsVisibility.autoHideDelay)
            guard !Task.isCancelled else { return }
            controls.hide()
        }
    }

    private func pager(_ context: ImmersivePageContext) -> some View {
        // `TabView(.page)` yerine sayfalı yatay `ScrollView`: UIKit sayfa kaydırıcısı kısa dokunuşları
        // (XCUITest ve hızlı parmak dokunuşları) yutuyordu; ScrollView içeriğinde dokunuş güvenilir.
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(ImmersivePage.allCases) { item in
                        pageView(item, context: context)
                            .containerRelativeFrame(.horizontal)
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
            // `scrollPosition` ilk sunumda saklı sayfayı uygulamaz; açılışta animasyonsuz oraya git.
            .onAppear {
                scrolledPage = page
                proxy.scrollTo(page, anchor: .leading)
            }
            .task {
                try? await Task.sleep(for: .milliseconds(400))
                tracksScroll = true
            }
            // Kaydırma → saklanan sayfa (gösterge, erişilebilirlik, hatırlama). Sayfa, gerçek kaydırma
            // konumundan türetilir (`scrollPosition` bağlaması hızlı kaydırmalarda güncellenmeyebiliyor).
            .onScrollGeometryChange(for: Int.self) { geometry in
                guard geometry.containerSize.width > 0 else { return 0 }
                return Int((geometry.contentOffset.x / geometry.containerSize.width).rounded())
            } action: { _, index in
                // Açılıştaki ilk konum (0) saklı sayfayı ezmesin: başlangıç kaydırması oturana dek yok say.
                guard tracksScroll else { return }
                let pages = ImmersivePage.allCases
                guard pages.indices.contains(index) else { return }
                let target = pages[index]
                if target.rawValue != pageRaw { pageRaw = target.rawValue }
            }
            // Dışarıdan değişim (gösterge ayarı vb.) → kaydırma konumu.
            .onChange(of: pageRaw) { _, new in
                guard let target = ImmersivePage(rawValue: new), scrolledPage != target else { return }
                withAnimation(reduceMotion ? nil : FokusMotion.baseAnimation) { scrolledPage = target }
            }
        }
    }

    @ViewBuilder
    private func pageView(_ item: ImmersivePage, context: ImmersivePageContext) -> some View {
        switch item {
        case .stopwatch: ImmersiveStopwatchPage(context: context)
        case .ring: ImmersiveRingPage(context: context)
        case .night: ImmersiveNightPage(context: context)
        case .summary: ImmersiveSummaryPage(context: context)
        case .sound: ImmersiveSoundPage(context: context)
        }
    }

    private func overlay(
        snapshot: ImmersiveSnapshot, insets: EdgeInsets, showsControls: Bool, isNight: Bool
    ) -> some View {
        let animation = reduceMotion ? nil : FokusMotion.baseAnimation
        return VStack(spacing: 0) {
            HStack {
                Spacer()
                // Gizliyken görünüm ağacında YOK (opaklık 0 değil): erişilebilirlik ağacında ve
                // dokunma testinde de görünmez/dokunulamaz olur.
                if showsControls {
                    ImmersiveMinimizeButton(action: onMinimize)
                        .transition(.opacity)
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
                    page: pageBinding, tone: snapshot.phase == .break ? FokusColor(.success) : FokusColor(.label),
                    isDimmed: isNight)
            }
            .padding(.bottom, max(insets.bottom, FokusSpacing.md))
        }
        .padding(.leading, max(insets.leading, FokusSpacing.xl))
        .padding(.trailing, max(insets.trailing, FokusSpacing.xl))
        .modifier(ImmersiveNightScheme(isNight: isNight))
        .animation(animation, value: showsControls)
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
