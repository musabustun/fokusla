import SwiftUI

/// Şimdi çalan parçanın görünüm girdisi (değer tipi; müzik sağlayıcısından uygulama doldurur).
public struct NowPlayingInfo: Equatable, Sendable {
    public var title: String
    public var artist: String
    /// Kapak görseli verisi (PNG/JPEG); yoksa nota yer tutucusu çizilir.
    public var artworkData: Data?
    public var isPaused: Bool

    public init(title: String, artist: String, artworkData: Data? = nil, isPaused: Bool = false) {
        self.title = title
        self.artist = artist
        self.artworkData = artworkData
        self.isPaused = isPaused
    }
}

/// Kapak görseli: veriden çözülür, yoksa vurgu tonlu nota yer tutucusu. Dekoratiftir.
struct NowPlayingArtwork: View {
    let data: Data?
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            Color.clear.overlay { placeholder }
            if let image = Self.image(from: data) {
                image.resizable().scaledToFill()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(.fkAccentSubtle)
            Image(systemName: "music.note")
                .font(.largeTitle)
                .foregroundStyle(.fkAccentInk)
        }
    }

    static func image(from data: Data?) -> Image? {
        guard let data else { return nil }
        #if canImport(UIKit)
        return UIImage(data: data).map { Image(uiImage: $0) }
        #elseif canImport(AppKit)
        return NSImage(data: data).map { Image(nsImage: $0) }
        #else
        return nil
        #endif
    }
}

/// Tam ekran "StandBy" müzik kartı: büyük kapak, parça adı, sanatçı ve önceki / oynat-duraklat / sonraki
/// düğmeleri. Geniş alanda (genişlik > yükseklik × 1.15) kapak solda, bilgi ve düğmeler sağda; aksi halde dikey.
public struct NowPlayingCard: View {
    private let info: NowPlayingInfo
    private let errorMessage: String?
    private let onPrevious: () -> Void
    private let onPlayPause: () -> Void
    private let onNext: () -> Void

    /// Yatay düzene geçiş oranı.
    nonisolated static let wideAspectThreshold: CGFloat = 1.15

    public init(
        info: NowPlayingInfo, errorMessage: String?,
        onPrevious: @escaping () -> Void, onPlayPause: @escaping () -> Void, onNext: @escaping () -> Void
    ) {
        self.info = info
        self.errorMessage = errorMessage
        self.onPrevious = onPrevious
        self.onPlayPause = onPlayPause
        self.onNext = onNext
    }

    public var body: some View {
        GeometryReader { proxy in
            let isWide = Self.isWide(width: proxy.size.width, height: proxy.size.height)
            Group {
                if isWide {
                    HStack(spacing: FokusSpacing.xxl) {
                        artwork.frame(maxWidth: proxy.size.height)
                        details(alignment: .leading)
                    }
                } else {
                    VStack(spacing: FokusSpacing.xl) {
                        artwork.frame(maxWidth: proxy.size.width)
                        details(alignment: .center)
                    }
                }
            }
            .padding(FokusSpacing.xl)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("immersive.nowPlaying")
    }

    /// Yatay (kapak solda) düzen mi? Saf; test edilebilir.
    nonisolated public static func isWide(width: CGFloat, height: CGFloat) -> Bool {
        width > height * wideAspectThreshold
    }

    private var artwork: some View {
        NowPlayingArtwork(data: info.artworkData, cornerRadius: FokusRadius.lg)
    }

    private func details(alignment: HorizontalAlignment) -> some View {
        let textAlignment: TextAlignment = alignment == .leading ? .leading : .center
        return VStack(alignment: alignment, spacing: FokusSpacing.md) {
            Text(info.title)
                .fokusTextStyle(.title1)
                .foregroundStyle(.fkLabel)
                .lineLimit(2)
                .multilineTextAlignment(textAlignment)
                .accessibilityIdentifier("immersive.nowPlaying.title")
            Text(info.artist)
                .font(.title3)
                .foregroundStyle(.fkSecondaryLabel)
                .lineLimit(1)
                .accessibilityIdentifier("immersive.nowPlaying.artist")
            transport.padding(.top, FokusSpacing.sm)
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.fkDanger)
                    .multilineTextAlignment(textAlignment)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
    }

    private var transport: some View {
        HStack(spacing: FokusSpacing.xl) {
            transportButton("backward.fill", label: "Önceki parça", id: "previous", action: onPrevious)
            Button(action: onPlayPause) {
                Image(systemName: info.isPaused ? "play.fill" : "pause.fill")
                    .font(.title)
                    .foregroundStyle(.fkAccentContrast)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(.fkAccent))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(info.isPaused ? "Oynat" : "Duraklat")
            .accessibilityIdentifier("immersive.nowPlaying.playPause")
            transportButton("forward.fill", label: "Sonraki parça", id: "next", action: onNext)
        }
    }

    private func transportButton(
        _ symbol: String, label: String, id: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.fkLabel)
                .frame(width: fokusMinTapTarget + 8, height: fokusMinTapTarget + 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("immersive.nowPlaying.\(id)")
    }
}

#Preview("NowPlayingCard") {
    NowPlayingCard(
        info: NowPlayingInfo(title: "Gece Mesaisi İçin Uzun Bir Parça Adı", artist: "Sanatçı", isPaused: false),
        errorMessage: nil, onPrevious: {}, onPlayPause: {}, onNext: {}
    )
    .background(.fkBackground)
    .fokusTheme()
    .preferredColorScheme(.dark)
}
