import FokusDesign
import FokusDomain
import SwiftUI

/// Kronometrenin durumu (web `TimerPhase`).
enum FocusTimerPhase: Equatable {
    case idle, focus, `break`

    var label: String {
        switch self {
        case .idle: "Hazır"
        case .focus: "Odak"
        case .break: "Mola"
        }
    }

    var isRunning: Bool { self != .idle }
}

/// Eylemler (ekran uygular).
struct FocusTimerActions {
    var start: () -> Void
    var pause: () -> Void
    var resume: () -> Void
    var finish: () -> Void
}

/// Kronometre: durum, büyük halka + saat, bugünkü toplam, (boştayken) ders seçici, uzun mola uyarısı
/// ve eylemler. Saf görünümdür: tüm değerler dışarıdan gelir.
struct FocusTimerPanel<PickerContent: View>: View {
    let phase: FocusTimerPhase
    /// Bu oturumun toplam odak süresi (ms).
    let sessionFocusMs: Double
    /// Açık molanın süresi (ms); molada değilse 0.
    let breakMs: Double
    let todayTotalMs: Double
    let sessionLabel: String?
    let isLongBreak: Bool
    let errorMessage: String?
    @ViewBuilder let picker: () -> PickerContent

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWide: Bool { horizontalSizeClass == .regular }
    private var ringMaxWidth: CGFloat { isWide ? 360 : 280 }

    var body: some View {
        VStack(spacing: FokusSpacing.xl) {
            dial
            totals
            if phase == .idle { picker() }
            if phase == .break && isLongBreak { FocusLongBreakAlert() }
            if let errorMessage {
                Text(errorMessage)
                    .fokusTextStyle(.subheadline)
                    .foregroundStyle(.fkDanger)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("focus.error")
            }
        }
    }

    // MARK: Halka + saat

    private var shownMs: Double { phase == .break ? breakMs : phase == .focus ? sessionFocusMs : 0 }

    /// Saatlik tur: geçen sürenin saat içindeki payı (0–1); yay her saniye hafifçe ilerler.
    static func hourLap(_ ms: Double) -> Double {
        guard ms.isFinite, ms > 0 else { return 0 }
        let hourMs = 3_600_000.0
        return ms.truncatingRemainder(dividingBy: hourMs) / hourMs
    }

    private var dial: some View {
        VStack(spacing: FokusSpacing.md) {
            HStack(spacing: FokusSpacing.sm) {
                if phase == .focus {
                    Circle().fill(.fkAccent).frame(width: 6, height: 6).accessibilityHidden(true)
                }
                Text(phase.label)
                    .fokusTextStyle(.eyebrow)
                    .foregroundStyle(phaseColor)
                    .accessibilityIdentifier("focus.phase")
            }
            ProgressRing(
                progress: Self.hourLap(shownMs), lineWidth: 7, tone: phase == .break ? .success : .accent
            ) {
                clock
            }
            .frame(maxWidth: ringMaxWidth)
            // Halkanın kendi erişilebilirlik öğesi (yüzde) yerine saat okunur.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(phase == .break ? "Mola süresi" : "Oturum süresi")
            .accessibilityValue(FocusFormat.clock(shownMs))
            .accessibilityAddTraits(phase.isRunning ? .updatesFrequently : [])
            .accessibilityIdentifier("focus.clock")
            Text(phase == .idle ? " " : (sessionLabel ?? " "))
                .fokusTextStyle(.subheadline)
                .foregroundStyle(.fkSecondaryLabel)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(minHeight: 20)
        }
    }

    private var phaseColor: FokusColor {
        switch phase {
        case .idle: .fkSecondaryLabel
        case .focus: .fkAccentInk
        case .break: .fkSuccess
        }
    }

