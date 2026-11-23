import CoreData
import FokusData
import FokusDomain
import Foundation
import Observation
import SwiftData

/// Saat uygulamasının tek durum kaynağı. Veri SwiftData'dadır (iPhone ile aynı modeller, CloudKit
/// eşitler); anlık oturum durumu `FocusLinkCoordinator` ile telefondan da gelir. Süre sayaçları
/// `Text(timerInterval:)` ile sistemce sayıldığından burada saniyelik güncelleme YOKTUR.
@MainActor
@Observable
final class WatchModel {
    struct SubjectItem: Identifiable, Hashable {
        let id: UUID
        let name: String
    }

    struct FinishedSummary: Equatable {
        let focusMs: Double
        let at: Date
    }

    private static let subjectKey = "fokus.watch.subject"

    let container: ModelContainer
    private(set) var snapshot: FokusSystemSnapshot?
    /// Ekranda gösterilecek açık oturum (yerel depo + telefondan gelen bildirim, yeni olan).
    private(set) var live: FocusLink.LiveState?
    private(set) var subjects: [SubjectItem] = []
    private(set) var lastFinished: FinishedSummary?
    private(set) var actionFailed = false

    var selectedSubjectId: UUID? {
        didSet { UserDefaults.standard.set(selectedSubjectId?.uuidString, forKey: Self.subjectKey) }
    }

    @ObservationIgnored private let link = FocusLinkCoordinator.shared
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var pendingRefresh: Task<Void, Never>?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    init(container: ModelContainer) {
        self.container = container
        selectedSubjectId = UserDefaults.standard.string(forKey: Self.subjectKey).flatMap(UUID.init(uuidString:))
        link.onChange = { [weak self] in self?.refresh() }
        link.start()
        observeStore()
        refresh()
    }

    var selectedSubjectName: String? {
        selectedSubjectId.flatMap { id in subjects.first { $0.id == id }?.name }
    }

    // MARK: - Okuma

    /// Depo ya da telefon değişince çağrılır. Haptik ipucu, görünen durumun GEÇİŞİNDEN çıkar; böylece
    /// saatte dokunmak da telefondan gelen değişiklik de aynı tek yoldan titreşir (çift titreşim yok).
    func refresh(now: Date = .now, reloadWidgets: Bool = false) {
        guard let fresh = try? FokusSystem.snapshot(now: now) else { return }
        snapshot = fresh
        let resolved = link.resolvedLive(now: now)
        if hasLoaded, let cue = FocusLink.cue(from: live, to: resolved) { WatchHaptics.play(cue) }
        hasLoaded = true
        if !Self.isSame(live, resolved) {
            live = resolved
            WatchReminders.sync(live: resolved, now: now)
        }
        loadSubjects()
        if reloadWidgets { FokusSystem.reloadWidgets() }
    }

    private func loadSubjects() {
        guard let context = try? FokusSystem.context(),
            let all = try? context.fetch(FetchDescriptor<Subject>())
        else { return }
        let field = (try? ProfileRepository(context: context).current())?.field
        let examOrder: [ExamType] = [.tyt, .ayt, .ydt]
        let visible = all.filter { $0.isLive && (field.map($0.fields.contains) ?? true) }
        var seen = Set<UUID>()
        subjects = visible
            .sorted { lhs, rhs in
                let (left, right) = (examOrder.firstIndex(of: lhs.exam) ?? 9, examOrder.firstIndex(of: rhs.exam) ?? 9)
                if left != right { return left < right }
                if lhs.order != rhs.order { return lhs.order < rhs.order }
                return lhs.name.compare(rhs.name, locale: Locale(identifier: "tr_TR")) == .orderedAscending
            }
            .filter { seen.insert($0.id).inserted }
            .map { SubjectItem(id: $0.id, name: $0.name) }
    }

    private func observeStore() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            ModelContext.didSave, NSPersistentCloudKitContainer.eventChangedNotification,
            .NSPersistentStoreRemoteChange,
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleRefresh() }
            }
        }
    }

    /// Kayıt/CloudKit dalgalarını tek yenilemeye indirir.
    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.refresh(reloadWidgets: true)
        }
    }

    // MARK: - Eylemler

    func start() async {
        actionFailed = false
        await WatchReminders.requestAuthorizationIfNeeded()
        do {
            _ = try FocusActions.start(subjectId: selectedSubjectId)
            lastFinished = nil
            link.publish()
            refresh()
        } catch {
            actionFailed = true
        }
    }

    /// Odaktaysa duraklatır, moladaysa devam ettirir.
    func togglePause() async {
        let handled = await link.perform(live?.state.phase == .focus ? .pause : .resume)
        actionFailed = !handled
        refresh()
    }

    func finish() async {
        let summary = live.map { FinishedSummary(focusMs: Self.sessionFocusMs($0.state), at: .now) }
        let handled = await link.perform(.finish)
        actionFailed = !handled
        if handled { lastFinished = summary }
        refresh()
    }

    func toggleTask(_ id: UUID) {
        do {
            try FocusActions.toggleTask(id: id)
            WatchHaptics.tap()
            refresh()
        } catch {
            actionFailed = true
        }
    }

    /// Aynı görünüm mü? Çapalar her hesapta `now`'dan türediği için milisaniye sapmaları yok sayılır
    /// (gereksiz yeniden çizim ve bildirim yeniden kurulumu olmasın).
    private static func isSame(_ lhs: FocusLink.LiveState?, _ rhs: FocusLink.LiveState?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): true
        case let (lhs?, rhs?):
            lhs.sessionId == rhs.sessionId && lhs.subjectName == rhs.subjectName
                && lhs.state.isEquivalent(to: rhs.state)
        default: false
        }
    }

    /// Oturumun toplam odak süresi (ms): odakta `şimdi`ye, molada mola başlangıcına kadar.
    static func sessionFocusMs(_ state: FocusActivityCalc.State, now: Date = .now) -> Double {
        guard let start = state.sessionFocusStart else { return 0 }
        let end = state.phase == .focus ? now : state.timerStart
        return max(0, end.timeIntervalSince(start) * 1000)
    }
}
