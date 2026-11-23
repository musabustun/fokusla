import FokusAudio
import FokusData
import FokusDesign
import FokusDomain
import Foundation
import SwiftData
import SwiftUI

/// Tam ekran görünümün "küçültüldü" durumu. Ortamla (`\.immersiveCoordinator`) Odak ekranına da verilir:
/// oradaki "Tam ekran" düğmesi `reopen()` çağırır.
@MainActor
@Observable
final class ImmersiveFocusCoordinator {
    private(set) var minimizedSessionId: UUID?

    func minimize(sessionId: UUID) { minimizedSessionId = sessionId }
    func reopen() { minimizedSessionId = nil }
}

/// Kapağın açık olup olmayacağı (saf mantık): açık oturum varsa ve KÜÇÜLTÜLMEMİŞSE. Küçültme oturum
/// kimliğine bağlıdır; bu yüzden yeni oturum her zaman tam ekran açar, oturum bitince durum kendiliğinden düşer.
enum ImmersivePresentation {
    static func shouldPresent(activeSessionId: UUID?, minimizedSessionId: UUID?) -> Bool {
        guard let activeSessionId else { return false }
        return activeSessionId != minimizedSessionId
    }
}

extension EnvironmentValues {
    /// Kök (`FokusApp`) sağlar; önizlemelerde `nil` olabilir.
    @Entry var immersiveCoordinator: ImmersiveFocusCoordinator? = nil
}

/// Açık odak oturumu için `fullScreenCover`'ı kökte sunar. Kökte olması, oturum açıkken uygulama
/// başka sekmede (ya da yeniden başlatıldığında) açılsa bile tam ekranın gelmesini sağlar.
///
/// Özet sheet'i yarışı: "Bitir" ile oturum biter, kapak kapanmaya başlar. Sheet'i hemen sunmak
/// "zaten sunum var" çakışmasına yol açar; bu yüzden özet `pendingSummary`de bekler ve kapağın
/// `onDismiss` geri çağrısında (kapanış tamamlanınca) gösterilir.
private struct ImmersiveCoverHost<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.focusSound) private var focusSound
    @Query(filter: #Predicate<FocusSession> { $0.deletedAt == nil }, sort: \FocusSession.startedAt, order: .reverse)
    private var sessions: [FocusSession]

    @State private var coordinator = ImmersiveFocusCoordinator()
    @State private var isPresented = false
    @State private var pendingSummary: FocusCalc.FocusSessionStats?
    @State private var summary: SummaryItem?

    private struct SummaryItem: Identifiable {
        let id = UUID()
        let stats: FocusCalc.FocusSessionStats
    }

    private var activeSessionId: UUID? {
        sessions.filter { $0.endedAt == nil }.max { $0.startedAt < $1.startedAt }?.id
    }

    private var shouldPresent: Bool {
        ImmersivePresentation.shouldPresent(
            activeSessionId: activeSessionId, minimizedSessionId: coordinator.minimizedSessionId)
    }

    var body: some View {
        content
            .environment(\.immersiveCoordinator, coordinator)
            // `.task`: görünüm pencereye girdikten sonra çalışır; ilk karede sunmaya çalışmaz.
            .task(id: shouldPresent) { isPresented = shouldPresent }
            .fullScreenCover(isPresented: $isPresented, onDismiss: coverDidDismiss) {
                ImmersiveFocusView(
                    onMinimize: {
                        if let id = activeSessionId { coordinator.minimize(sessionId: id) }
                    },
                    onFinished: { pendingSummary = $0 }
                )
                .fokusTheme()
            }
            .sheet(item: $summary) { item in
                FocusSummarySheet(stats: item.stats) { summary = nil }
                    .presentationDetents([.medium, .large])
                    .presentationBackground(.fkBackground)
            }
            .onChange(of: activeSessionId) { old, new in
                // Oturum bitince (nereden olursa olsun) odak sesi susar.
                if old != nil && new == nil { focusSound?.stop() }
                // Odak filtresi bir ses seçtiyse yeni oturumda o ses çalar.
                if old == nil, new != nil,
                    let raw = FocusFilterStore.load().ambientSoundRaw, let kind = FocusSoundKind(rawValue: raw)
                {
                    focusSound?.play(kind)
                }
            }
    }

    private func coverDidDismiss() {
        // `.onDisappear` zaten çağrılmış olabilir; ikisi de idempotent.
        ImmersiveScreenAwake.deactivate()
        ImmersiveOrientation.setImmersiveActive(false)
        guard let stats = pendingSummary else { return }
        pendingSummary = nil
        summary = SummaryItem(stats: stats)
    }
}

extension View {
    /// Kök görünüme uygulanır: açık oturum varken tam ekran odak kapağını sunar.
    func immersiveFocusHost() -> some View {
        ImmersiveCoverHost { self }
    }
}

/// UI testlerinde son seçilen sayfa ve StandBy tercihleri testler arasında sızmasın: `-FokusUITestMode` ile
/// başlarken saklanan sayfa silinir ve tercihler varsayılana (gece kırmızısı varsayılan kapalı: saatten bağımsız) döner.
/// Yeniden başlatmada hatırlamayı sınayan test `-FokusUITestKeepImmersivePage` verir.
/// `-FokusUITestStandBy <json>` tercihleri açıkça verir (eksik anahtarlar varsayılan).
enum ImmersiveUITestSupport {
    static func resetStoredPageIfNeeded(
        arguments: [String] = ProcessInfo.processInfo.arguments, defaults: UserDefaults = .standard,
        preferencesDefaults: UserDefaults = ImmersiveStorage.preferencesDefaults
    ) {
        guard arguments.contains("-FokusUITestMode") else { return }
        if !arguments.contains("-FokusUITestKeepImmersivePage") {
            defaults.removeObject(forKey: ImmersiveStorage.pageKey)
            preferencesDefaults.set(StandByPreferences.default.encoded(), forKey: StandByPreferences.storageKey)
        }
        if let json = value(after: "-FokusUITestStandBy", in: arguments), let data = json.data(using: .utf8) {
            preferencesDefaults.set(overlay(json: data, on: .default).encoded(), forKey: StandByPreferences.storageKey)
        }
        // Başlangıç sayfası `-FokusUITestImmersivePage <raw>` ile verilir. `-fokus.focus.immersivePage`
        // KULLANILMAZ: UserDefaults argüman alanı uygulamanın yazdığı değeri ezer, sayfa hiç değişmezdi.
        if let raw = value(after: "-FokusUITestImmersivePage", in: arguments), StandByPage(rawValue: raw) != nil {
            defaults.set(raw, forKey: ImmersiveStorage.pageKey)
        }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    /// Kısmi JSON'u (`{"nightMode":"on"}`) taban tercihlerin üstüne bindirir.
    private static func overlay(json: Data, on base: StandByPreferences) -> StandByPreferences {
        guard let patch = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
            let baseObject = try? JSONSerialization.jsonObject(with: base.encoded()) as? [String: Any]
        else { return base }
        let merged = baseObject.merging(patch) { _, new in new }
        guard let data = try? JSONSerialization.data(withJSONObject: merged) else { return base }
        return StandByPreferences.decoded(from: data)
    }
}
