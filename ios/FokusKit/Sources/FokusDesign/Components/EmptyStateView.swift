import SwiftUI

/// Boş/henüz hazır olmayan içerik (web `EmptyState`): ince çizgili daire içinde ikon, Bricolage
/// başlık, ikincil mesaj ve opsiyonel eylem.
public struct EmptyStateView<Action: View>: View {
    private let systemImage: String?
    private let title: String
    private let message: String?
    private let action: Action

    public init(
        _ title: String, systemImage: String? = nil, message: String? = nil,
        @ViewBuilder action: () -> Action
    ) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.action = action()
    }

    public var body: some View {
        VStack(spacing: FokusSpacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.fkSecondaryLabel)
                    .frame(width: 64, height: 64)
                    .overlay(Circle().strokeBorder(.fkSeparator, lineWidth: 1))
                    .padding(.bottom, FokusSpacing.md)
                    .accessibilityHidden(true)
            }
            Text(title)
                .fokusTextStyle(.title3)
                .foregroundStyle(.fkLabel)
                .accessibilityAddTraits(.isHeader)
            if let message {
                Text(message).fokusTextStyle(.callout).foregroundStyle(.fkSecondaryLabel)
            }
            action.padding(.top, FokusSpacing.md)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 420)
        .padding(.horizontal, FokusSpacing.xl)
        .padding(.vertical, FokusSpacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

extension EmptyStateView where Action == EmptyView {
    public init(_ title: String, systemImage: String? = nil, message: String? = nil) {
        self.init(title, systemImage: systemImage, message: message) { EmptyView() }
    }
}

#Preview("EmptyStateView — koyu") {
    FokusPreviewCanvas(.dark) { EmptyPreviewContent() }
}

#Preview("EmptyStateView — açık") {
    FokusPreviewCanvas(.light) { EmptyPreviewContent() }
}

private struct EmptyPreviewContent: View {
    var body: some View {
        EmptyStateView("Henüz kitap yok", systemImage: "books.vertical", message: "İlk kitabını ekleyerek ilerlemeni takip et.") {
            Button("Kitap ekle") {}.buttonStyle(.fokusPrimary)
        }
    }
}
