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

/// Davet koduyla bir odaya katıl.
struct SocialJoinRoomSheet: View {
    let social: any SocialService

    var body: some View {
        SocialSheetScaffold(
            title: "Kodla katıl", description: "Odanın 6 karakterlik davet kodunu gir.",
            identifier: "social.joinRoom"
        ) {
            SocialSingleFieldForm(
                label: "Oda davet kodu", initialValue: "", submitLabel: "Katıl", placeholder: "K7M2QX",
                capitalization: .characters, fieldIdentifier: "social.joinCode.field",
                submitIdentifier: "social.joinCode.submit"
            ) { code in try await social.joinRoom(.inviteCode(code)) }
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
            } catch let error as SocialError {
                errorMessage = error.userMessage
            } catch {
                errorMessage = "Bir şeyler ters gitti. Lütfen tekrar dene."
            }
        }
    }
}
