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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.clear.overlay { placeholder }
            if let image = Self.image(from: data) {
                image.resizable().scaledToFill().transition(.opacity)
            }
        }
        // Parça değişince kapak çapraz solar (hareket azaltmada animasyonsuz).
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: data)
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: info)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("immersive.nowPlaying")
    }

    /// Yatay (kapak solda) düzen mi? Saf; test edilebilir.
    nonisolated public static func isWide(width: CGFloat, height: CGFloat) -> Bool {
        width > height * wideAspectThreshold
    }

    /// Duraklatılınca kapak hafifçe küçülür (Apple Müzik gibi).
    private var artwork: some View {
        NowPlayingArtwork(data: info.artworkData, cornerRadius: FokusRadius.lg)
            .scaleEffect(info.isPaused && !reduceMotion ? 0.92 : 1)
            .shadow(color: .black.opacity(info.isPaused ? 0.1 : 0.3), radius: info.isPaused ? 6 : 20, y: 8)
            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7), value: info.isPaused)
    }

    private func details(alignment: HorizontalAlignment) -> some View {
        let textAlignment: TextAlignment = alignment == .leading ? .leading : .center
        return VStack(alignment: alignment, spacing: FokusSpacing.md) {
            Text(info.title)
                .fokusTextStyle(.title1)
                .foregroundStyle(.fkLabel)
                .lineLimit(2)
                .multilineTextAlignment(textAlignment)
                .contentTransition(.opacity)
                .accessibilityIdentifier("immersive.nowPlaying.title")
            Text(info.artist)
                .font(.title3)
                .foregroundStyle(.fkSecondaryLabel)
                .lineLimit(1)
                .contentTransition(.opacity)
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
        NowPlayingTransport(
            isPaused: info.isPaused, identifierPrefix: "immersive.nowPlaying", playDiameter: 72,
            spacing: FokusSpacing.xl, onPrevious: onPrevious, onPlayPause: onPlayPause, onNext: onNext)
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
