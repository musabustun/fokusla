import FokusData
import FokusDesign
import SwiftUI

/// Arkadaş ekle: kullanıcı adıyla ya da davet koduyla istek gönderir (web `AddFriendSheet`).
struct SocialAddFriendSheet: View {
    let social: any SocialService

    @Environment(\.dismiss) private var dismiss
    @State private var byUsername = true
    @State private var value = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        SocialSheetScaffold(
            title: "Arkadaş ekle",
            description: "Arkadaşının kullanıcı adını ya da davet kodunu gir. İsteği kabul edince birbirinizin durumunu görürsünüz.",
            identifier: "social.addFriend"
        ) {
            Picker("Arama yöntemi", selection: $byUsername) {
                Text("Kullanıcı adı").tag(true)
                Text("Davet kodu").tag(false)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("social.addFriend.mode")
            .onChange(of: byUsername) { _, _ in
                value = ""
                errorMessage = nil
            }
            SocialTextField(
                label: byUsername ? "Kullanıcı adı" : "Davet kodu",
                prefix: byUsername ? "@" : nil, text: $value,
                placeholder: byUsername ? "kullanici_adi" : "K7M2QX",
                hint: byUsername ? nil : "6 karakter, ör. K7M2QX", error: errorMessage,
                capitalization: byUsername ? .never : .characters, identifier: "social.addFriend.field",
                onSubmit: { if !value.trimmingCharacters(in: .whitespaces).isEmpty { submit() } })
            Button("İstek gönder", action: submit)
                .buttonStyle(.fokusPrimary)
                .disabled(isBusy || value.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("social.addFriend.submit")
        }
        .onChange(of: value) { _, _ in errorMessage = nil }
    }

    private func submit() {
        isBusy = true
        errorMessage = nil
        let lookup: FriendLookup = byUsername ? .username(value) : .inviteCode(value)
        Task {
            defer { isBusy = false }
            do {
                try await social.sendFriendRequest(lookup)
                dismiss()
            } catch let error as SocialError {
                errorMessage = error.userMessage
            } catch {
                errorMessage = "Bir şeyler ters gitti. Lütfen tekrar dene."
            }
        }
    }
}
