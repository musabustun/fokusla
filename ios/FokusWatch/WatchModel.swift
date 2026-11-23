import CoreData
import FokusData
import FokusDomain
import Foundation
import Observation
import SwiftData

/// Saat uygulamasının tek durum kaynağı. Veri SwiftData'dadır (iPhone ile aynı modeller, CloudKit
/// eşitler); anlık oturum durumu `FocusLinkCoordinator` ile telefondan da gelir. Süre sayacı
/// `Text(timerInterval:)` ile sistemce sayıldığından burada saniyelik güncelleme YOKTUR.
@MainActor
@Observable
final class WatchModel {
    struct FinishedSummary: Equatable {
        let focusMs: Double
    }

    let container: ModelContainer
    /// Ekranda gösterilecek açık oturum (yerel depo + telefondan gelen bildirim, yeni olan).
    private(set) var live: FocusLink.LiveState?
    private(set) var lastFinished: FinishedSummary?
    private(set) var actionFailed = false

    @ObservationIgnored private let link = FocusLinkCoordinator.shared
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var pendingRefresh: Task<Void, Never>?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    init(container: ModelContainer) {
        self.container = container
        link.onChange = { [weak self] in self?.refresh() }
        link.start()
        observeStore()
        refresh()
    }

    // MARK: - Okuma

    /// Depo ya da telefon değişince çağrılır. Haptik ipucu, görünen durumun GEÇİŞİNDEN çıkar; böylece
    /// saatte dokunmak da telefondan gelen değişiklik de aynı tek yoldan titreşir (çift titreşim yok).
    func refresh(now: Date = .now, reloadWidgets: Bool = false) {
        let resolved = link.resolvedLive(now: now)
        if hasLoaded, let cue = FocusLink.cue(from: live, to: resolved) { WatchHaptics.play(cue) }
        hasLoaded = true
        if !Self.isSame(live, resolved) { live = resolved }
        if reloadWidgets { FokusSystem.reloadWidgets() }
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

    // Eylemler HER ZAMAN saatin kendi deposuna yazılır (telefon uzakta olsa da çalışır); kayıt eşlemesi
    // (`FocusLinkCoordinator`) değişen kayıtları telefona yollar ya da kuyruğa alır.

    /// Ders seçmeden hemen başlatır (ders opsiyoneldir; telefondan sonradan eklenebilir).
    func start() {
        perform { _ = try FocusActions.start(subjectId: nil) }
        if !actionFailed { lastFinished = nil }
    }

    /// Odaktaysa mola, moladaysa devam (telefondaki tam ekran ve Live Activity ile aynı işlem).
    func togglePause() {
        perform { _ = try FocusActions.togglePause() }
    }

    func finish() {
        let summary = live.map { FinishedSummary(focusMs: Self.sessionFocusMs($0.state)) }
        perform {
            if case let .finished(focusMs) = try FocusActions.finish() {
                lastFinished = FinishedSummary(focusMs: focusMs)
            } else {
                lastFinished = summary
            }
        }
    }

    private func perform(_ action: () throws -> Void) {
        actionFailed = false
        do {
            try action()
        } catch {
            actionFailed = true
        }
        refresh()
    }

    /// Aynı görünüm mü? Çapalar her hesapta `now`'dan türediği için milisaniye sapmaları yok sayılır
    /// (gereksiz yeniden çizim olmasın).
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
