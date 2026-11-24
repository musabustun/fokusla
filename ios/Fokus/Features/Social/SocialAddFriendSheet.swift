import FokusData
import FokusDesign
import SwiftUI

/// Arkadaş ekle: tam kullanıcı adına istek, tek kullanımlık davet bağlantısı/QR ya da gelen bağlantıyı yapıştırma.
struct SocialAddFriendSheet: View {
    let social: any SocialService

    private enum Mode: String, CaseIterable, Identifiable {
        case username, link, paste
        var id: String { rawValue }
        var title: String {
            switch self {
            case .username: "Kullanıcı adı"
            case .link: "Bağlantı"
            case .paste: "Davetim var"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .username
    @State private var value = ""
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var invite: FriendInvite?

    var body: some View {
        SocialSheetScaffold(title: "Arkadaş ekle", description: nil, identifier: "social.addFriend") {
            Picker("Ekleme yöntemi", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("social.addFriend.mode")
            switch mode {
            case .username: usernameForm
            case .link: linkForm
            case .paste: SocialPasteInviteForm(social: social) { dismiss() }
            }
        }
        .onChange(of: value) { _, _ in errorMessage = nil }
        .onChange(of: mode) { _, _ in errorMessage = nil }
    }

    @ViewBuilder private var usernameForm: some View {
        Text("Arkadaşının kullanıcı adını tam olarak yaz. Böyle biri varsa isteğin ona gider; kabul edene kadar birbirinizi görmezsiniz.")
            .fokusTextStyle(.callout).foregroundStyle(.fkSecondaryLabel)
        SocialTextField(
            label: "Kullanıcı adı", prefix: "@", text: $value, placeholder: "kullanici_adi", error: errorMessage,
            identifier: "social.addFriend.field", onSubmit: { if !isEmpty { sendRequest() } })
        Button("İstek gönder", action: sendRequest)
            .buttonStyle(.fokusPrimary)
            .disabled(isBusy || isEmpty)
            .accessibilityIdentifier("social.addFriend.submit")
    }

    @ViewBuilder private var linkForm: some View {
        Text("Bağlantıyı ya da QR kodu arkadaşınla paylaş. Her bağlantı tek kişiliktir ve 30 gün geçerlidir. Açan kişi iOS'un davet ekranında iCloud adını görebilir.")
            .fokusTextStyle(.callout).foregroundStyle(.fkSecondaryLabel)
        if let invite {
            SocialShareBlock(
                url: invite.url, message: "Fokus'ta birlikte çalışalım", identifier: "social.addFriend.invite")
        }
        if let errorMessage { SocialErrorText(message: errorMessage, identifier: "social.addFriend.error") }
        Button(invite == nil ? "Davet bağlantısı oluştur" : "Başkası için yeni bağlantı", action: createInvite)
            .buttonStyle(.fokusSecondary)
            .disabled(isBusy)
            .accessibilityIdentifier("social.addFriend.createInvite")
    }

    private var isEmpty: Bool { value.trimmingCharacters(in: .whitespaces).isEmpty }

    private func sendRequest() {
        run {
            try await social.sendFriendRequest(.username(value))
            dismiss()
        }
    }

    private func createInvite() {
        run { invite = try await social.createFriendInvite() }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do { try await action() } catch { errorMessage = SocialError.message(for: error) }
        }
    }
}
