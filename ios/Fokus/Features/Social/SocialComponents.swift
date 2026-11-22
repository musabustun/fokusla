import FokusDesign
import FokusDomain
import SwiftUI
import UIKit

/// Durum noktası — dekoratif; durum her zaman metinle de verilir (yalnızca renge dayanmaz).
struct PresenceDot: View {
    let state: PresenceState

    var body: some View {
        Group {
            switch state {
            case .focusing: Circle().fill(.fkSuccess)
            case .onBreak: Circle().fill(.fkTertiaryLabel)
            case .offline: Circle().strokeBorder(.fkSeparatorStrong, lineWidth: 2)
            }
        }
        .frame(width: 10, height: 10)
        .accessibilityHidden(true)
    }
}

/// Bölüm başlığı + sağda küçük eylem (web `Card` `title` + `trailing`).
struct SocialSectionHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title)
                .fokusTextStyle(.eyebrow)
                .foregroundStyle(.fkSecondaryLabel)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: FokusSpacing.sm)
            trailing
        }
    }
}

/// Satır içi küçük eylem: çizgili hap, ≥ 44pt dokunma alanı.
struct SocialChipButtonStyle: ButtonStyle {
    enum Kind { case regular, quiet, destructive }
    var kind: Kind = .regular

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(kind == .destructive ? FokusColor.fkDanger : .fkLabel)
            .padding(.horizontal, FokusSpacing.md)
            .frame(minHeight: fokusMinTapTarget)
            .overlay {
                if kind != .quiet {
                    Capsule().strokeBorder(
                        kind == .destructive ? FokusColor.fkDanger : .fkSeparatorStrong, lineWidth: 1)
                        .frame(height: 34)
                }
            }
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
            .animation(reduceMotion ? nil : FokusMotion.pressAnimation, value: configuration.isPressed)
    }
}

/// Çizgili metin alanı: üstte eyebrow etiket, altta çizgi; hata/ipucu altında.
struct SocialTextField: View {
    let label: String
    var prefix: String?
    @Binding var text: String
    var placeholder: String = ""
    var hint: String?
    var error: String?
    var capitalization: TextInputAutocapitalization = .never
    let identifier: String
    /// Klavyede "Git"e basılınca çağrılır (formu gönderir).
    var onSubmit: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.xs) {
            Text(label).fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
            HStack(spacing: FokusSpacing.xs) {
                if let prefix {
                    Text(prefix).font(.body).foregroundStyle(.fkSecondaryLabel).accessibilityHidden(true)
                }
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(onSubmit)
                    .accessibilityLabel(label)
                    .accessibilityIdentifier(identifier)
            }
            .frame(minHeight: fokusMinTapTarget)
            .overlay(alignment: .bottom) {
                Rectangle().fill(error == nil ? .fkSeparatorStrong : .fkDanger).frame(height: 1)
            }
            if let error {
                Text(error)
                    .fokusTextStyle(.footnote)
                    .foregroundStyle(.fkDanger)
                    .accessibilityIdentifier("\(identifier).error")
            } else if let hint {
                Text(hint).fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
            }
        }
    }
}

/// Hata satırı (kırmızı, ekran okuyucuya duyurulur).
struct SocialErrorText: View {
    let message: String
    let identifier: String

    var body: some View {
        Text(message)
            .fokusTextStyle(.subheadline)
            .foregroundStyle(.fkDanger)
            .accessibilityIdentifier(identifier)
    }
}

/// Davet kodunu panoya kopyalar; kısa süre "Kopyalandı" gösterir.
struct SocialCopyButton: View {
    let text: String
    let accessibilityLabel: String
    let identifier: String

    @State private var copied = false

    var body: some View {
        Button(copied ? "Kopyalandı" : "Kopyala") {
            UIPasteboard.general.string = text
            copied = true
            UIAccessibility.post(notification: .announcement, argument: "Panoya kopyalandı")
            Task {
                try? await Task.sleep(for: .seconds(2))
                copied = false
            }
        }
        .buttonStyle(SocialChipButtonStyle(kind: .quiet))
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(identifier)
    }
}

extension UsernameProblem {
    /// Web `USERNAME_PROBLEM_MESSAGES`.
    var message: String {
        switch self {
        case .tooShort: "En az 3 karakter olmalı."
        case .tooLong: "En fazla 20 karakter olabilir."
        case .invalidChars: "Yalnızca küçük harf (a–z), rakam, nokta ve alt çizgi kullan."
        case .mustStartWithLetter: "Bir harfle başlamalı."
        }
    }
}

/// Sayfa (sheet) iskeleti: gezinme çubuğunda başlık + "Vazgeç"; içerik kaydırılabilir.
struct SocialSheetScaffold<Content: View>: View {
    let title: String
    let description: String?
    let identifier: String
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FokusSpacing.lg) {
                    if let description {
                        Text(description).fokusTextStyle(.callout).foregroundStyle(.fkSecondaryLabel)
                    }
                    content
                }
                .padding(.horizontal, FokusSpacing.screenHorizontal)
                .padding(.vertical, FokusSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.fkBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }.accessibilityIdentifier("\(identifier).cancel")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .socialContainer(identifier)
    }
}

extension SocialFormat {
    /// Oda davet metni (paylaşma sayfası).
    static func roomInviteMessage(code: String, name: String) -> String {
        "Fokus'ta “\(name)” odasına katıl: davet kodu \(code)"
    }
}

extension View {
    /// Kapsayıcıya tanımlayıcı verir; çocukların kendi tanımlayıcıları (UI testleri) korunur.
    func socialContainer(_ identifier: String) -> some View {
        accessibilityElement(children: .contain).accessibilityIdentifier(identifier)
    }
}
