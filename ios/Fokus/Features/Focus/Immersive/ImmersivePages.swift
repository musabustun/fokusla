import FokusDesign
import FokusDomain
import SwiftUI

/// Sayfaların ortak girdisi (tüm değerler dışarıdan gelir; sayfalar saf görünümdür).
struct ImmersivePageContext {
    var snapshot: ImmersiveSnapshot
    var sessionLabel: String?
    var now: Date
    /// Ekranın güvenli alan boşlukları (sayfalar kenarlara kadar uzanır, içerik bunlara göre dizilir).
    var insets: EdgeInsets
    /// Altta sayfa göstergesi ve (sabitlenmişse) kontrol çubuğu için ayrılan yükseklik.
    var bottomReserve: CGFloat

    var contentPadding: EdgeInsets {
        EdgeInsets(
            top: max(insets.top, FokusSpacing.lg),
            leading: max(insets.leading, FokusSpacing.xl),
            bottom: insets.bottom + bottomReserve,
            trailing: max(insets.trailing, FokusSpacing.xl))
    }
}

extension FocusTimerPhase {
    /// Büyük rakamların rengi: molada mola tonu (`success`), aksi halde `label`.
    var immersiveDigitColor: FokusColor { self == .break ? FokusColor(.success) : FokusColor(.label) }
    var immersivePhaseColor: FokusColor {
        switch self {
        case .idle: FokusColor(.secondaryLabel)
        case .focus: FokusColor(.accentInk)
        case .break: FokusColor(.success)
        }
    }
}

/// Faz etiketi: odakta kehribar nokta + "ODAK", molada "MOLA" (mola tonu).
struct ImmersivePhaseLabel: View {
    let phase: FocusTimerPhase
    var isDimmed = false

    var body: some View {
        HStack(spacing: FokusSpacing.sm) {
            if phase == .focus {
                Circle().fill(.fkAccent).frame(width: 6, height: 6).accessibilityHidden(true)
            }
            Text(phase.label)
                .fokusTextStyle(.eyebrow)
                .foregroundStyle(phase.immersivePhaseColor)
                .accessibilityIdentifier("immersive.phase")
        }
        .opacity(isDimmed ? 0.45 : 1)
    }
}

/// Süre değeri için VoiceOver ve test öğesi (`immersive.clock`).
private struct ImmersiveClockAccessibility: ViewModifier {
    let phase: FocusTimerPhase
    let ms: Double

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(phase == .break ? "Mola süresi" : "Oturum süresi")
            .accessibilityValue(FocusFormat.clock(ms))
            .accessibilityAddTraits(phase.isRunning ? .updatesFrequently : [])
            .accessibilityIdentifier("immersive.clock")
    }
}

extension View {
    fileprivate func immersiveClockAccessibility(phase: FocusTimerPhase, ms: Double) -> some View {
        modifier(ImmersiveClockAccessibility(phase: phase, ms: ms))
    }
}

// MARK: - (a) Kronometre

/// Büyük mono kronometre + gerçek saat. Yatayda rakamlar ekranı doldurur (StandBy hissi).
struct ImmersiveStopwatchPage: View {
    let context: ImmersivePageContext

    private static let turkish = Locale(identifier: "tr_TR")

    var body: some View {
        let snap = context.snapshot
        VStack(spacing: FokusSpacing.md) {
            HStack {
                Text(context.now, format: .dateTime.hour().minute().locale(Self.turkish))
                    .fokusTextStyle(.numeralLG)
                    .foregroundStyle(.fkSecondaryLabel)
                    .accessibilityLabel("Saat")
                Spacer(minLength: 0)
            }
            .frame(minHeight: fokusMinTapTarget)
            ZStack {
                ImmersiveDigits(text: FocusFormat.clock(snap.shownMs))
                    .foregroundStyle(snap.phase.immersiveDigitColor)
            }
            .frame(maxHeight: .infinity)
            .immersiveClockAccessibility(phase: snap.phase, ms: snap.shownMs)
            ImmersivePhaseLabel(phase: snap.phase)
            Text(snap.phase == .idle ? " " : (context.sessionLabel ?? " "))
                .fokusTextStyle(.subheadline)
                .foregroundStyle(.fkSecondaryLabel)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .frame(minHeight: 20)
        }
        .padding(context.contentPadding)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ImmersivePage.stopwatch.accessibilityIdentifier)
    }
}

