import FokusData
import FokusDomain
import Foundation
import Observation
import SwiftData

/// iPhone ↔ saat odak eşlemesi (iki hedefe de derlenir). Her cihazın deposu kendi doğruluk kaynağıdır;
/// başlat/mola/devam/bitir HER ZAMAN yerel depoya yazılır (telefon yanında olmasa da), sonra değişen
/// `FocusSession`/`FocusSegment` kayıtları tam haliyle karşıya gider ve orada `id` ile idempotent yazılır
/// (`FocusLinkRepository`). Böylece:
/// - telefonda başlatılan oturum saatte, saatte başlatılan oturum telefonda anında görünür ve iki taraftan
///   da mola/devam/bitir yapılabilir;
/// - telefon uzaktayken saatte yapılanlar sistem kuyruğunda bekler, buluşunca telefona işlenir ve oradan
///   CloudKit ile iPad'e gider (saat deposu CloudKit'e bağlı değildir; bkz. `FocusLinkSync.swift`).
/// Kurallar saf ve testlidir: `FokusDomain/Calc/FocusLinkSync.swift`.
@MainActor
@Observable
final class FocusLinkCoordinator {
    static let shared = FocusLinkCoordinator()

    /// Karşıdan gelen ders adları (saatte ders kaydı yoktur; gösterim önbelleği).
    private(set) var subjectNames: [UUID: String] = [:]
    /// Karşıdan kayıt gelip depoya işlendiğinde çağrılır (ekran yenilensin).
    @ObservationIgnored var onChange: (() -> Void)?
    /// Karşıdan gelen kayıt işlendikten sonra (iPhone: Live Activity + widget eşitlemesi).
    @ObservationIgnored var onRecordsApplied: (() -> Void)?

    @ObservationIgnored private let transport = FocusLinkTransport()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isStarted = false
    /// Karşıdan aynen alınan sürümler (`id` → `updatedAt`): geri yollanmaz.
    @ObservationIgnored private var echo: [UUID: Date] = [:]
    @ObservationIgnored private var pendingPublish: Task<Void, Never>?
    @ObservationIgnored private var saveObserver: (any NSObjectProtocol)?

    private static let lastSentKey = "fokus.link.lastSent"
    private static let subjectNamesKey = "fokus.link.subjectNames"
    private static let publishDebounce: Duration = .milliseconds(300)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let cached = defaults.dictionary(forKey: Self.subjectNamesKey) as? [String: String] ?? [:]
        subjectNames = Dictionary(
            cached.compactMap { key, value in UUID(uuidString: key).map { ($0, value) } },
            uniquingKeysWith: { first, _ in first })
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        transport.onRecords = { [weak self] batch in self?.receive(batch) }
        transport.onActivated = { [weak self] in self?.peerStateChanged() }
        // Her yerel kayıt (uygulama, intent, Live Activity düğmesi) karşıya gitsin.
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.schedulePublish() }
        }
        transport.activate()
    }

    // MARK: - Durum

    /// Yerel depodaki açık oturum (ekran için).
    func resolvedLive(now: Date = .now) -> FocusLink.LiveState? {
        guard let snapshot = try? FokusSystem.snapshot(now: now), let id = snapshot.activeSessionId,
            let state = snapshot.activity
        else { return nil }
        let subject = snapshot.activeSubjectLabel ?? activeSubjectId().flatMap { subjectNames[$0] }
        return FocusLink.LiveState(sessionId: id, state: state, subjectName: subject)
    }

    private func activeSubjectId() -> UUID? {
        guard let context = try? FokusSystem.context() else { return nil }
        return (try? FocusRepository(context: context).findActive())?.subjectId
    }

    // MARK: - Gönderme

    private var lastSent: Date? {
        get { defaults.object(forKey: Self.lastSentKey) as? Date }
        set { defaults.set(newValue, forKey: Self.lastSentKey) }
    }

    /// Kayıt dalgalarını (bir eylem birkaç kayıt yazar) tek gönderime indirir.
    func schedulePublish() {
        pendingPublish?.cancel()
        pendingPublish = Task { [weak self] in
            try? await Task.sleep(for: Self.publishDebounce)
            guard !Task.isCancelled else { return }
            self?.publish()
        }
    }

    /// Son gönderimden sonra değişen odak kayıtlarını karşıya yollar.
    func publish(now: Date = .now) {
        guard transport.isPeerAvailable, let context = try? FokusSystem.context() else { return }
        guard
            let batch = try? FocusLinkRepository(context: context).outgoing(
                lastSent: lastSent, echo: echo, subjectNames: localSubjectNames(context), now: now),
            let latest = batch.latestUpdate
        else { return }
        let sent = FocusLink.chunked(batch).allSatisfy { transport.send($0) }
        if sent { lastSent = max(lastSent ?? .distantPast, latest) }
    }

    private func localSubjectNames(_ context: ModelContext) -> [UUID: String] {
        let subjects = (try? context.fetch(FetchDescriptor<Subject>())) ?? []
        return Dictionary(
            subjects.filter(\.isLive).map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private func peerStateChanged() {
        // iPhone: saat uygulaması kaldırıldıysa bir sonraki kurulumda son 8 gün yeniden gitsin.
        if !transport.isPeerAvailable { lastSent = nil }
        publish()
    }

    // MARK: - Alma

    private func receive(_ batch: FocusLink.RecordBatch) {
        if !batch.subjectNames.isEmpty {
            subjectNames.merge(batch.subjectNames) { _, new in new }
            defaults.set(
                Dictionary(uniqueKeysWithValues: subjectNames.map { ($0.key.uuidString, $0.value) }),
                forKey: Self.subjectNamesKey)
        }
        for record in batch.sessions { echo[record.id] = record.updatedAt }
        for record in batch.segments { echo[record.id] = record.updatedAt }
        // Ana bağlama yazılır: `@Query` ekranları (telefonda tam ekran odak) anında güncellenir.
        guard let context = try? FokusSystem.container().mainContext,
            let applied = try? FocusLinkRepository(context: context).apply(batch), applied > 0
        else { return }
        FokusSystem.reloadWidgets()
        onRecordsApplied?()
        onChange?()
    }
}
