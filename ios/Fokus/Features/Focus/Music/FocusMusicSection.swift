import FokusAudio
import FokusDesign
import SwiftUI
import UIKit

/// Tam ekran odağın "ses" sayfasındaki müzik bloğu. Sağlayıcıya özgü kod bilmez: yalnızca
/// `MusicProvider` sözleşmesini okur. Sağlayıcı yoksa hiçbir şey çizmez.
struct FocusMusicSection: View {
    let registry: MusicProviderRegistry

    var body: some View {
        if let provider = registry.provider(.spotify) {
            MusicProviderBlock(provider: provider)
        }
    }
}

/// Tek sağlayıcının bloğu; `availability`/`connectionState` değişince `MusicSectionMode`'a göre yeniden çizilir.
private struct MusicProviderBlock: View {
    let provider: any MusicProvider

    private var mode: MusicSectionMode {
        .mode(availability: provider.availability, connection: provider.connectionState)
    }

    var body: some View {
        LineSection("Müzik") {
            Group {
                switch mode {
                case .openLink: MusicOpenLinkView(provider: provider)
                case .connect: MusicConnectView(provider: provider)
                case .controls: MusicControlsView(provider: provider)
                }
            }
            .padding(.vertical, FokusSpacing.lg)
        }
    }
}

// MARK: - Uygulamayı aç

private struct MusicOpenLinkView: View {
    let provider: any MusicProvider
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.md) {
            Text("Odak müziğini \(provider.displayName) uygulamasında aç; Fokus'a dönüp çalışmaya devam et.")
                .fokusTextStyle(.subheadline)
                .foregroundStyle(.fkSecondaryLabel)
            Button("\(provider.displayName)'da aç", action: open)
                .buttonStyle(.fokusSecondary)
                .accessibilityIdentifier("music.spotify.open")
        }
    }

    /// Uygulama yüklüyse doğrudan uygulamayı, değilse (ya da sistem reddederse) web bağlantısını açar.
    private func open() {
        guard provider.availability != .appNotInstalled else {
            openURL(provider.webURL)
            return
        }
        let webURL = provider.webURL
        openURL(provider.appURL) { accepted in
            if !accepted { openURL(webURL) }
        }
    }
}

// MARK: - Bağlan

private struct MusicConnectView: View {
    let provider: any MusicProvider

    private var isConnecting: Bool { provider.connectionState == .connecting }

