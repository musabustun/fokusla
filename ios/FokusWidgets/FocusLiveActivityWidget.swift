import ActivityKit
import AppIntents
import FokusDesign
import FokusDomain
import SwiftUI
import WidgetKit

/// Odak/mola kronometresi: kilit ekranı + Dynamic Island. Saniyeleri sistem sayar (`Text(timerInterval:)`);
/// Mola ver/Devam et ve Bitir düğmeleri `LiveActivityIntent`'tir (uygulama sürecinde çalışır).
///
/// "Gece mesaisi" dili: koyu zemin, tek amber vurgu (mola: adaçayı), büyük mono sayaç. Ana sayaç odakta SON
/// DEVAMDAN beri geçen süredir (moladan dönüşte sıfırlanır); oturum toplamı ikincil satırdadır.
/// Kilit ekranı duvar kağıdı açık da olsa koyu tonda sabittir (`activityBackgroundTint`), bu yüzden içerik
/// her zaman koyu renk şemasıyla çizilir.
struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            LockScreenFocusView(attributes: context.attributes, state: context.state)
                .environment(\.colorScheme, .dark)
                .activityBackgroundTint(ActivityAppearance.lockScreenTint)
                .activitySystemActionForegroundColor(ActivityAppearance.systemActionForeground)
        } dynamicIsland: { context in
            let state = context.state
            let subject = context.attributes.subjectLabel
            return DynamicIsland {
                // Kameranın iki yanı: kısa durum etiketi ve ikincil toplam. Uzun içerik (ders adı, sayaç,
                // düğmeler) kameranın ALTINDAki `.bottom` bölgesindedir; böylece hiçbir şey TrueDepth
                // kameranın altında kalmaz/kesilmez.
                DynamicIslandExpandedRegion(.leading) {
                    PhaseBadge(phase: state.phase).padding(.leading, FokusSpacing.xs)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SecondaryTotal(state: state, alignment: .trailing)
                        .padding(.trailing, FokusSpacing.xs)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottom(state: state, subject: subject)
                }
            } compactLeading: {
                PhaseDot(phase: state.phase).padding(.leading, FokusSpacing.xs)
            } compactTrailing: {
                FocusTimerText(state: state, style: .numeralSM, alignment: .trailing)
                    .frame(width: 52, alignment: .trailing)
            } minimal: {
                PhaseDot(phase: state.phase)
            }
            .keylineTint(state.phase.tone)
        }
    }
}

// MARK: - Görünüm sabitleri

enum ActivityAppearance {
    /// Kilit ekranı zemini: palet `background` renginin KOYU hâli, az saydam (duvar kağıdı hafifçe sezilir,
    /// ama açık duvar kağıdında da metin AA kontrastında kalır).
    static var lockScreenTint: Color {
        darkToken(.background).opacity(0.94)
    }

    /// Sistem eylem düğmesi (kapat/aç) metin rengi.
    static var systemActionForeground: Color { darkToken(.label) }

    /// Token'ın koyu görünümü (sabit): kilit ekranı sistemi açık olsa bile zemin koyu kalır. Renk, SwiftUI'ın
    /// kendi çözümleyicisiyle KOYU ortamda çözülür (`UIColor(named:compatibleWith:)` uzantı sürecinde açık
    /// varyantı döndürebiliyor).
    static func darkToken(_ token: FokusColorToken) -> Color {
        var environment = EnvironmentValues()
        environment.colorScheme = .dark
        return Color(FokusColor.color(token).resolve(in: environment))
    }
}

extension FocusActivityCalc.Phase {
    /// Odak: amber vurgu; mola: adaçayı. Her yüzey koyu olduğu için parlak tonlar (`accent`, `success`).
    var tone: Color { FokusColor.color(self == .focus ? .accent : .success) }

    /// Tonun üstündeki metin rengi (dolgulu düğme).
    var toneContrast: Color { FokusColor.color(self == .focus ? .accentContrast : .successContrast) }

    var title: String { self == .focus ? "Odak" : "Mola" }
}

