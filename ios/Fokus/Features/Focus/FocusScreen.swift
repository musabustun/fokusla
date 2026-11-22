import FokusData
import FokusDesign
import FokusDomain
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "focus")

/// Odak modülü: kronometre (başlat / mola / devam / bitir), istatistikler ve geçmiş.
/// Durum yalnızca depoda yaşar (`FocusRepository`); süreler segment zaman damgalarından hesaplanır,
/// bu yüzden uygulama kapanıp açılınca açık oturum doğru sürelerle devam eder.
struct FocusScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.immersiveCoordinator) private var immersive

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

    @State private var selection = FocusSelection.none
    @State private var errorMessage: String?
    @State private var summary: SummaryItem?

    private struct SummaryItem: Identifiable {
        let id = UUID()
        let stats: FocusCalc.FocusSessionStats
    }

    private static let saveError = "İşlem kaydedilemedi. Lütfen tekrar dene."

    // MARK: Türetilmiş veri (sorgu değişince bir kez; saniyelik tikte yeniden hesaplanmaz)

    private var activeSession: FocusSession? {
        sessions.filter { $0.endedAt == nil }.max { $0.startedAt < $1.startedAt }
    }

    private var phase: FocusTimerPhase {
        guard let activeSession else { return .idle }
        let all = segments.map(\.snapshot)
        switch FocusCalc.focusPhase(session: activeSession.snapshot, segments: all) {
        case .focus: return .focus
        case .break: return .break
        case .ended: return .idle
        }
    }

    private var sessionLabel: String? {
        guard let activeSession,
            let subject = subjects.first(where: { $0.id == activeSession.subjectId })
        else { return nil }
        let topic = topics.first { $0.id == activeSession.topicId }
        return [subject.exam.rawValue, subject.name, topic?.name].compactMap { $0 }.joined(separator: " · ")
    }

    private var field: YksField? { profiles.first?.field }

    var body: some View {
        let sessionSnapshots = sessions.map(\.snapshot)
        let segmentSnapshots = segments.map(\.snapshot)
        let activeId = activeSession?.id
        let activeSegments = segmentSnapshots.filter { $0.sessionId == activeId && activeId != nil }
        let currentPhase = phase

        TimelineView(.periodic(from: .now, by: currentPhase.isRunning ? 1 : 30)) { context in
            let now = context.date
            let overall = FocusCalc.computeSessionStats(segmentSnapshots, now: now)
            let days = FocusCalc.recentDays(now: now)
            let todayTotal = (try? FocusCalc.dailyFocusTotalMs(
                sessions: sessionSnapshots, segments: segmentSnapshots, day: days.last ?? "", now: now)) ?? 0
            let weekly = (try? FocusCalc.dailyFocusTotals(
                sessions: sessionSnapshots, segments: segmentSnapshots, days: days, now: now)) ?? []

            let panel = FocusTimerPanel(
                phase: currentPhase,
                sessionFocusMs: FocusCalc.computeSessionStats(activeSegments, now: now).focusMs,
                breakMs: FocusCalc.openSegmentDurationMs(activeSegments, kind: .break, now: now),
                todayTotalMs: todayTotal,
                sessionLabel: sessionLabel,
                isLongBreak: currentPhase == .break && FocusCalc.isLongBreak(activeSegments, now: now),
                errorMessage: errorMessage,
                onOpenImmersive: immersive.map { coordinator in { coordinator.reopen() } }
            ) {
                FocusSubjectPicker(
                    subjects: FocusSubjects.subjects(subjects, field: field),
                    topics: FocusSubjects.topics(topics, subjectId: selection.subjectId),
                    selection: $selection)
            }
            let stats = VStack(alignment: .leading, spacing: FokusSpacing.xxl) {
                FocusStatsSection(
                    averageFocusMs: overall.averageFocusMs, averageBreakMs: overall.averageBreakMs,
                    weeklyTotals: weekly)
                FocusHistorySection(
                    rows: historyRows(sessions: sessionSnapshots, segments: segmentSnapshots, now: now))
            }
            let isLong = currentPhase == .break && FocusCalc.isLongBreak(activeSegments, now: now)
            let timerActions = FocusTimerActions(start: start, pause: pause, resume: resume, finish: finish)
            content(
                panel: panel,
                inlineButtons: FocusActionButtons(
                    phase: currentPhase, isLongBreak: isLong, isStacked: true, actions: timerActions),
                pinnedButtons: FocusActionButtons(
                    phase: currentPhase, isLongBreak: isLong, isStacked: false, actions: timerActions),
                stats: stats)
        }
        .background(.fkBackground)
        .sheet(item: $summary) { item in
            FocusSummarySheet(stats: item.stats) { summary = nil }
                .presentationDetents([.medium, .large])
                .presentationBackground(.fkBackground)
        }
        .task { FocusUITestSeed.applyIfRequested(context: modelContext) }
        .onChange(of: activeSession?.id) { _, newId in
            // Oturum nereden biterse bitsin (tam ekran dahil) ders seçimi sıfırlanır.
            if newId == nil { selection = .none }
        }
    }

    /// En az bu genişlikte (pt) kronometre ile istatistikler yan yana durur; daha darda (iPad dikey,
    /// bölünmüş ekran) alt alta dizilir.
    private static let sideBySideMinWidth: CGFloat = 760

    /// iPhone: eylem düğmeleri altta sabit (tab bar'ın üstünde, kaydırmadan erişilir). iPad: yeterince
    /// genişse kronometre + istatistik yan yana, değilse alt alta; düğmeler kronometrenin altında.
    @ViewBuilder
    private func content(
        panel: some View, inlineButtons: some View, pinnedButtons: some View, stats: some View
    ) -> some View {
        let isCompact = horizontalSizeClass != .regular
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xxl) {
                ScreenHeader("Odak", eyebrow: "Kronometre")
                if isCompact {
                    panel
                    stats
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: FokusSpacing.xxl) {
                            VStack(spacing: FokusSpacing.xl) {
                                panel
                                inlineButtons
                            }
                            .frame(maxWidth: .infinity)
                            stats.frame(maxWidth: .infinity)
                        }
                        .frame(minWidth: Self.sideBySideMinWidth)
                        VStack(alignment: .leading, spacing: FokusSpacing.xxl) {
                            VStack(spacing: FokusSpacing.xl) {
                                panel
                                inlineButtons
                            }
                            .frame(maxWidth: 520)
                            .frame(maxWidth: .infinity)
                            stats
                        }
                    }
                }
            }
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.vertical, FokusSpacing.lg)
        }
        .accessibilityIdentifier("screen.focus")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isCompact {
                pinnedButtons
                    .padding(.horizontal, FokusSpacing.screenHorizontal)
                    .padding(.vertical, FokusSpacing.md)
                    .background(.fkBackground)
                    .overlay(alignment: .top) { Divider().overlay(.fkSeparator) }
            }
        }
    }

    // MARK: Geçmiş

    private func historyRows(
        sessions: [FocusSessionSnapshot], segments: [FocusSegmentSnapshot], now: Date
    ) -> [FocusHistoryRow] {
        // Yinelenen id'lerde (CloudKit kopyaları) ilki tutulur.
        let byId = Dictionary(self.sessions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return FocusCalc.historyEntries(sessions: sessions, segments: segments, now: now).map { entry in
            let session = byId[entry.id]
            let subject = subjects.first { $0.id == session?.subjectId }
            let topic = topics.first { $0.id == session?.topicId }
            let details = [subject?.exam.rawValue, topic?.name].compactMap { $0 }
            return FocusHistoryRow(
                id: entry.id,
                title: subject?.name ?? "Ders seçilmedi",
                subtitle: ([FocusDateFormat.sessionStart(entry.startedAt)] + details).joined(separator: " · "),
                focusMs: entry.focusMs)
        }
    }

    // MARK: Eylemler

    private func start() {
        perform(announcement: "Odak başladı") { repository in
            try repository.start(subjectId: selection.subjectId, topicId: selection.topicId)
        }
    }

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
            if let stats = try repository.finish(sessionId: id) {
                summary = SummaryItem(stats: stats)
                selection = .none
            }
        }
    }

    /// Yazma işlemini çalıştırır; hata olursa kullanıcıya mesaj gösterir (sessizce yutmaz).
    private func perform(announcement: String, _ action: (FocusRepository) throws -> Void) {
        do {
            try action(FocusRepository(context: modelContext))
            errorMessage = nil
            AccessibilityNotification.Announcement(announcement).post()
        } catch {
            logger.error("Odak işlemi kaydedilemedi: \(error.localizedDescription, privacy: .public)")
            errorMessage = Self.saveError
        }
    }
}

/// Önizleme deposu; kurulamazsa önizleme açılmaz (yalnızca geliştirici hatası).
@MainActor
private let previewContainer: ModelContainer = {
    do {
        return try FokusStore.makeInMemoryContainer()
    } catch {
        preconditionFailure("Önizleme deposu kurulamadı: \(error)")
    }
}()

#Preview("Odak — koyu") {
    FocusScreen()
        .modelContainer(previewContainer)
        .fokusTheme()
        .preferredColorScheme(.dark)
}
