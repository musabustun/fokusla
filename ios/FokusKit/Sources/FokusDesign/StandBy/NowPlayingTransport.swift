import SwiftUI

/// "Şimdi çalıyor" düğmeleri için ortak basma geri bildirimi: basılıyken hafif küçülür, bırakınca yaylanarak
/// geri döner. Hareket azaltma açıkken ölçek değişmez (yalnızca opaklık).
struct NowPlayingPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressBody(isPressed: configuration.isPressed, label: configuration.label)
    }

    private struct PressBody<Label: View>: View {
        let isPressed: Bool
        let label: Label
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            label
                .scaleEffect(isPressed && !reduceMotion ? 0.86 : 1)
                .opacity(isPressed ? 0.8 : 1)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.55), value: isPressed)
        }
    }
}

/// Önceki / oynat-duraklat / sonraki satırı. Düğmeler ≥ 44 pt, hafif titreşimli ve yaylı basma geri bildirimli;
/// oynat ↔ duraklat simgesi yumuşakça yer değiştirir. Erişilebilirlik kimlikleri `"\(identifierPrefix).previous"`,
/// `.playPause`, `.next`.
public struct NowPlayingTransport: View {
    private let isPaused: Bool
    private let identifierPrefix: String
    private let playDiameter: CGFloat
    private let spacing: CGFloat
    private let onPrevious: () -> Void
    private let onPlayPause: () -> Void
    private let onNext: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var taps = 0

    public init(
        isPaused: Bool, identifierPrefix: String, playDiameter: CGFloat = 64, spacing: CGFloat = FokusSpacing.xl,
        onPrevious: @escaping () -> Void, onPlayPause: @escaping () -> Void, onNext: @escaping () -> Void
    ) {
        self.isPaused = isPaused
        self.identifierPrefix = identifierPrefix
        self.playDiameter = max(playDiameter, fokusMinTapTarget)
        self.spacing = spacing
        self.onPrevious = onPrevious
        self.onPlayPause = onPlayPause
        self.onNext = onNext
    }

    public var body: some View {
        HStack(spacing: spacing) {
            sideButton("backward.fill", label: "Önceki parça", id: "previous", action: onPrevious)
            Button {
                taps += 1
                onPlayPause()
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: playDiameter * 0.38, weight: .semibold))
                    .foregroundStyle(.fkAccentContrast)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: playDiameter, height: playDiameter)
                    .background(Circle().fill(.fkAccent))
                    .contentShape(Circle())
            }
            .buttonStyle(NowPlayingPressStyle())
            .accessibilityLabel(isPaused ? "Oynat" : "Duraklat")
            .accessibilityIdentifier("\(identifierPrefix).playPause")
            sideButton("forward.fill", label: "Sonraki parça", id: "next", action: onNext)
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: isPaused)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }

    private func sideButton(_ symbol: String, label: String, id: String, action: @escaping () -> Void)
        -> some View
    {
        Button {
            taps += 1
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: playDiameter * 0.34, weight: .semibold))
                .foregroundStyle(.fkLabel)
                .frame(width: fokusMinTapTarget + 8, height: fokusMinTapTarget + 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(NowPlayingPressStyle())
        .accessibilityLabel(label)
        .accessibilityIdentifier("\(identifierPrefix).\(id)")
    }
}
