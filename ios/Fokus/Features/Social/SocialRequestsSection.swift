import FokusData
import FokusDesign
import SwiftUI

/// Gelen (kabul/ret/engelle) ve giden (geri çek) istekler ile kullanılmamış davet bağlantıları. Boşsa görünmez.
struct SocialRequestsSection: View {
    let social: any SocialService
    let requests: [FriendRequest]
    let invites: [FriendInvite]

    @State private var busyId: String?
    @State private var errorMessage: String?

    var body: some View {
        if !requests.isEmpty || !invites.isEmpty {
            VStack(alignment: .leading, spacing: FokusSpacing.sm) {
                Text("İstekler")
                    .fokusTextStyle(.eyebrow)
                    .foregroundStyle(.fkSecondaryLabel)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    Divider().overlay(.fkSeparator)
                    ForEach(requests) { request in
                        switch request.direction {
                        case .incoming: incomingRow(request)
                        case .outgoing: outgoingRow(request)
                        }
                    }
                    ForEach(invites) { inviteRow($0) }
                }
                if let errorMessage {
                    SocialErrorText(message: errorMessage, identifier: "social.requests.error")
                }
            }
            .socialContainer("social.requests")
        }
    }

    private func incomingRow(_ request: FriendRequest) -> some View {
        let username = request.user.username
        return row(id: request.id) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    title("@\(username)", subtitle: "Seni arkadaş olarak eklemek istiyor")
                    Spacer(minLength: FokusSpacing.sm)
                    SocialSafetyMenu(username: username) {
                        run(request.id) { try await social.blockRequest(id: request.id) }
                    }
                }
                HStack(spacing: FokusSpacing.sm) {
                    Button("Kabul et") {
                        run(request.id) { try await social.respondToRequest(id: request.id, accept: true) }
                    }
                    .buttonStyle(SocialChipButtonStyle())
                    .accessibilityLabel("@\(username) isteğini kabul et")
                    .accessibilityIdentifier("social.request.accept.\(username)")
                    Button("Reddet") {
                        run(request.id) { try await social.respondToRequest(id: request.id, accept: false) }
                    }
                    .buttonStyle(SocialChipButtonStyle(kind: .quiet))
                    .accessibilityLabel("@\(username) isteğini reddet")
                    .accessibilityIdentifier("social.request.decline.\(username)")
                }
            }
        }
    }

    private func outgoingRow(_ request: FriendRequest) -> some View {
        let username = request.user.username
        return row(id: request.id) {
            HStack(spacing: FokusSpacing.sm) {
                title("@\(username)", subtitle: "Yanıt bekleniyor")
                Spacer(minLength: FokusSpacing.sm)
                Button("Geri çek") { run(request.id) { try await social.cancelRequest(id: request.id) } }
                    .buttonStyle(SocialChipButtonStyle(kind: .quiet))
                    .accessibilityLabel("@\(username) isteğini geri çek")
                    .accessibilityIdentifier("social.request.cancel.\(username)")
            }
        }
    }

    private func inviteRow(_ invite: FriendInvite) -> some View {
        row(id: invite.id) {
            HStack(spacing: FokusSpacing.xs) {
                title("Davet bağlantısı", subtitle: "Henüz kullanılmadı")
                Spacer(minLength: FokusSpacing.sm)
                ShareLink(item: invite.url) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: fokusMinTapTarget, height: fokusMinTapTarget)
                }
                .accessibilityLabel("Davet bağlantısını paylaş")
                Button("Geri çek") { run(invite.id) { try await social.cancelInvite(id: invite.id) } }
                    .buttonStyle(SocialChipButtonStyle(kind: .quiet))
                    .accessibilityLabel("Davet bağlantısını geri çek")
                    .accessibilityIdentifier("social.invite.cancel")
            }
        }
    }

    private func title(_ text: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text).fokusTextStyle(.body).foregroundStyle(.fkLabel).lineLimit(1).minimumScaleFactor(0.8)
            Text(subtitle).fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
        }
    }

    private func row<Content: View>(id: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
                .disabled(busyId == id)
                .frame(minHeight: fokusMinTapTarget)
                .padding(.vertical, FokusSpacing.sm)
            Divider().overlay(.fkSeparator)
        }
    }

    private func run(_ id: String, _ action: @escaping () async throws -> Void) {
        busyId = id
        errorMessage = nil
        Task {
            defer { busyId = nil }
            do { try await action() } catch { errorMessage = SocialError.message(for: error) }
        }
    }
}
