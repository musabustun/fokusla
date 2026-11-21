import FokusData
import FokusDesign
import FokusDomain
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "tasks")

/// Görevler modülü: rutinler ve son tarihli ödevler. Web `features/tasks/TasksScreen`.
/// iPhone: liste + ayrıntı sayfası (sheet); iPad (geniş): liste + yan ayrıntı paneli.
struct TasksScreen: View {
    private enum ViewMode: Hashable { case today, all }

    /// Liste + yan panel için gereken en az genişlik (pt).
    private static let wideLayoutMinWidth: CGFloat = 640
    private static let detailPanelWidth: CGFloat = 360

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    @Query(filter: #Predicate<StudyTask> { $0.deletedAt == nil }, sort: \StudyTask.order)
    private var tasks: [StudyTask]
    @Query(filter: #Predicate<TaskCompletion> { $0.deletedAt == nil }) private var completions: [TaskCompletion]
    @Query(filter: #Predicate<Subject> { $0.deletedAt == nil }) private var subjects: [Subject]
    @Query(filter: #Predicate<UserProfile> { $0.deletedAt == nil }, sort: \UserProfile.createdAt)
    private var profiles: [UserProfile]

    /// Cihaza özel tercih (senkronize edilmez); web: `fokus.tasks.hideCompleted`.
    @AppStorage("fokus.tasks.hideCompleted") private var hideCompleted = false
    @State private var mode: ViewMode = .today
    @State private var today: ISODate = Identifiers.isoDate(.now)
    @State private var selectedId: UUID?
    @State private var isAdding = false
    @State private var actionError: String?
    @State private var toggleCount = 0

    // MARK: - Türetilmiş veri

    private var liveTasks: [StudyTask] { Self.deduplicated(tasks) }
    private var liveCompletions: [TaskCompletion] { Self.deduplicated(completions) }
    private var snapshots: [TaskSnapshot] { liveTasks.map(\.snapshot) }

    private var rowContext: TaskViews.Context {
        TaskViews.Context(
            completions: liveCompletions.map(\.snapshot), today: today,
            subjectNames: Dictionary(
                subjects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first }))
    }

    private var selectedTask: StudyTask? { liveTasks.first { $0.id == selectedId } }

    private func subjectGroups(keeping keepId: UUID?) -> [SubjectGroup] {
        SubjectOptions.groups(subjects: subjects, field: profiles.first?.field, keepId: keepId)
    }

    /// Aynı `id`'li kopyalarda en eski `createdAt` kazanır (CloudKit); sıra korunur.
    private static func deduplicated<T: SyncedEntity>(_ entities: [T]) -> [T] {
        var winners: [UUID: T] = [:]
        for entity in entities {
            if let current = winners[entity.id], current.createdAt <= entity.createdAt { continue }
            winners[entity.id] = entity
        }
        return entities.filter { winners[$0.id] === $0 }
    }

    // MARK: - Gövde

    var body: some View {
        GeometryReader { proxy in
            let isWide = horizontalSizeClass == .regular && proxy.size.width >= Self.wideLayoutMinWidth
            Group {
                if isWide {
                    HStack(spacing: 0) {
                        ScrollView { listContent(isWide: true) }
                        Divider().overlay(.fkSeparator)
                        ScrollView { detailPanel }
                            .frame(width: Self.detailPanelWidth)
                    }
                } else {
                    ScrollView { listContent(isWide: false) }
                }
            }
            .sheet(isPresented: detailSheetBinding(isWide: isWide)) { detailSheet }
        }
        .background(.fkBackground)
        .sheet(isPresented: $isAdding) {
            TaskFormView(mode: .create(today: today), subjectGroups: subjectGroups(keeping: nil))
        }
        .sensoryFeedback(.selection, trigger: toggleCount)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshToday() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshToday() } }
        .accessibilityIdentifier("screen.tasks")
    }

    private func refreshToday() {
        today = Identifiers.isoDate(.now)
    }

    // MARK: - Liste

    private func listContent(isWide: Bool) -> some View {
        let result = mode == .today
            ? TaskViews.today(snapshots, context: rowContext, hideCompleted: hideCompleted)
            : TaskViews.all(snapshots, context: rowContext, hideCompleted: hideCompleted)
        let summary = TaskViews.summary(snapshots, context: rowContext)
        return VStack(alignment: .leading, spacing: FokusSpacing.xl) {
            ScreenHeader("Görevler", eyebrow: TaskFormatting.dayTitle(today)) {
                Button { isAdding = true } label: { Label("Ekle", systemImage: "plus") }
                    .buttonStyle(.fokusPrimary)
                    .fixedSize()
                    .accessibilityIdentifier("tasks.add")
            }
            summaryView(summary)
            controls
            if let actionError {
                Text(actionError).fokusTextStyle(.subheadline).foregroundStyle(.fkDanger)
                    .accessibilityIdentifier("tasks.error")
            }
            if result.sections.isEmpty {
                emptyState(hasTasks: result.hasTasks)
            } else {
                ForEach(result.sections) { section in
                    LineSection(section.title) {
                        ForEach(section.rows) { row in
                            TaskRowView(
                                model: row, isSelected: isWide && row.id == selectedId,
                                onToggle: { toggle(row.id) }, onSelect: { selectedId = row.id })
                        }
                    }
                }
            }
        }
        .padding(.horizontal, FokusSpacing.screenHorizontal)
        .padding(.vertical, FokusSpacing.lg)
    }

    private func summaryView(_ summary: TaskViews.Summary) -> some View {
        HStack(alignment: .center) {
            Metric(
                label: "Bugün tamamlanan",
                value: "\(TaskFormatting.number(summary.done))/\(TaskFormatting.number(summary.total))",
                size: .xl, tone: summary.isComplete ? .success : .default)
            Spacer(minLength: FokusSpacing.md)
            ProgressRing(progress: summary.progress, lineWidth: 6, tone: summary.isComplete ? .success : .accent)
                .frame(width: 64, height: 64)
                .accessibilityLabel("Bugün tamamlanan görevler")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tasks.summary")
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.sm) {
            Picker("Görünüm", selection: $mode) {
                Text("Bugün").tag(ViewMode.today)
                Text("Tümü").tag(ViewMode.all)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("tasks.mode")
            HStack {
                Spacer()
                Button { hideCompleted.toggle() } label: {
                    Label(
                        hideCompleted ? "Tamamlananları göster" : "Tamamlananları gizle",
                        systemImage: hideCompleted ? "eye" : "eye.slash")
                }
                .buttonStyle(.fokusPlain)
                .accessibilityIdentifier("tasks.hideCompleted")
            }
        }
    }

    @ViewBuilder private func emptyState(hasTasks: Bool) -> some View {
        if hasTasks {
            EmptyStateView(
                mode == .today ? "Bugünkü görevlerin tamam" : "Açık görev kalmadı",
                systemImage: "checkmark.circle",
                message: "Tamamlananları görmek için “Tamamlananları göster”e dokun.")
        } else {
            EmptyStateView(
                mode == .today ? "Bugün için görev yok" : "Henüz görev yok",
                systemImage: "checklist",
                message: "Her gün tekrarlanan rutinlerini ve son tarihli ödevlerini ekle; tamamladıkça işaretle."
            ) {
                Button("Yeni görev oluştur") { isAdding = true }
                    .buttonStyle(.fokusSecondary)
                    .fixedSize()
                    .accessibilityIdentifier("tasks.empty.add")
            }
        }
    }

    // MARK: - Ayrıntı

    @ViewBuilder private var detailPanel: some View {
        Group {
            if let task = selectedTask {
                TaskDetailView(
                    task: task, context: rowContext,
                    subjectGroups: subjectGroups(keeping: task.subjectId), showsTitle: true,
                    onDeleted: { selectedId = nil })
                    .id(task.id)
            } else {
                VStack(spacing: FokusSpacing.md) {
                    Image(systemName: "hand.tap").font(.title).foregroundStyle(.fkSecondaryLabel)
                        .accessibilityHidden(true)
                    Text("Ayrıntıları görmek için bir görev seç")
                        .fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, FokusSpacing.xxl)
            }
        }
        .padding(FokusSpacing.xl)
    }

    private func detailSheetBinding(isWide: Bool) -> Binding<Bool> {
        Binding(
            get: { !isWide && selectedTask != nil },
            set: { if !$0 { selectedId = nil } })
    }

    @ViewBuilder private var detailSheet: some View {
        if let task = selectedTask {
            NavigationStack {
                ScrollView {
                    TaskDetailView(
                        task: task, context: rowContext,
                        subjectGroups: subjectGroups(keeping: task.subjectId), showsTitle: false,
                        onDeleted: { selectedId = nil })
                        .padding(FokusSpacing.screenHorizontal)
                }
                .background(.fkBackground)
                .navigationTitle(task.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Kapat") { selectedId = nil }.accessibilityIdentifier("task.detail.close")
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Eylemler

    private func toggle(_ id: UUID) {
        guard let task = liveTasks.first(where: { $0.id == id }) else { return }
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

#Preview("Görevler — boş") {
    TasksScreen()
        .fokusTheme()
        .modelContainer(PreviewSupport.onboardedContainer())
}
