import SwiftUI

/// Tam ekran odak zemini; güvenli alanı yok sayarak tüm ekranı doldurur.
/// `plain` tema zemini, `gradient` alt köşeden çok hafif vurgu parıltısı, `aura` yavaş süzülen bulanık
/// vurgu lekeleri (hareket azaltmada durağan), `black` saf siyah (OLED istisnası: `Color.black`).
public struct StandByBackdropView: View {
    private let backdrop: StandByBackdrop

    @Environment(\.fokusPalette) private var palette

    public init(_ backdrop: StandByBackdrop) {
        self.backdrop = backdrop
    }

    /// Parıltı opaklığı (zemin üstünde çok hafif kalır).
    static let glowOpacity: Double = 0.15
    /// Aura döngü süresi (sn).
    static let auraPeriod: Double = 48

    public var body: some View {
        ZStack {
            switch backdrop {
            case .plain:
                Color.clear
            case .gradient:
                glow
            case .aura:
                StandByAura(palette: palette)
            case .black:
                Color.black
            }
        }
        .background { backdrop == .black ? Color.black : FokusColor.color(.background, palette: palette) }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var glow: some View {
        RadialGradient(
            colors: [FokusColor.color(.accent, palette: palette).opacity(Self.glowOpacity), .clear],
            center: .bottomTrailing, startRadius: 0, endRadius: 520)
    }
}

/// Yavaşça süzülen 3 bulanık leke. Saniyede ~15 kare; hareket azaltmada zaman sabit (durağan).
private struct StandByAura: View {
    let palette: FokusPalette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Blob {
        let token: FokusColorToken
        let opacity: Double
        let diameter: CGFloat
        let anchor: CGPoint
        let phase: Double
    }

    private static let blobs: [Blob] = [
        Blob(token: .accent, opacity: 0.16, diameter: 0.9, anchor: CGPoint(x: 0.2, y: 0.25), phase: 0),
        Blob(token: .accentSubtle, opacity: 0.5, diameter: 1.0, anchor: CGPoint(x: 0.8, y: 0.6), phase: 0.33),
        Blob(token: .accent, opacity: 0.10, diameter: 0.7, anchor: CGPoint(x: 0.5, y: 0.9), phase: 0.66),
    ]
    private static let driftFraction: CGFloat = 0.12

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                ZStack {
                    ForEach(Array(Self.blobs.enumerated()), id: \.offset) { _, blob in
                        blobView(blob, time: time, in: proxy.size)
                    }
                }
                .blur(radius: 90)
                .drawingGroup()
            }
        }
    }

    private func blobView(_ blob: Blob, time: Double, in size: CGSize) -> some View {
        let progress = (time / StandByBackdropView.auraPeriod + blob.phase) * 2 * .pi
        let diameter = min(size.width, size.height) * blob.diameter
        let dx = CGFloat(cos(progress)) * size.width * Self.driftFraction
        let dy = CGFloat(sin(progress)) * size.height * Self.driftFraction
        return Circle()
            .fill(FokusColor.color(blob.token, palette: palette).opacity(blob.opacity))
            .frame(width: diameter, height: diameter)
            .position(x: size.width * blob.anchor.x + dx, y: size.height * blob.anchor.y + dy)
    }
}
