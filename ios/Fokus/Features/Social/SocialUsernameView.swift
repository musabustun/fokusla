import FokusData
import FokusDesign
import FokusDomain
import SwiftUI

/// Benzersiz kullanıcı adı seçimi (ilk kurulum ve değiştirme).
struct SocialUsernameForm: View {
    let social: any SocialService
    var initialValue: String = ""
    let submitLabel: String
    var onDone: (() -> Void)?

    @State private var value: String
    @State private var touched = false
    @State private var isBusy = false
    @State private var serverError: String?

    init(social: any SocialService, initialValue: String = "", submitLabel: String, onDone: (() -> Void)? = nil) {
        self.social = social
        self.initialValue = initialValue
        self.submitLabel = submitLabel
        self.onDone = onDone
        _value = State(initialValue: initialValue)
    }

    private static let hint =
        "3–20 karakter: küçük harf (a–z), rakam, nokta ve alt çizgi. Arkadaşların seni bu adla görür; gerçek adını ya da okulunu yazma."

    private var formatError: String? {
        guard touched, case let .invalid(problem) = SocialCalc.validateUsername(value) else { return nil }
        return problem.message
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.lg) {
            SocialTextField(
                label: "Kullanıcı adı", prefix: "@", text: $value, placeholder: "ornek_ogrenci",
                hint: Self.hint, error: serverError ?? formatError, identifier: "social.username.field",
                onSubmit: submit)
            Button(submitLabel, action: submit)
                .buttonStyle(.fokusPrimary)
                .disabled(isBusy)
                .accessibilityIdentifier("social.username.submit")
        }
        .onChange(of: value) { _, _ in
            serverError = nil
            if !value.isEmpty { touched = true }
        }
    }

    private func submit() {
        touched = true
        guard case .valid = SocialCalc.validateUsername(value) else { return }
        isBusy = true
        serverError = nil
        Task {
            defer { isBusy = false }
            switch await social.checkUsername(value) {
            case let .ok(username):
                do {
                    try await social.claimUsername(username)
                    onDone?()
                } catch let error as SocialError {
                    serverError = error.userMessage
                } catch {
                    serverError = "Bir şeyler ters gitti. Lütfen tekrar dene."
                }
            case let .invalid(problem):
                serverError = problem.message
            case .taken:
                serverError = "Bu kullanıcı adı alınmış."
            }
        }
    }
}

/// İlk kurulum: giriş var ama kullanıcı adı yok.
struct SocialUsernameSetupView: View {
    let social: any SocialService

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.lg) {
            Text("Kullanıcı adını seç")
                .fokusTextStyle(.title1)
                .foregroundStyle(.fkLabel)
                .accessibilityAddTraits(.isHeader)
            Text("Arkadaşların seni yalnızca bu adla görür. Adın, e-postan ve çalışma içeriğin paylaşılmaz.")
                .fokusTextStyle(.callout)
                .foregroundStyle(.fkSecondaryLabel)
            SocialUsernameForm(social: social, submitLabel: "Devam")
        }
        .frame(maxWidth: 520, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .socialContainer("social.username")
    }
}
