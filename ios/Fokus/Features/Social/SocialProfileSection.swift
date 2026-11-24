import FokusData
import FokusDesign
import FokusDomain
import SwiftUI

/// Kullanıcı adı, "Sosyalde görün" anahtarı ve sosyal profili silme.
struct SocialProfileSection: View {
    let social: any SocialService
    let profile: SocialProfile

    @Environment(\.fokusPalette) private var palette
    @State private var isRenaming = false
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var visibilityError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.sm) {
            Text("Profil").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                Divider().overlay(.fkSeparator)
                Button { isRenaming = true } label: {
                    LineRow("Kullanıcı adı", value: "@\(profile.username)", showsChevron: true)
                }
                .buttonStyle(.fokusRow)
                .accessibilityIdentifier("social.profile.rename")
                LineRow("Sosyalde görün") {
                    Toggle("Sosyalde görün", isOn: discoverable)
                        .labelsHidden()
                        .tint(FokusColor.color(.accent, palette: palette))
                        .accessibilityIdentifier("social.profile.discoverable")
                }
                Button { isConfirmingDelete = true } label: {
                    LineRow("Sosyal profilimi sil", showsChevron: true)
                }
                .buttonStyle(.fokusRow)
                .disabled(isDeleting)
                .accessibilityIdentifier("social.profile.delete")
            }
            Text(footer).fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
            if let visibilityError {
                SocialErrorText(message: visibilityError, identifier: "social.profile.error")
            }
        }
        .sheet(isPresented: $isRenaming) {
            SocialSheetScaffold(
                title: "Kullanıcı adını değiştir",
                description: "Arkadaşların yeni adını görür; eski adını başkası alabilir.",
                identifier: "social.renameSheet"
            ) {
                SocialUsernameForm(
                    social: social, initialValue: profile.username, submitLabel: "Kaydet"
                ) { isRenaming = false }
            }
        }
        .confirmationDialog(
            "Sosyal profilin silinsin mi?", isPresented: $isConfirmingDelete, titleVisibility: .visible
        ) {
            Button("Kalıcı olarak sil", role: .destructive, action: deleteProfile)
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Kullanıcı adın, arkadaşlıkların, isteklerin ve odan silinir; geri alınamaz. Çalışma verilerin cihazında kalır.")
        }
        .socialContainer("social.profile")
    }

    private func deleteProfile() {
        isDeleting = true
        visibilityError = nil
        Task {
            defer { isDeleting = false }
            do { try await social.deleteAccount() } catch { visibilityError = SocialError.message(for: error) }
        }
    }

    private var footer: String {
        "Kabul ettiğin kişilerle paylaşılan tek bilgi kullanıcı adın ve çalışma durumun/sürendir."
            + (profile.isDiscoverable
                ? ""
                : " Şu an gizlisin: arkadaşların durumunu görmez ve kullanıcı adına istek gelmez; davet bağlantıların çalışmaya devam eder.")
    }

    private var discoverable: Binding<Bool> {
        Binding(
            get: { profile.isDiscoverable },
            set: { newValue in
                visibilityError = nil
                Task {
                    do { try await social.setDiscoverable(newValue) } catch {
                        visibilityError = SocialError.message(for: error)
                    }
                }
            }
        )
    }
}