    private var failure: MusicProviderError? {
        if case .failed(let error) = provider.connectionState { return error }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.md) {
            Text("Odaklanırken \(provider.displayName) müziğini buradan denetle.")
                .fokusTextStyle(.subheadline)
                .foregroundStyle(.fkSecondaryLabel)
            Button {
                provider.connect()
            } label: {
                HStack(spacing: FokusSpacing.sm) {
                    if isConnecting { ProgressView() }
                    Text(buttonTitle)
                }
            }
            .buttonStyle(.fokusPrimary)
            .disabled(isConnecting)
            .accessibilityIdentifier("music.spotify.connect")
            if let failure {
                Text(failure.userMessage)
                    .fokusTextStyle(.footnote)
                    .foregroundStyle(.fkDanger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("music.spotify.error")
            }
            Text("\(provider.displayName) uygulaması gerekir; çalmayı denetlemek Premium gerektirebilir.")
                .fokusTextStyle(.footnote)
                .foregroundStyle(.fkTertiaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var buttonTitle: String {
        if isConnecting { return "Bağlanıyor…" }
        return failure == nil ? "\(provider.displayName)'a bağlan" : "Tekrar dene"
    }
}

// MARK: - Kontroller

private struct MusicControlsView: View {
    let provider: any MusicProvider

    private var track: MusicTrack? { provider.nowPlaying }

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.lg) {
            nowPlayingRow
            transportRow
            if let error = provider.lastCommandError {
                Text(error.userMessage)
                    .fokusTextStyle(.footnote)
                    .foregroundStyle(.fkDanger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("music.spotify.error")
            }
            Button("Bağlantıyı kes") { provider.disconnect() }
                .buttonStyle(.fokusPlain)
                .accessibilityIdentifier("music.spotify.disconnect")
        }
    }

    private var nowPlayingRow: some View {
        HStack(spacing: FokusSpacing.md) {
            MusicArtworkView(data: track?.artworkData)
            VStack(alignment: .leading, spacing: 2) {
                Text(track?.title ?? "\(provider.displayName) bağlı")
                    .fokusTextStyle(.headline)
                    .foregroundStyle(.fkLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(track?.artist ?? "Çalmak için \(provider.displayName) uygulamasında bir şey başlat.")
                    .fokusTextStyle(.subheadline)
                    .foregroundStyle(.fkSecondaryLabel)
                    .lineLimit(track == nil ? 2 : 1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(nowPlayingLabel)
        .accessibilityIdentifier("music.spotify.nowPlaying")
    }

    private var nowPlayingLabel: String {
        guard let track else { return "\(provider.displayName) bağlı, çalan parça yok" }
        return "\(track.isPaused ? "Duraklatıldı" : "Çalıyor"): \(track.title), \(track.artist)"
    }

    private var isPlaying: Bool { track?.isPaused == false }

    private var transportRow: some View {
        HStack(spacing: FokusSpacing.xl) {
            Spacer(minLength: 0)
            transportButton("backward.fill", label: "Önceki parça", id: "previous") {
                provider.skipToPrevious()
            }
            Button {
                provider.togglePlayPause()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.fkAccentContrast)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(.fkAccent))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Duraklat" : "Çal")
            .accessibilityIdentifier("music.spotify.playPause")
            transportButton("forward.fill", label: "Sonraki parça", id: "next") {
                provider.skipToNext()
            }
            Spacer(minLength: 0)
        }
    }

    private func transportButton(
        _ symbol: String, label: String, id: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.fkLabel)
                .frame(minWidth: fokusMinTapTarget, minHeight: fokusMinTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("music.spotify.\(id)")
    }
}

/// Kapak görseli; yoksa nötr zemin üstünde nota simgesi. Görsel çözme gövdeden ayrı, veri değişince yapılır.
private struct MusicArtworkView: View {
    let data: Data?
    @State private var image: UIImage?

    private let side: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: FokusRadius.md, style: .continuous).fill(.fkFill)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "music.note").font(.title2).foregroundStyle(.fkSecondaryLabel)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: FokusRadius.md, style: .continuous))
        .accessibilityHidden(true)
        .task(id: data) { image = data.flatMap(UIImage.init(data:)) }
    }
}

#if DEBUG
#Preview("Müzik — bağlan (koyu)") {
    MusicPreviewCanvas(.dark, .disconnected)
}

#Preview("Müzik — bağlan, hata (açık)") {
    MusicPreviewCanvas(.light, .failed)
}

#Preview("Müzik — kontroller (koyu)") {
    MusicPreviewCanvas(.dark, .connected)
}

#Preview("Müzik — kontroller (açık)") {
    MusicPreviewCanvas(.light, .connected)
}

#Preview("Müzik — Spotify'da aç (açık)") {
    MusicPreviewCanvas(.light, .notInstalled)
}

private struct MusicPreviewCanvas: View {
    let scheme: ColorScheme
    @State private var registry: MusicProviderRegistry

    init(_ scheme: ColorScheme, _ preset: FakeMusicProvider.Preset) {
        self.scheme = scheme
        _registry = State(initialValue: MusicProviderRegistry(providers: [FakeMusicProvider(preset)]))
    }

    var body: some View {
        FocusMusicSection(registry: registry)
            .padding(FokusSpacing.screenHorizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.fkBackground)
            .fokusTheme()
            .preferredColorScheme(scheme)
    }
}
#endif