enum ActivityTimer {
    /// Sayaç aralığının üst sınırı. `...distantFuture` aralığı sistemin sayaç genişliğini "gün" hanelerine
    /// göre ayırmasına ve metnin "21:--" diye kesilmesine yol açar; 12 saat ("12:00:00") yeterli ve dardır
    /// (Live Activity zaten en fazla 8–12 saat yaşar).
    static let horizon: TimeInterval = 12 * 3600

    static func range(from start: Date) -> ClosedRange<Date> { start...start.addingTimeInterval(horizon) }
}

// MARK: - Sayaçlar

/// Ana sayaç: odakta son devamdan, molada mola başından beri.
struct FocusTimerText: View {
    let state: FocusActivityAttributes.ContentState
    var style: FokusTextStyle = .numeralLG
    var alignment: TextAlignment = .leading

    var body: some View {
        Text(timerInterval: ActivityTimer.range(from: state.timerStart), countsDown: false)
            .fokusTextStyle(style)
            .foregroundStyle(.fkLabel)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .multilineTextAlignment(alignment)
    }
}

/// İkincil "Oturum toplam odak" sayacı. Yalnızca moladan sonra (odakta ana sayaçtan farklıyken) ya da molada
/// görünür; molada mola başında DONAR (`pauseTime`). İlk kesintisiz odakta ana sayaçla aynı olduğundan gizlidir.
struct SecondaryTotal: View {
    let state: FocusActivityAttributes.ContentState
    var alignment: HorizontalAlignment = .leading

    private var isVisible: Bool { state.phase == .break || state.state.hasResumedAfterBreak }

