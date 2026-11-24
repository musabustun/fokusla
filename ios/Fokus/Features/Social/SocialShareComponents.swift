import CoreImage.CIFilterBuiltins
import FokusData
import FokusDesign
import SwiftUI
import UIKit

/// Davet bağlantısı: QR + paylaş + kopyala.
struct SocialShareBlock: View {
    let url: URL
    let message: String
    let identifier: String

    var body: some View {
        VStack(spacing: FokusSpacing.md) {
            SocialQRCode(url: url)
                .frame(maxWidth: .infinity)
            HStack(spacing: FokusSpacing.sm) {
                ShareLink(item: url, message: Text(message)) {
                    Label("Paylaş", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SocialChipButtonStyle())
                .accessibilityIdentifier("\(identifier).share")
                SocialCopyButton(
                    text: url.absoluteString, accessibilityLabel: "Davet bağlantısını kopyala",
                    identifier: "\(identifier).copy")
            }
        }
        .socialContainer(identifier)
    }
}

/// Taranabilirlik için her temada açık zeminde siyah QR.
private struct SocialQRCode: View {
    let url: URL
    private static let side: CGFloat = 180

    var body: some View {
        if let image = Self.render(url) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: Self.side, height: Self.side)
                .clipShape(RoundedRectangle(cornerRadius: FokusRadius.sm))
                .accessibilityLabel("Davet QR kodu")
                .accessibilityHint("Arkadaşın kamerasıyla okutabilir")
        }
    }

    private static let scale: CGFloat = 8
    /// QR standardı: çevrede en az 4 modül boşluk.
    private static let quietModules: CGFloat = 4

    private static func render(_ url: URL) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let code = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else { return nil }
        let frame = code.extent.insetBy(dx: -quietModules * scale, dy: -quietModules * scale)
        let output = code.composited(over: CIImage(color: .white).cropped(to: frame))
        guard let image = CIContext().createCGImage(output, from: frame) else { return nil }
        return UIImage(cgImage: image)
    }
}

/// Yapıştırılan davet bağlantısını kabul eder (arkadaşlık ya da oda).
struct SocialPasteInviteForm: View {
    let social: any SocialService
    let onDone: () -> Void

    @State private var value = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.lg) {
            SocialTextField(
                label: "Davet bağlantısı", text: $value, placeholder: "https://www.icloud.com/share/…",
                hint: "Sana gönderilen bağlantıya dokunman yeterli; açılmazsa buraya yapıştır.", error: errorMessage,
                identifier: "social.pasteInvite.field", onSubmit: submit)
            Button("Katıl", action: submit)
                .buttonStyle(.fokusSecondary)
                .disabled(isBusy || value.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("social.pasteInvite.submit")
        }
        .onChange(of: value) { _, _ in errorMessage = nil }
    }

    private func submit() {
        guard let invite = SocialInvite(text: value) else {
            errorMessage = SocialError(.inviteInvalid).userMessage
            return
        }
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do {
                try await social.acceptInvite(invite)
                onDone()
            } catch {
                errorMessage = SocialError.message(for: error)
            }
        }
    }
}

/// Engelle / bildir menüsü (App Store 1.2).
struct SocialSafetyMenu: View {
    private static let reportURL = URL(string: "https://github.com/musabustun/fokusla/blob/main/docs/support.md")!

    let username: String
    let onBlock: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        Menu {
            Button("Engelle", systemImage: "hand.raised", role: .destructive, action: onBlock)
            Button("Bildir", systemImage: "exclamationmark.bubble") { openURL(Self.reportURL) }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: fokusMinTapTarget, height: fokusMinTapTarget)
                .contentShape(Rectangle())
        }
        .foregroundStyle(.fkSecondaryLabel)
        .accessibilityLabel("@\(username) için diğer seçenekler")
        .accessibilityIdentifier("social.safety.\(username)")
    }
}
