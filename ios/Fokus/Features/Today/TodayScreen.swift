import FokusData
import FokusDesign
import FokusDomain
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "today")

/// Bugün modülü: günün bir bakışta özeti ve tek dokunuşla işe başlama (açılış sekmesi).
/// Web `features/today/TodayScreen`. Yalnızca okur; tek yazma eylemi görev tamamlamadır
/// (Görevler deposundaki `toggleCompletion`). Tüm hesaplar `TodayCalc` ve diğer `Calc`'lardandır.
/// iPhone: tek sütun, Odak en üstte. iPad (geniş): Odak tam genişlikte, altında iki sütun.
struct TodayScreen: View {
    /// İki sütun için gereken en az genişlik (pt).
    private static let wideLayoutMinWidth: CGFloat = 700

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    @Query(filter: #Predicate<FocusSession> { $0.deletedAt == nil }) private var sessions: [FocusSession]
    @Query(filter: #Predicate<FocusSegment> { $0.deletedAt == nil }) private var segments: [FocusSegment]
    @Query(filter: #Predicate<StudyTask> { $0.deletedAt == nil }, sort: \StudyTask.order)
    private var tasks: [StudyTask]
    @Query(filter: #Predicate<TaskCompletion> { $0.deletedAt == nil }) private var completions: [TaskCompletion]
    @Query(filter: #Predicate<Subject> { $0.deletedAt == nil }) private var subjects: [Subject]
    @Query(filter: #Predicate<Topic> { $0.deletedAt == nil }) private var topics: [Topic]
    @Query(filter: #Predicate<TestResult> { $0.deletedAt == nil }) private var results: [TestResult]
    @Query(filter: #Predicate<Book> { $0.deletedAt == nil }) private var books: [Book]
    @Query(filter: #Predicate<BookProgress> { $0.deletedAt == nil }) private var bookProgress: [BookProgress]
    @Query(filter: #Predicate<UserProfile> { $0.deletedAt == nil }, sort: \UserProfile.createdAt)
    private var profiles: [UserProfile]

    @State private var today: ISODate = Identifiers.isoDate(.now)
    @State private var actionError: String?
    @State private var toggleCount = 0

    // MARK: - Türetilmiş veri

    private var profile: UserProfile? { profiles.first }

    private var taskContext: TaskViews.Context {
        TaskViews.Context(
            completions: TodayData.deduplicated(completions).map(\.snapshot), today: today,
            subjectNames: Dictionary(
                subjects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first }))
    }

    private var taskOverview: TodayCalc.TaskOverview {
        TodayCalc.taskOverview(
            tasks: TodayData.deduplicated(tasks).map(\.snapshot),
            completions: taskContext.completions, today: today)
    }

    private var recentTests: TodayCalc.RecentTests {
        TodayCalc.recentTests(results: TodayData.deduplicated(results).map(\.snapshot), today: today)
    }

    private var weakRows: [TodayTestsSection.WeakRow] {
        let topicById = Dictionary(topics.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let subjectNames = Dictionary(
            subjects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return TodayCalc.weakestTopics(results: TodayData.deduplicated(results).map(\.snapshot)).map { weak in
            let topic = topicById[weak.topicId]
            return TodayTestsSection.WeakRow(
                id: weak.topicId, topic: topic?.name ?? "Adsız konu",
                subject: topic?.subjectId.flatMap { subjectNames[$0] }, accuracy: weak.summary.accuracy)
        }
    }

    private var bookSummaries: [BooksCalc.BookSummary] {
        TodayCalc.booksInProgress(
            BooksCalc.summarizeBooks(
                TodayData.deduplicated(books).map(\.snapshot),
                progress: TodayData.deduplicated(bookProgress).map(\.snapshot), now: .now))
    }

    // MARK: - Gövde

    var body: some View {
        GeometryReader { proxy in
            let isWide = horizontalSizeClass == .regular && proxy.size.width >= Self.wideLayoutMinWidth
            ScrollView {
                VStack(alignment: .leading, spacing: FokusSpacing.xxl + FokusSpacing.sm) {
                    TodayHeader(profile: profile)
                    TodayFocusSection(
                        sessions: TodayData.deduplicated(sessions).map(\.snapshot),
                        segments: TodayData.deduplicated(segments).map(\.snapshot),
                        goalMinutes: profile?.dailyFocusGoalMinutes, isWide: isWide)
                    if isWide {
                        HStack(alignment: .top, spacing: FokusSpacing.xxl * 2) {
                            tasksSection.frame(maxWidth: .infinity)
                            VStack(alignment: .leading, spacing: FokusSpacing.xxl) {
                                testsSection
                                booksSection
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        tasksSection
                        testsSection
                        booksSection
                    }
                    // iPhone'da Kitaplar ve Sosyal tab bar'da yok; buradan açılır (web "Diğer").
                    if horizontalSizeClass == .compact { shortcuts }
                }
                .padding(.horizontal, FokusSpacing.screenHorizontal)
                .padding(.vertical, FokusSpacing.lg)
            }
        }
        .background(.fkBackground)
        .sensoryFeedback(.selection, trigger: toggleCount)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshToday() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshToday() } }
        .task { TodayUITestSeed.applyIfRequested(context: modelContext) }
        .accessibilityIdentifier("screen.today")
    }

    private func refreshToday() { today = Identifiers.isoDate(.now) }

    private var tasksSection: some View {
        TodayTasksSection(
            overview: taskOverview, context: taskContext, errorMessage: actionError, onToggle: toggle)
    }

    private var testsSection: some View {
        TodayTestsSection(recent: recentTests, weakRows: weakRows)
    }

    private var booksSection: some View {
        TodayBooksSection(books: bookSummaries)
    }

    private var shortcuts: some View {
        LineSection("Diğer") {
            shortcut(.books)
            shortcut(.social)
        }
    }

    private func shortcut(_ section: AppSection) -> some View {
        NavigationLink(value: section) {
            LineRow(section.title) {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.fkTertiaryLabel)
            }
        }
        .buttonStyle(.fokusRow)
        .accessibilityIdentifier("today.shortcut.\(section.rawValue)")
    }

    // MARK: - Eylemler

    private func toggle(_ id: UUID) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        do {
            try TasksRepository(context: modelContext).toggleCompletion(task, on: today)
            actionError = nil
            toggleCount += 1
        } catch {
            logger.error("Görev işaretlenemedi: \(error.localizedDescription, privacy: .public)")
            actionError = "Görev güncellenemedi. Tekrar dene."
        }
    }
}

/// Başlık: tarih, selam ve kullanıcının YKS alanı (web `TodayHeader`).
private struct TodayHeader: View {
    let profile: UserProfile?

    var body: some View {
        // Selam dakikada bir güncellenir.
        TimelineView(.everyMinute) { context in
            let now = context.date
            ScreenHeader("Bugün", eyebrow: Self.dateText(now), subtitle: subtitle(now)) {
                if let profile {
                    Text(profile.field.shortLabel)
                        .fokusTextStyle(.footnote)
                        .foregroundStyle(.fkLabel)
                        .padding(.horizontal, FokusSpacing.md)
                        .padding(.vertical, FokusSpacing.xs)
                        .overlay(Capsule().strokeBorder(.fkSeparatorStrong, lineWidth: 1))
                        .accessibilityLabel("\(profile.field.label) alanı")
                        .accessibilityIdentifier("today.field")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.header")
    }

    private func subtitle(_ now: Date) -> String {
        let greeting = TodayCalc.greeting(now: now).text
        guard let name = profile?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
        else { return greeting }
        return "\(greeting), \(name)"
    }

    private static func dateText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle().weekday(.wide).day().month(.wide).locale(Locale(identifier: "tr_TR")))
    }
}

#Preview {
    NavigationStack { TodayScreen() }
        .fokusTheme()
        .environment(AppNavigation())
        .modelContainer(PreviewSupport.onboardedContainer())
}
