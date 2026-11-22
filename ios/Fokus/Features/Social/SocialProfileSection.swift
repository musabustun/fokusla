import FokusData
import FokusDesign
import FokusDomain
import SwiftUI

/// Kullanıcı adı, davet kodu ve "Sosyalde görün" anahtarı (web `ProfileSection`).
struct SocialProfileSection: View {
    let social: any SocialService
    let profile: SocialProfile

    @Environment(\.fokusPalette) private var palette
    @State private var isRenaming = false
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
                VStack(spacing: 0) {
                    HStack(spacing: FokusSpacing.xs) {
                        Text("Davet kodu").fokusTextStyle(.body).foregroundStyle(.fkLabel).lineLimit(1)
                        Spacer(minLength: FokusSpacing.sm)
                        Text(profile.inviteCode)
                            .fokusTextStyle(.numeralSM)
                            .tracking(2)
                            .foregroundStyle(.fkLabel)
                            .lineLimit(1)
                            .fixedSize()
                            .accessibilityLabel("Davet kodu \(profile.inviteCode.map(String.init).joined(separator: " "))")
                            .accessibilityIdentifier("social.profile.inviteCode")
                        SocialCopyButton(
                            text: profile.inviteCode, accessibilityLabel: "Davet kodunu kopyala",
                            identifier: "social.profile.copyCode")
                        ShareLink(item: SocialFormat.inviteMessage(code: profile.inviteCode)) {
                            Image(systemName: "square.and.arrow.up")
                                .frame(width: fokusMinTapTarget, height: fokusMinTapTarget)
                        }
                        .accessibilityLabel("Davet kodunu paylaş")
                        .accessibilityIdentifier("social.profile.shareCode")
                    }
                    .frame(minHeight: fokusMinTapTarget)
                    .padding(.vertical, FokusSpacing.xs)
                    Divider().overlay(.fkSeparator)
                }
                LineRow("Sosyalde görün") {
                    Toggle("Sosyalde görün", isOn: discoverable)
                        .labelsHidden()
                        .tint(FokusColor.color(.accent, palette: palette))
                        .accessibilityIdentifier("social.profile.discoverable")
                }
            }
            Text(footer).fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
            if let visibilityError {
                SocialErrorText(message: visibilityError, identifier: "social.profile.error")
            }
        }
        .sheet(isPresented: $isRenaming) {
            SocialSheetScaffold(
                title: "Kullanıcı adını değiştir",
                description: "Arkadaşların yeni adını görür; eski adın başkası tarafından alınabilir.",
                identifier: "social.renameSheet"
            ) {
                SocialUsernameForm(
                    social: social, initialValue: profile.username, submitLabel: "Kaydet"
                ) { isRenaming = false }
            }
        }
        .socialContainer("social.profile")
    }

    private var footer: String {
        "Paylaşılan tek bilgi kullanıcı adın ve çalışma durumun/sürendir."
            + (profile.isDiscoverable
                ? ""
                : " Şu an gizlisin: arkadaşların seni çevrimdışı görür ve kullanıcı adınla aranamazsın; davet kodun çalışmaya devam eder.")
    }

    private var discoverable: Binding<Bool> {
        Binding(
            get: { profile.isDiscoverable },
            set: { newValue in
                visibilityError = nil
                Task {
                    do { try await social.setDiscoverable(newValue) } catch let error as SocialError {
                        visibilityError = error.userMessage
                    } catch {
                        visibilityError = "Bir şeyler ters gitti. Lütfen tekrar dene."
                    }
                }
            }
        )
    }
}