    private var clock: some View {
        let text = FocusFormat.clock(shownMs)
        // Saat hanesi varsa (7 karakter) iPhone halkasına sığması için bir kademe küçülür (web ile aynı).
        let style: FokusTextStyle = text.count > 5 && !isWide ? .numeralXL : .numeralHero
        return Text(text)
            .fokusTextStyle(style)
            .foregroundStyle(phase.isRunning ? FokusColor(.label) : FokusColor(.tertiaryLabel))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, FokusSpacing.lg)
            .accessibilityHidden(true)
    }

    // MARK: Toplamlar

    private var totals: some View {
        VStack(spacing: 0) {
            Divider().overlay(.fkSeparator)
            HStack(alignment: .top, spacing: FokusSpacing.xxl) {
                if phase == .break {
                    total("Bu oturumda odak", FocusFormat.durationText(sessionFocusMs), id: "focus.sessionTotal")
                }
                total("Bugün toplam", FocusFormat.durationText(todayTotalMs), id: "focus.todayTotal")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, FokusSpacing.lg)
            Divider().overlay(.fkSeparator)
        }
    }

    private func total(_ title: String, _ value: String, id: String) -> some View {
        VStack(spacing: FokusSpacing.xs) {
            Text(title).fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
            Text(value).fokusTextStyle(.numeralSM).foregroundStyle(.fkLabel)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

}

/// Eylem düğmeleri. Ana eylem her durumda aynı konumda kalır. Kehribar hap yalnızca boşta
/// ("Odak başlat") ve molada ("Devam et"); odaktayken "Mola ver" ve "Bitir" çizgili hap olur
/// (ekranda en fazla bir kehribar eylem). Uzun molada "Bitir" → "Oturumu bitir".
struct FocusActionButtons: View {
    let phase: FocusTimerPhase
    let isLongBreak: Bool
    /// `true`: düğmeler alt alta (geniş sütun); `false`: yan yana (iPhone'da alta sabit çubuk).
    let isStacked: Bool
    let actions: FocusTimerActions

    var body: some View {
        let layout = isStacked ? AnyLayout(VStackLayout(spacing: FokusSpacing.md)) : AnyLayout(HStackLayout(spacing: FokusSpacing.md))
        layout {
            switch phase {
            case .idle:
                Button(action: actions.start) { Label("Odak başlat", systemImage: "play.fill") }
                    .buttonStyle(.fokusPrimary)
                    .accessibilityIdentifier("focus.start")
            case .focus:
                Button(action: actions.pause) {
                    Label("Mola ver", systemImage: "pause.fill").lineLimit(1).minimumScaleFactor(0.8)
                }
                    .buttonStyle(.fokusSecondary)
                    .accessibilityIdentifier("focus.pause")
            case .break:
                Button(action: actions.resume) {
                    Label("Devam et", systemImage: "play.fill").lineLimit(1).minimumScaleFactor(0.8)
                }
                    .buttonStyle(.fokusPrimary)
                    .accessibilityIdentifier("focus.resume")
            }
            if phase != .idle {
                Button(action: actions.finish) {
                    Label(isLongBreak ? "Oturumu bitir" : "Bitir", systemImage: "stop.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.fokusSecondary)
                .accessibilityIdentifier("focus.finish")
            }
        }
    }
}

/// Mola eşiği aştığında gösterilen uyarı metni. Oturum kendiliğinden bitmez; karar kullanıcıdadır
/// ("Devam et" / "Oturumu bitir" düğmeleri `FocusActionButtons`'ta).
struct FocusLongBreakAlert: View {
    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(.fkSeparator)
            HStack(alignment: .top, spacing: FokusSpacing.md) {
                Image(systemName: "alarm")
                    .font(.title3)
                    .foregroundStyle(.fkWarning)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: FokusSpacing.xs) {
                    Text("Molan uzadı").fokusTextStyle(.headline).foregroundStyle(.fkLabel)
                    Text(
                        "Mola süren \(FocusFormat.durationText(FocusCalc.longBreakThresholdMs)) sınırını geçti. Hazırsan odağa dön ya da oturumu bitir."
                    )
                    .fokusTextStyle(.subheadline)
                    .foregroundStyle(.fkSecondaryLabel)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, FokusSpacing.lg)
            Divider().overlay(.fkSeparator)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("focus.longBreak")
    }
}

#Preview("Zamanlayıcı — odak, koyu") {
    panelPreview(.focus).preferredColorScheme(.dark)
}

#Preview("Zamanlayıcı — uzun mola, açık") {
    panelPreview(.break, longBreak: true).preferredColorScheme(.light)
}

@MainActor
private func panelPreview(_ phase: FocusTimerPhase, longBreak: Bool = false) -> some View {
    FocusTimerPanel(
        phase: phase, sessionFocusMs: 3_905_000, breakMs: 2_000_000, todayTotalMs: 9_000_000,
        sessionLabel: "TYT · Matematik · Temel kavramlar", isLongBreak: longBreak, errorMessage: nil
    ) { Text("Ders seçici") }
    .padding(FokusSpacing.screenHorizontal)
    .background(.fkBackground)
    .fokusTheme()
}
