import SwiftUI

/// Sayfalara yerleşen "müzik widget'ı" kontrolleri: kapak, parça adı, sanatçı ve önceki / oynat-duraklat / sonraki.
/// `.stacked` yan sütun içindir (dikey: büyük kapak üstte), `.row` alt şerit içindir (kapak solda, metin ve
/// düğmeler sağda). Kimlikler `immersive.musicWidget`, `.title`, `.artist`, `.previous`, `.playPause`, `.next`.
public struct NowPlayingPanel: View {
    public enum Style: Equatable, Sendable {
        case stacked
        case row
    }

    private let info: NowPlayingInfo
    private let errorMessage: String?
    private let style: Style
    private let onPrevious: () -> Void
    private let onPlayPause: () -> Void
    private let onNext: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let identifierPrefix = "immersive.musicWidget"
    static let rowArtworkSize: CGFloat = 76

    public init(
        info: NowPlayingInfo, errorMessage: String?, style: Style,
        onPrevious: @escaping () -> Void, onPlayPause: @escaping () -> Void, onNext: @escaping () -> Void
    ) {
        self.info = info
        self.errorMessage = errorMessage
        self.style = style
        self.onPrevious = onPrevious
        self.onPlayPause = onPlayPause
        self.onNext = onNext
    }

    public var body: some View {
        Group {
            switch style {
            case .stacked: stacked
            case .row: row
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: info)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(Self.identifierPrefix)
    }

    // MARK: Düzenler

    private var stacked: some View {
        VStack(spacing: FokusSpacing.md) {
            artwork(cornerRadius: FokusRadius.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: FokusSpacing.xs) {
                title(font: .title3.weight(.semibold), lines: 2, alignment: .center)
                artist(font: .subheadline)
            }
            .frame(maxWidth: .infinity)
            NowPlayingTransport(
                isPaused: info.isPaused, identifierPrefix: Self.identifierPrefix, playDiameter: 60,
                spacing: FokusSpacing.lg, onPrevious: onPrevious, onPlayPause: onPlayPause, onNext: onNext)
            error(alignment: .center)
        }
    }

    private var row: some View {
        HStack(spacing: FokusSpacing.lg) {
            artwork(cornerRadius: FokusRadius.md)
                .frame(width: Self.rowArtworkSize, height: Self.rowArtworkSize)
            VStack(alignment: .leading, spacing: FokusSpacing.xs) {
                title(font: .headline, lines: 1, alignment: .leading)
                artist(font: .footnote)
                NowPlayingTransport(
                    isPaused: info.isPaused, identifierPrefix: Self.identifierPrefix, playDiameter: 48,
                    spacing: FokusSpacing.md, onPrevious: onPrevious, onPlayPause: onPlayPause, onNext: onNext)
                error(alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Parçalar

    /// Duraklatılınca kapak hafifçe küçülür (Apple Müzik gibi); parça değişince çapraz solar.
    private func artwork(cornerRadius: CGFloat) -> some View {
        NowPlayingArtwork(data: info.artworkData, cornerRadius: cornerRadius)
            .scaleEffect(info.isPaused && !reduceMotion ? 0.9 : 1)
            .shadow(color: .black.opacity(info.isPaused ? 0.1 : 0.3), radius: info.isPaused ? 4 : 14, y: 6)
            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7), value: info.isPaused)
    }

    private func title(font: Font, lines: Int, alignment: TextAlignment) -> some View {
        Text(info.title)
            .font(font)
            .foregroundStyle(.fkLabel)
            .lineLimit(lines)
            .multilineTextAlignment(alignment)
            .contentTransition(.opacity)
            .accessibilityIdentifier("\(Self.identifierPrefix).title")
    }

    private func artist(font: Font) -> some View {
        Text(info.artist)
            .font(font)
            .foregroundStyle(.fkSecondaryLabel)
            .lineLimit(1)
            .contentTransition(.opacity)
            .accessibilityIdentifier("\(Self.identifierPrefix).artist")
    }

    @ViewBuilder private func error(alignment: TextAlignment) -> some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.fkDanger)
                .multilineTextAlignment(alignment)
                .transition(.opacity)
        }
    }
}

#Preview("NowPlayingPanel") {
    HStack(spacing: FokusSpacing.xl) {
        NowPlayingPanel(
            info: NowPlayingInfo(title: "Gece Mesaisi", artist: "Sanatçı"), errorMessage: nil, style: .stacked,
            onPrevious: {}, onPlayPause: {}, onNext: {}
        )
        .frame(width: 280, height: 380)
        NowPlayingPanel(
            info: NowPlayingInfo(title: "Duraklatılmış parça", artist: "Sanatçı", isPaused: true), errorMessage: nil,
            style: .row, onPrevious: {}, onPlayPause: {}, onNext: {}
        )
        .frame(width: 340)
    }
    .padding()
    .background(.fkBackground)
    .fokusTheme()
    .preferredColorScheme(.dark)
}
