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
        TabView(selection: pageBinding) {
            ForEach(ImmersivePage.allCases) { item in
                pageView(item, context: context)
                    .tag(item)
                    .accessibilityHidden(item != page)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .contentShape(Rectangle())
        // Her dokunuş kontrolleri gösterir/süreyi yeniler; çocuk düğmelerin dokunuşunu engellemez.
        .simultaneousGesture(TapGesture().onEnded { controls.reveal() })
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
                ImmersiveMinimizeButton(action: onMinimize)
                    .opacity(showsControls ? 1 : 0)
                    .allowsHitTesting(showsControls)
                    .accessibilityHidden(!showsControls)
            }
            .padding(.top, max(insets.top, FokusSpacing.lg))
            Spacer(minLength: 0)
            VStack(spacing: FokusSpacing.md) {
                if snapshot.isLongBreak { ImmersiveLongBreakBadge(isDimmed: isNight) }
                ImmersiveControlsBar(
                    phase: snapshot.phase, isLongBreak: snapshot.isLongBreak,
                    actions: FocusTimerActions(start: {}, pause: pause, resume: resume, finish: finish)
                )
                .opacity(showsControls ? 1 : 0)
                .allowsHitTesting(showsControls)
                .accessibilityHidden(!showsControls)
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
