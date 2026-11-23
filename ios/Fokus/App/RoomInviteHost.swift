import FokusDesign
import FokusDomain
import SwiftUI

extension RoomInvite: Identifiable {}

/// iMessage'dan gelen `fokus://room?…` bağlantısını yakalar ve "Odaya katıl" sayfasını açar.
/// Sunucu yoktur: oda tamamen bağlantıdadır. Odak ANCAK kullanıcı "Başla"ya dokunursa başlar
/// (başlangıç saati gelmeden düğme kapalıdır). Bağlantı dışarıdan gelir; çözme `RoomInvite(url:)` ile doğrulanır.
struct RoomInviteHost: ViewModifier {
    @State private var invite: RoomInvite?

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                // Spotify geri dönüşü vb. başka `fokus://` bağlantıları burada çözülemez ve yok sayılır.
                if let parsed = try? RoomInvite(url: url) { invite = parsed }
            }
            // Sayfa boş bir arka plana bağlanır: kökteki `.sheet` altındaki ekranların kendi sayfalarıyla
            // (ör. Kitaplar'ın form sayfası) çakışmasın.
            .background {
                Color.clear.sheet(item: $invite) { invite in
                    RoomJoinSheet(invite: invite)
                        .presentationDetents([.large])
                }
            }
    }
}

extension View {
    /// Kök görünüme uygulanır (`FokusApp`).
    func roomInviteHost() -> some View { modifier(RoomInviteHost()) }
}

struct RoomJoinSheet: View {
    let invite: RoomInvite
    @Environment(\.dismiss) private var dismiss
    @State private var outcome: Outcome?

    private enum Outcome { case started, alreadyRunning, failed }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let phase = invite.phase(now: context.date)
            VStack(alignment: .leading, spacing: FokusSpacing.lg) {
                Text("ORTAK ODAK").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                RoomInviteCardView(invite: invite).frame(maxWidth: .infinity)
                Text(title(for: phase)).fokusTextStyle(.title2).foregroundStyle(.fkLabel)
                if let outcome { Text(message(outcome)).fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel) }
                Spacer(minLength: 0)
                primaryButton(phase)
                Button("Kapat") { dismiss() }
                    .fokusTextStyle(.callout).foregroundStyle(.fkSecondaryLabel)
                    .frame(maxWidth: .infinity, minHeight: fokusMinTapTarget)
            }
            .padding(FokusSpacing.screenHorizontal)
            .background(.fkBackground)
        }
    }

    private func title(for phase: RoomInvite.Phase) -> String {
        switch phase {
        case .upcoming(let seconds): "Başlamasına \(SocialFormat.formatClock(seconds * 1000))"
        case .live(let seconds): "Oda sürüyor · \(SocialFormat.formatClock(seconds * 1000)) kaldı"
        case .ended: "Bu oda bitti"
        }
    }

    private func message(_ outcome: Outcome) -> String {
        switch outcome {
        case .started: "Odak başladı. Odak sekmesinden süreni izleyebilirsin."
        case .alreadyRunning: "Zaten bir odak oturumun sürüyor."
        case .failed: "Odak başlatılamadı. Fokus'u kapatıp tekrar aç."
        }
    }

    @ViewBuilder
    private func primaryButton(_ phase: RoomInvite.Phase) -> some View {
        let enabled: Bool = {
            if case .live = phase { return outcome != .started }
            return false
        }()
        Button {
            start()
        } label: {
            Text(outcome == .started ? "Odak başladı" : "Başla")
                .fokusTextStyle(.headline).foregroundStyle(.fkAccentContrast)
                .frame(maxWidth: .infinity, minHeight: fokusMinTapTarget)
                .background(.fkAccent, in: Capsule())
                .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    @MainActor private func start() {
        do {
            switch try FocusActions.start(subjectId: nil) {
            case .started: outcome = .started
            case .alreadyRunning: outcome = .alreadyRunning
            default: outcome = .failed
            }
        } catch {
            outcome = .failed
        }
    }
}
