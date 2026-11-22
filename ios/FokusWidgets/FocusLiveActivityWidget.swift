import ActivityKit
import AppIntents
import FokusDesign
import FokusDomain
import SwiftUI
import WidgetKit

/// Odak/mola kronometresi: kilit ekranı + Dynamic Island. Saniyeleri sistem sayar (`Text(timerInterval:)`);
/// Mola ver/Devam et ve Bitir düğmeleri `LiveActivityIntent`'tir (uygulama sürecinde çalışır).
struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            LockScreenFocusView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(nil)
                .containerBackground(.fkBackground, for: .widget)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PhaseLabel(phase: state.phase, subject: context.attributes.subjectLabel)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FocusTimerText(state: state, style: .numeral).frame(maxWidth: 110, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ControlButtons(phase: state.phase)
                }
            } compactLeading: {
                Image(systemName: state.phase == .focus ? "timer" : "cup.and.saucer.fill")
                    .foregroundStyle(state.phase.tone())
            } compactTrailing: {
                FocusTimerText(state: state, style: .numeralSM).frame(width: 56)
            } minimal: {
                Image(systemName: state.phase == .focus ? "timer" : "cup.and.saucer.fill")
                    .foregroundStyle(state.phase.tone())
            }
            .keylineTint(state.phase.tone())
        }
    }
}

extension FocusActivityCalc.Phase {
    /// Odak: kehribar vurgu; mola: adaçayı. Koyu zeminde (Dynamic Island hep koyudur) parlak kehribar,
    /// açık kilit ekranında AA için koyu kehribar (`accentInk`).
    func tone(for scheme: ColorScheme = .dark) -> Color {
        guard self == .focus else { return FokusColor.color(.success) }
        return FokusColor.color(scheme == .dark ? .accent : .accentInk)
    }

    var title: String { self == .focus ? "Odak" : "Mola" }
}

struct FocusTimerText: View {
    let state: FocusActivityAttributes.ContentState
    var style: FokusTextStyle = .numeralLG

    var body: some View {
        Text(timerInterval: state.timerStart...Date.distantFuture, countsDown: false)
            .fokusTextStyle(style)
            .foregroundStyle(.fkLabel)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.trailing)
    }
}

struct PhaseLabel: View {
    let phase: FocusActivityCalc.Phase
    let subject: String?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(phase.title).fokusTextStyle(.eyebrow).foregroundStyle(phase.tone(for: scheme))
            if let subject {
                Text(subject).fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel).lineLimit(1)
            }
        }
    }
}

struct ControlButtons: View {
    let phase: FocusActivityCalc.Phase
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: FokusSpacing.md) {
            Button(intent: TogglePauseFocusIntent()) {
                Label(
                    phase == .focus ? "Mola ver" : "Devam et",
                    systemImage: phase == .focus ? "pause.fill" : "play.fill"
                )
                .fokusTextStyle(.subheadline)
                .frame(maxWidth: .infinity, minHeight: fokusMinTapTarget)
            }
            .tint(phase.tone(for: scheme))
            Button(intent: FinishFocusIntent()) {
                Label("Bitir", systemImage: "stop.fill")
                    .fokusTextStyle(.subheadline)
                    .frame(maxWidth: .infinity, minHeight: fokusMinTapTarget)
            }
            .tint(.secondary)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
    }
}

struct LockScreenFocusView: View {
    let attributes: FocusActivityAttributes
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: FokusSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                PhaseLabel(phase: state.phase, subject: attributes.subjectLabel)
                Spacer()
                FocusTimerText(state: state, style: .numeralLG)
            }
            ControlButtons(phase: state.phase)
        }
        .padding(FokusSpacing.lg)
    }
}
