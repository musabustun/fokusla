import FokusData
import SwiftData
import SwiftUI

/// Yerel hatırlatmaları güncel tutar: açılışta, uygulama öne gelince ve veri kaydedilince (ör. odak
/// oturumu bitti → hedefe ulaşıldıysa bugünün çalışma bildirimi iptal edilir; rutin tamamlandı →
/// bugünkü rutin bildirimi güncellenir) yeniden planlar. Kayıt dalgalarını tek çağrıya indirgemek
/// için kısa süre bekler (debounce). Hiçbir hatırlatma açık değilse ya da izin yoksa hiçbir şey planlamaz.
struct ReminderCoordinator: ViewModifier {
    private static let debounce: Duration = .seconds(2)

    @Environment(\.modelContext) private var modelContext
    @Environment(\.notificationService) private var notificationService
    @Environment(\.scenePhase) private var scenePhase
    @State private var pending: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .task { schedule(after: .zero) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { schedule(after: .zero) }
            }
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                schedule(after: Self.debounce)
            }
    }

    private func schedule(after delay: Duration) {
        guard let service = notificationService else { return }
        pending?.cancel()
        let context = modelContext
        pending = Task {
            if delay > .zero { try? await Task.sleep(for: delay) }
            guard !Task.isCancelled else { return }
            await ReminderScheduler(service: service).reschedule(context: context)
        }
    }
}
