import SwiftUI

/// Köşedeki "şimdi çalıyor" çipi: dokununca AYRI EKRANA GİTMEDEN yerinde kontrol kartına genişler (kapak büyür,
/// parça adı/sanatçı ve önceki / oynat-duraklat / sonraki açılır); başlığa dokununca yine çipe daralır.
/// Geçiş `matchedGeometryEffect` + yay animasyonudur; `accessibilityReduceMotion` açıksa yalnızca opaklık.
/// Açık/kapalı durumu dışarıdadır (otomatik daralma, dışa dokunma gibi davranışları uygulama yönetir).
public struct NowPlayingExpandableChip: View {
    private let info: NowPlayingInfo
    private let errorMessage: String?
    @Binding private var isExpanded: Bool
    private let onPrevious: () -> Void
    private let onPlayPause: () -> Void
    private let onNext: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    static let thumbnailSize: CGFloat = 28
    static let expandedArtworkSize: CGFloat = 56
    static let maxTitleWidth: CGFloat = 220
    static let expandedWidth: CGFloat = 340
    static let collapsedCorner: CGFloat = fokusMinTapTarget / 2

    /// Yay animasyonu (hareket azaltmada `nil`).
    static let spring = Animation.spring(response: 0.46, dampingFraction: 0.82)

    public init(
        info: NowPlayingInfo, errorMessage: String?, isExpanded: Binding<Bool>,
        onPrevious: @escaping () -> Void, onPlayPause: @escaping () -> Void, onNext: @escaping () -> Void
    ) {
        self.info = info
        self.errorMessage = errorMessage
        _isExpanded = isExpanded
        self.onPrevious = onPrevious
        self.onPlayPause = onPlayPause
        self.onNext = onNext
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if isExpanded {
                expanded
            } else {
                collapsed
            }
        }
        .background(
            RoundedRectangle(cornerRadius: isExpanded ? FokusRadius.xl + 4 : Self.collapsedCorner, style: .continuous)
                .fill(.fkBackground.opacity(isExpanded ? 1 : 0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: isExpanded ? FokusRadius.xl + 4 : Self.collapsedCorner, style: .continuous)
                .strokeBorder(.fkSeparator, lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: isExpanded ? FokusRadius.xl + 4 : Self.collapsedCorner, style: .continuous)
        )
        .shadow(color: .black.opacity(isExpanded ? 0.28 : 0), radius: 22, y: 10)
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : Self.spring, value: isExpanded)
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: info)
    }

    // MARK: Çip (daralmış)

    private var collapsed: some View {
        Button {
            isExpanded = true
        } label: {
            HStack(spacing: FokusSpacing.sm) {
                artwork(size: Self.thumbnailSize, corner: FokusRadius.sm)
                titleText(font: .footnote.weight(.semibold), lines: 1)
                    .frame(maxWidth: Self.maxTitleWidth, alignment: .leading)
                if info.isPaused {
                    Image(systemName: "pause.fill").font(.caption2).foregroundStyle(.fkSecondaryLabel)
                } else {
                    EqualizerBars(isAnimating: !reduceMotion)
                }
            }
            .padding(.leading, FokusSpacing.sm)
            .padding(.trailing, FokusSpacing.md)
            .frame(minHeight: fokusMinTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(NowPlayingPressStyle())
        .transition(.opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Şimdi çalıyor: \(info.title), \(info.artist)")
        .accessibilityHint("Müzik kontrollerini açar")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("immersive.nowPlayingChip")
    }

    // MARK: Kontrol kartı (genişlemiş)

    private var expanded: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.md) {
            Button {
                isExpanded = false
            } label: {
                HStack(spacing: FokusSpacing.md) {
                    artwork(size: Self.expandedArtworkSize, corner: FokusRadius.md)
                    VStack(alignment: .leading, spacing: 2) {
                        titleText(font: .headline, lines: 2)
                        Text(info.artist)
                            .font(.subheadline)
                            .foregroundStyle(.fkSecondaryLabel)
                            .lineLimit(1)
                            .contentTransition(.opacity)
                    }
                    Spacer(minLength: FokusSpacing.sm)
                    Image(systemName: "chevron.up")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.fkSecondaryLabel)
                        .frame(width: fokusMinTapTarget, height: fokusMinTapTarget)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Şimdi çalıyor: \(info.title), \(info.artist)")
            .accessibilityHint("Kontrolleri kapatır")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("immersive.nowPlayingChip.collapse")

            NowPlayingTransport(
                isPaused: info.isPaused, identifierPrefix: "immersive.nowPlayingChip", playDiameter: 56,
                spacing: FokusSpacing.xl, onPrevious: onPrevious, onPlayPause: onPlayPause, onNext: onNext
            )
            .frame(maxWidth: .infinity)
            .transition(
                reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.9, anchor: .top)))

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.fkDanger).transition(.opacity)
            }
        }
        .padding(.horizontal, FokusSpacing.md)
        .padding(.vertical, FokusSpacing.sm)
        .frame(width: Self.expandedWidth)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("immersive.nowPlayingChip.expanded")
    }

    // MARK: Ortak parçalar (matchedGeometryEffect ile kapak ve başlık yer değiştirir)

    private func artwork(size: CGFloat, corner: CGFloat) -> some View {
        NowPlayingArtwork(data: info.artworkData, cornerRadius: corner)
            .frame(width: size, height: size)
            .matchedGeometryEffect(id: "artwork", in: namespace)
    }

    private func titleText(font: Font, lines: Int) -> some View {
        Text(info.title)
            .font(font)
            .foregroundStyle(.fkLabel)
            .lineLimit(lines)
            .truncationMode(.tail)
            .contentTransition(.opacity)
            .matchedGeometryEffect(id: "title", in: namespace)
    }
}

#Preview("NowPlayingExpandableChip") {
    struct Host: View {
        @State private var expanded = false
        var body: some View {
            NowPlayingExpandableChip(
                info: NowPlayingInfo(title: "Gece Mesaisi İçin Uzun Bir Parça Adı", artist: "Sanatçı"),
                errorMessage: nil, isExpanded: $expanded, onPrevious: {}, onPlayPause: {}, onNext: {})
        }
    }
    return Host()
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.fkBackground)
        .fokusTheme()
        .preferredColorScheme(.dark)
}
