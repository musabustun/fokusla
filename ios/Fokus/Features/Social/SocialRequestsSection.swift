import FokusData
import FokusDesign
import SwiftUI

/// Gelen (kabul/ret) ve giden (geri çek) arkadaşlık istekleri. İstek yoksa görünmez.
struct SocialRequestsSection: View {
    let social: any SocialService
    let requests: [FriendRequest]

    @State private var busyId: String?
    @State private var errorMessage: String?

    var body: some View {
        if !requests.isEmpty {
            VStack(alignment: .leading, spacing: FokusSpacing.sm) {
                Text("İstekler")
                    .fokusTextStyle(.eyebrow)
                    .foregroundStyle(.fkSecondaryLabel)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    Divider().overlay(.fkSeparator)
                    ForEach(requests) { request in row(request) }
                }
                if let errorMessage {
                    SocialErrorText(message: errorMessage, identifier: "social.requests.error")
                }
            }
            .socialContainer("social.requests")
        }
    }

    private func row(_ request: FriendRequest) -> some View {
        let name = "@\(request.user.username)"
        let isBusy = busyId == request.id
        let isIncoming = request.direction == .incoming
        return VStack(spacing: 0) {
            HStack(spacing: FokusSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).fokusTextStyle(.body).foregroundStyle(.fkLabel).lineLimit(1).minimumScaleFactor(0.8)
                    Text(isIncoming ? "Seni arkadaş olarak eklemek istiyor" : "Yanıt bekleniyor")
                        .fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                }
                Spacer(minLength: FokusSpacing.sm)
                if isIncoming {
                    Button("Reddet") { run(request.id) { try await social.respondToRequest(id: request.id, accept: false) } }
                        .buttonStyle(SocialChipButtonStyle(kind: .quiet))
                        .accessibilityLabel("\(name) isteğini reddet")
                        .accessibilityIdentifier("social.request.decline.\(request.user.username)")
                    Button("Kabul et") { run(request.id) { try await social.respondToRequest(id: request.id, accept: true) } }
                        .buttonStyle(SocialChipButtonStyle())
                        .accessibilityLabel("\(name) isteğini kabul et")
                        .accessibilityIdentifier("social.request.accept.\(request.user.username)")
                } else {
                    Button("Geri çek") { run(request.id) { try await social.cancelRequest(id: request.id) } }
                        .buttonStyle(SocialChipButtonStyle(kind: .quiet))
                        .accessibilityLabel("\(name) isteğini geri çek")
                        .accessibilityIdentifier("social.request.cancel.\(request.user.username)")
                }
            }
            .disabled(isBusy)
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
            do { try await action() } catch let error as SocialError {
                errorMessage = error.userMessage
            } catch {
                errorMessage = "Bir şeyler ters gitti. Lütfen tekrar dene."
            }
        }
    }
}
