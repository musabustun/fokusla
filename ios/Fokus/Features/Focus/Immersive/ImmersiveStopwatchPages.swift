import FokusDesign
import FokusDomain
import SwiftUI

/// Büyük sayaç + ikincil satır, ortak yerleşim: kronometre ve "Ders" kartı kullanır.
private struct ImmersiveBigTimer: View {
    let context: ImmersivePageContext

    var body: some View {
        let snap = context.snapshot
        VStack(spacing: FokusSpacing.md) {
            ZStack {
                StandByDigits(text: FocusFormat.clock(snap.primaryMs), style: context.clockStyle)
                    .foregroundStyle(context.digitColor)
            }
            .frame(maxHeight: .infinity)
            .immersiveClockAccessibility(phase: snap.phase, ms: snap.primaryMs)
            ImmersivePhaseLabel(phase: snap.phase)
            ImmersiveSecondaryLine(secondary: snap.secondary)
        }
    }
}

// MARK: - Kronometre

/// Ekranı dolduran sayaç; üstte küçük gerçek saat + tarih, altta faz ve ikincil satır.
struct ImmersiveStopwatchPage: View {
    let context: ImmersivePageContext

    var body: some View {
        VStack(spacing: FokusSpacing.md) {
            // Üst satır köşe çipi ve düğmelere ayrılır; saat/tarih onların altında durur.
            ImmersiveClockHeader(now: context.now)
                .padding(.top, fokusMinTapTarget + FokusSpacing.sm)
            ImmersiveBigTimer(context: context)
            Text(context.snapshot.phase == .idle ? " " : (context.subject?.line ?? " "))
                .fokusTextStyle(.footnote)
                .foregroundStyle(.fkSecondaryLabel)
                .lineLimit(1)
                .frame(minHeight: 18)
        }
        .padding(context.contentPadding)
        .immersivePageContainer(.stopwatch)
    }
}

// MARK: - Ders

/// Büyük ders adı, konu, sınav rozeti; altında sayaç. Ders yoksa "Serbest çalışma".
struct ImmersiveSubjectPage: View {
    let context: ImmersivePageContext

    var body: some View {
        VStack(spacing: FokusSpacing.lg) {
            Spacer(minLength: 0)
            VStack(spacing: FokusSpacing.sm) {
                if let subject = context.subject {
                    Text(subject.exam)
                        .fokusTextStyle(.eyebrow)
                        .foregroundStyle(.fkAccentInk)
                        .padding(.horizontal, FokusSpacing.md)
                        .padding(.vertical, FokusSpacing.xs)
                        .overlay(Capsule().strokeBorder(.fkSeparatorStrong, lineWidth: 1))
                    Text(subject.name)
                        .fokusTextStyle(.display)
                        .foregroundStyle(.fkLabel)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                    if let topic = subject.topic {
                        Text(topic)
                            .fokusTextStyle(.title3)
                            .foregroundStyle(.fkSecondaryLabel)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                } else {
                    Text("Serbest çalışma")
                        .fokusTextStyle(.display)
                        .foregroundStyle(.fkLabel)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("immersive.subject")
            ImmersiveBigTimer(context: context).frame(maxHeight: 220)
            Spacer(minLength: 0)
        }
        .padding(context.contentPadding)
        .immersivePageContainer(.subject)
    }
}