// MARK: - (b) Halka

/// Saatlik tur halkası: içinde oturum süresi, yanında/altında bugünkü toplam.
struct ImmersiveRingPage: View {
    let context: ImmersivePageContext

    private static let ringLineWidth: CGFloat = 10
    /// Halka içindeki rakam alanının çapa oranı.
    private static let digitsWidthRatio: CGFloat = 0.66
    private static let digitsHeightRatio: CGFloat = 0.3

    var body: some View {
        let snap = context.snapshot
        GeometryReader { proxy in
            let size = proxy.size
            let isWide = size.width > size.height * 1.15
            let diameter = isWide ? min(size.height, size.width * 0.45) : min(size.width, size.height * 0.62)
            Group {
                if isWide {
                    HStack(spacing: FokusSpacing.xxl) {
                        ring(snap, diameter: diameter)
                        info(snap, alignment: .leading)
                    }
                } else {
                    VStack(spacing: FokusSpacing.xl) {
                        ring(snap, diameter: diameter)
                        info(snap, alignment: .center)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .padding(context.contentPadding)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ImmersivePage.ring.accessibilityIdentifier)
    }

    private func ring(_ snap: ImmersiveSnapshot, diameter: CGFloat) -> some View {
        ProgressRing(
            progress: snap.hourLap, lineWidth: Self.ringLineWidth,
            tone: snap.phase == .break ? .success : .accent
        ) {
            ImmersiveDigits(text: FocusFormat.clock(snap.shownMs))
                .foregroundStyle(snap.phase.immersiveDigitColor)
                .frame(width: diameter * Self.digitsWidthRatio, height: diameter * Self.digitsHeightRatio)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snap.phase == .break ? "Mola süresi" : "Oturum süresi")
        .accessibilityValue(FocusFormat.clock(snap.shownMs))
        .accessibilityAddTraits(snap.phase.isRunning ? .updatesFrequently : [])
        .accessibilityIdentifier("immersive.clock")
    }

    private func info(_ snap: ImmersiveSnapshot, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: FokusSpacing.md) {
            ImmersivePhaseLabel(phase: snap.phase)
            VStack(alignment: alignment, spacing: FokusSpacing.xs) {
                Text("Bugün toplam").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                FocusDurationValue(ms: snap.todayTotalMs, style: .numeralLG)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Bugün toplam")
            .accessibilityValue(FocusFormat.durationText(snap.todayTotalMs))
            .accessibilityIdentifier("immersive.todayTotal")
        }
    }
}

// MARK: - (c) Gece

/// OLED gece görünümü: saf siyah zemin, yalnızca soluk süre (+ çok soluk faz etiketi). Tasarım
/// kuralının tek istisnası: bu sayfada `Color.black` kullanılır (OLED'de piksel tamamen kapalı olsun).
/// İçerik her zaman koyu şemada çözülür; açık temada bile siyah üstünde okunur kalır.
struct ImmersiveNightPage: View {
    let context: ImmersivePageContext

    private static let digitOpacity: Double = 0.38

    var body: some View {
        let snap = context.snapshot
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: FokusSpacing.md) {
                ZStack {
                    ImmersiveDigits(text: FocusFormat.clock(snap.shownMs))
                        .foregroundStyle(
                            (snap.phase == .break ? FokusColor(.success) : FokusColor(.label))
                                .opacity(Self.digitOpacity))
                }
                .frame(maxHeight: .infinity)
                .immersiveClockAccessibility(phase: snap.phase, ms: snap.shownMs)
                ImmersivePhaseLabel(phase: snap.phase, isDimmed: true)
            }
            .padding(context.contentPadding)
        }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ImmersivePage.night.accessibilityIdentifier)
    }
}
