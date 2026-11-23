import FokusDesign
import SwiftUI

/// Müzik widget'ı seçili sayfanın iki bölgeli düzeni: yatayda solda sayfa içeriği + sağda müzik kontrolleri
/// (yan sütun), dikeyde üstte içerik + altta müzik şeridi. Böylece müzik içeriğin üstüne binmez; kontroller
/// her an dokunulabilirdir. Güvenli alanlar (Dynamic Island, ev çubuğu, yan çentikler) bağlamdan gelir.
struct ImmersiveMusicSplit<Content: View>: View {
    let context: ImmersivePageContext
    let content: (ImmersivePageContext) -> Content

    private static var hairline: CGFloat { 1 }

    var body: some View {
        GeometryReader { proxy in
            switch StandByMusicSplit.arrangement(width: proxy.size.width, height: proxy.size.height) {
            case .sideBySide: sideBySide(proxy.size)
            case .stacked: stacked(proxy.size)
            }
        }
    }

    // MARK: Yatay: içerik | müzik sütunu

    private func sideBySide(_ size: CGSize) -> some View {
        let columnWidth = StandByMusicSplit.sideColumnWidth(totalWidth: size.width)
        var left = context
        left.insets.trailing = 0
        left.isCompactColumn = true
        return HStack(spacing: 0) {
            content(left)
                .frame(width: size.width - columnWidth, height: size.height)
            musicPanel(style: .stacked)
                .padding(.leading, FokusSpacing.lg)
                .padding(.trailing, max(context.insets.trailing, FokusSpacing.xl))
                .padding(.top, max(context.insets.top, FokusSpacing.lg))
                .padding(.bottom, context.insets.bottom + context.bottomReserve)
                .frame(width: columnWidth, height: size.height)
                .overlay(alignment: .leading) {
                    Rectangle().fill(.fkSeparator).frame(width: Self.hairline)
                        .padding(.vertical, max(context.insets.top, FokusSpacing.xl))
                        .accessibilityHidden(true)
                }
        }
    }

    // MARK: Dikey: içerik / müzik şeridi

    private func stacked(_ size: CGSize) -> some View {
        let strip = StandByMusicSplit.bottomStripHeight
        let bottomPad = context.insets.bottom + context.bottomReserve
        var top = context
        top.insets.bottom = 0
        top.bottomReserve = FokusSpacing.lg
        top.isCompactColumn = true
        return VStack(spacing: 0) {
            content(top)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle().fill(.fkSeparator).frame(height: Self.hairline)
                .padding(.horizontal, max(context.insets.leading, FokusSpacing.xl))
                .accessibilityHidden(true)
            musicPanel(style: .row)
                .padding(.leading, max(context.insets.leading, FokusSpacing.xl))
                .padding(.trailing, max(context.insets.trailing, FokusSpacing.xl))
                .padding(.top, FokusSpacing.md)
                .frame(height: strip + FokusSpacing.md, alignment: .top)
                .padding(.bottom, bottomPad)
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func musicPanel(style: NowPlayingPanel.Style) -> some View {
        let music = context.music
        if let info = music.info {
            NowPlayingPanel(
                info: info, errorMessage: music.errorMessage, style: style,
                onPrevious: music.previous, onPlayPause: music.playPause, onNext: music.next)
        } else {
            Color.clear
        }
    }
}
