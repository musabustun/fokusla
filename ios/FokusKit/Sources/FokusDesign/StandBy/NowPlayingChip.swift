import SwiftUI

/// Köşede küçük "şimdi çalıyor" çipi: küçük kapak, tek satır parça adı ve eşitleyici çubukları
/// (duraklatılmışsa duraklat simgesi). Dokununca müzik sayfasına gidilir.
public struct NowPlayingChip: View {
    private let info: NowPlayingInfo
    private let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let thumbnailSize: CGFloat = 28
    static let maxTitleWidth: CGFloat = 220

    public init(info: NowPlayingInfo, action: @escaping () -> Void) {
        self.info = info
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: FokusSpacing.sm) {
                NowPlayingArtwork(data: info.artworkData, cornerRadius: FokusRadius.sm)
                    .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
                Text(info.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.fkLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: Self.maxTitleWidth, alignment: .leading)
                indicator
            }
            .padding(.leading, FokusSpacing.sm)
            .padding(.trailing, FokusSpacing.md)
            .frame(minHeight: fokusMinTapTarget)
            .background(Capsule().fill(.fkBackground.opacity(0.7)))
            .overlay(Capsule().strokeBorder(.fkSeparator, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Şimdi çalıyor: \(info.title), \(info.artist)")
        .accessibilityHint("Müzik sayfasını açar")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("immersive.nowPlayingChip")
    }

    @ViewBuilder private var indicator: some View {
        if info.isPaused {
            Image(systemName: "pause.fill")
                .font(.caption2)
                .foregroundStyle(.fkSecondaryLabel)
        } else {
            EqualizerBars(isAnimating: !reduceMotion)
        }
    }
}

/// Üç çubuklu küçük eşitleyici; `isAnimating == false` iken durağan.
struct EqualizerBars: View {
    let isAnimating: Bool

    private static let phases: [Double] = [0, 1.3, 2.6]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !isAnimating)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(Self.phases.enumerated()), id: \.offset) { _, phase in
                    Capsule()
                        .fill(.fkAccent)
                        .frame(width: 3, height: height(time: time, phase: phase))
                }
            }
            .frame(width: 13, height: 14, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }

    private func height(time: Double, phase: Double) -> CGFloat {
        guard isAnimating else { return 8 }
        return 4 + 10 * CGFloat((sin(time * 5 + phase) + 1) / 2)
    }
}

#Preview("NowPlayingChip") {
    VStack(spacing: FokusSpacing.lg) {
        NowPlayingChip(info: NowPlayingInfo(title: "Gece Mesaisi", artist: "Sanatçı"), action: {})
        NowPlayingChip(info: NowPlayingInfo(title: "Duraklatılmış", artist: "Sanatçı", isPaused: true), action: {})
    }
    .padding()
    .background(.fkBackground)
    .fokusTheme()
    .preferredColorScheme(.dark)
}
