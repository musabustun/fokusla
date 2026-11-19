import SwiftUI

/// `#Preview`'lar için ortak zemin: fontları kaydeder, Kahve paletini ve zemin rengini uygular.
struct FokusPreviewCanvas<Content: View>: View {
    private let scheme: ColorScheme
    private let content: Content

    init(_ scheme: ColorScheme, @ViewBuilder content: () -> Content) {
        FokusFonts.registerAll()
        self.scheme = scheme
        self.content = content()
    }

    var body: some View {
        content
            .padding(FokusSpacing.screenHorizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.fkBackground)
            .environment(\.fokusPalette, .kahve)
            .preferredColorScheme(scheme)
    }
}