    var body: some View {
        if isVisible, let start = state.sessionFocusStart {
            VStack(alignment: alignment, spacing: 0) {
                Text("Toplam odak").fokusTextStyle(.caption).foregroundStyle(.fkSecondaryLabel)
                Text(
                    timerInterval: ActivityTimer.range(from: start),
                    pauseTime: state.phase == .break ? state.timerStart : nil, countsDown: false
                )
                .fokusTextStyle(.numeralSM)
                .foregroundStyle(.fkLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
        }
    }
}

// MARK: - Durum

struct PhaseDot: View {
    let phase: FocusActivityCalc.Phase

    var body: some View {
        Image(systemName: phase == .focus ? "timer" : "cup.and.saucer.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(phase.tone)
            .accessibilityLabel(phase.title)
    }
}

/// "● ODAK" / "● MOLA": küçük nokta + mono büyük harf etiketi.
struct PhaseBadge: View {
    let phase: FocusActivityCalc.Phase

    var body: some View {
        HStack(spacing: FokusSpacing.sm) {
            Circle().fill(phase.tone).frame(width: 7, height: 7).accessibilityHidden(true)
            Text(phase.title).fokusTextStyle(.eyebrow).foregroundStyle(phase.tone)
        }
        .lineLimit(1)
    }
}

// MARK: - Günlük hedef çubuğu

/// Günlük hedef ilerlemesi. Odakta sistem çubuğu (`ProgressView(timerInterval:)`) hedefe doğru kendiliğinden
/// akar; molada odak donduğu için sabit bir çubuk gösterilir. Hedef kapalıysa hiçbir şey çizilmez.
struct GoalBar: View {
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        if let goalMinutes = state.goalMinutes, let dayStart = state.dayFocusStart {
            bar(dayStart: dayStart, goalMs: DailyGoalCalc.goalMs(minutes: goalMinutes))
                .progressViewStyle(.linear)
                .tint(state.phase.tone)
                .accessibilityLabel("Günlük hedef \(DailyGoalCalc.goalText(minutes: goalMinutes))")
        }
    }

    @ViewBuilder
    private func bar(dayStart: Date, goalMs: Double) -> some View {
        if state.phase == .focus {
            ProgressView(
                timerInterval: dayStart...dayStart.addingTimeInterval(goalMs / 1000), countsDown: false
            ) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
        } else {
            let frozenMs = state.timerStart.timeIntervalSince(dayStart) * 1000
            ProgressView(value: min(max(frozenMs / goalMs, 0), 1))
        }
    }
}

// MARK: - Düğmeler

/// Mola ver / Devam et ve Bitir. İki düğme de ≥ 44pt yüksekliğinde, tam genişlikte kapsül; ana eylem mola
/// ("Devam et") tonla dolu, diğerleri çizgili (uygulamadaki düğme hiyerarşisiyle aynı).
struct ControlButtons: View {
    let phase: FocusActivityCalc.Phase

    var body: some View {
        HStack(spacing: FokusSpacing.md) {
            Button(intent: TogglePauseFocusIntent()) {
                ActivityButtonLabel(
                    title: phase == .focus ? "Mola ver" : "Devam et",
                    systemImage: phase == .focus ? "pause.fill" : "play.fill",
                    style: phase == .focus ? .outlined(phase.tone) : .filled(phase.tone, phase.toneContrast))
            }
            Button(intent: FinishFocusIntent()) {
                ActivityButtonLabel(title: "Bitir", systemImage: "stop.fill", style: .outlined(nil))
            }
        }
        .buttonStyle(.plain)
    }
}

struct ActivityButtonLabel: View {
    enum Style {
        case filled(Color, Color)
        case outlined(Color?)
    }

    let title: String
    let systemImage: String
    let style: Style

    var body: some View {
        Label(title, systemImage: systemImage)
            .fokusTextStyle(.subheadline)
            .fontWeight(.semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: fokusMinTapTarget)
            .background(background)
            .overlay(outline)
            .contentShape(Capsule())
    }

    private var foreground: Color {
        switch style {
        case let .filled(_, contrast): contrast
        case let .outlined(tone): tone ?? FokusColor.color(.label)
        }
    }

    @ViewBuilder private var background: some View {
        if case let .filled(tone, _) = style { Capsule().fill(tone) }
    }

    @ViewBuilder private var outline: some View {
        if case let .outlined(tone) = style {
            Capsule().strokeBorder(tone ?? FokusColor.color(.separatorStrong), lineWidth: 1)
        }
    }
}

// MARK: - Yüzeyler

/// Dynamic Island genişletilmiş alt bölgesi (kameranın altı): büyük sayaç + ders adı, düğmeler. Hedef çubuğu
/// yalnızca kilit ekranında: ada yüksekliği sınırlıdır ve fazla satır düğmeleri alt köşede keser.
struct ExpandedBottom: View {
    let state: FocusActivityAttributes.ContentState
    let subject: String?

    var body: some View {
        VStack(spacing: FokusSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: FokusSpacing.md) {
                FocusTimerText(state: state, style: .numeralLG)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let subject {
                    Text(subject)
                        .fokusTextStyle(.footnote)
                        .foregroundStyle(.fkSecondaryLabel)
                        .lineLimit(1)
                        .frame(maxWidth: 130, alignment: .trailing)
                }
            }
            ControlButtons(phase: state.phase)
        }
    }
}

/// Kilit ekranı: durum + ders adı üstte, büyük sayaç ve ikincil toplam ortada, hedef çubuğu, düğmeler.
/// Kilit ekranı Live Activity'si EN FAZLA 160 pt yüksekliğindedir; fazlası alttan/üstten kırpılır. Dikey
/// bütçe: 12 + durum 16 + 8 + sayaç 44 + 8 + çubuk 4 + 8 + düğmeler 44 + 12 = 156 pt.
struct LockScreenFocusView: View {
    let attributes: FocusActivityAttributes
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.sm) {
            HStack(spacing: FokusSpacing.sm) {
                PhaseBadge(phase: state.phase)
                if let subject = attributes.subjectLabel {
                    Text("·").foregroundStyle(.fkTertiaryLabel)
                    Text(subject)
                        .fokusTextStyle(.footnote)
                        .foregroundStyle(.fkSecondaryLabel)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            HStack(alignment: .lastTextBaseline) {
                FocusTimerText(state: state, style: .numeralLG)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SecondaryTotal(state: state, alignment: .trailing)
            }
            GoalBar(state: state)
            ControlButtons(phase: state.phase)
        }
        .padding(.horizontal, FokusSpacing.lg)
        .padding(.vertical, FokusSpacing.md)
    }
}
