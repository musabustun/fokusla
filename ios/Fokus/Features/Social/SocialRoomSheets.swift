import FokusData
import FokusDesign
import SwiftUI

/// Yeni paralel odak odası.
struct SocialCreateRoomSheet: View {
    let social: any SocialService

    var body: some View {
        SocialSheetScaffold(
            title: "Oda oluştur",
            description: "Arkadaşların odana katılır; herkes kendi kronometresiyle çalışır, durumlar canlı görünür.",
            identifier: "social.createRoom"
        ) {
            SocialSingleFieldForm(
                label: "Oda adı", initialValue: "Birlikte çalışalım", submitLabel: "Oluştur",
                fieldIdentifier: "social.room.name", submitIdentifier: "social.room.submit",
                maxLength: socialRoomNameMaxLength
            ) { name in try await social.createRoom(name: name) }
        }
    }
}

/// Bağlantıyla bir odaya katıl.
struct SocialJoinRoomSheet: View {
    let social: any SocialService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SocialSheetScaffold(title: "Bağlantıyla katıl", description: nil, identifier: "social.joinRoom") {
            SocialPasteInviteForm(social: social) { dismiss() }
        }
    }
}

/// Oda davetini paylaş: bağlantısı olan herkes katılabilir.
struct SocialRoomShareSheet: View {
    let name: String
    let url: URL

    var body: some View {
        SocialSheetScaffold(
            title: "Odaya davet et",
            description: "Bağlantısı olan herkes katılabilir (en çok 20 kişi). Odadakiler birbirini kullanıcı adı ve odak durumuyla görür. Açan kişi iOS'un davet ekranında iCloud adını görebilir.",
            identifier: "social.roomShare", cancelTitle: "Kapat"
        ) {
            SocialShareBlock(url: url, message: "Fokus'ta “\(name)” odasına katıl", identifier: "social.room.invite")
        }
    }
}

/// Tek alanlı form: gönder → hata göster ya da kapat.
private struct SocialSingleFieldForm<Result>: View {
    let label: String
    let initialValue: String
    let submitLabel: String
    var placeholder: String = ""
    var capitalization: TextInputAutocapitalization = .sentences
    let fieldIdentifier: String
    let submitIdentifier: String
    var maxLength: Int?
    let onSubmit: (String) async throws -> Result

    @Environment(\.dismiss) private var dismiss
    @State private var value: String
    @State private var isBusy = false
    @State private var errorMessage: String?

    init(
        label: String, initialValue: String, submitLabel: String, placeholder: String = "",
        capitalization: TextInputAutocapitalization = .sentences, fieldIdentifier: String,
        submitIdentifier: String, maxLength: Int? = nil,
        onSubmit: @escaping (String) async throws -> Result
    ) {
        self.label = label
        self.initialValue = initialValue
        self.submitLabel = submitLabel
        self.placeholder = placeholder
        self.capitalization = capitalization
        self.fieldIdentifier = fieldIdentifier
        self.submitIdentifier = submitIdentifier
        self.maxLength = maxLength
        self.onSubmit = onSubmit
        _value = State(initialValue: initialValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.lg) {
            SocialTextField(
                label: label, text: $value, placeholder: placeholder, error: errorMessage,
                capitalization: capitalization, identifier: fieldIdentifier,
                onSubmit: { if !value.trimmingCharacters(in: .whitespaces).isEmpty { submit() } })
            Button(submitLabel, action: submit)
                .buttonStyle(.fokusPrimary)
                .disabled(isBusy || value.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier(submitIdentifier)
        }
        .onChange(of: value) { _, newValue in
            errorMessage = nil
            if let maxLength, newValue.count > maxLength { value = String(newValue.prefix(maxLength)) }
        }
    }

    private func submit() {
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do {
                _ = try await onSubmit(value)
                dismiss()
            } catch {
                errorMessage = SocialError.message(for: error)
            }
        }
    }
}
