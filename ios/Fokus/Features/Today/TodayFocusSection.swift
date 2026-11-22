import FokusDesign
import FokusDomain
import SwiftUI

/// Bugün'ün Odak bölümü: günün toplamı (ana öğe; hedef varsa halka), açık oturumun canlı süresi,
/// özet rakamlar, son 7 gün ve tek dokunuşla Odak'a geçiş. Yalnızca okur. Web `FocusCard`.
struct TodayFocusSection: View {
    let sessions: [FocusSessionSnapshot]
    let segments: [FocusSegmentSnapshot]
    let goalMinutes: Int?
    let isWide: Bool

    @Environment(AppNavigation.self) private var navigation

    private var hasActiveSession: Bool {
        sessions.contains { $0.endedAt == nil && $0.deletedAt == nil }
    }

    var body: some View {
        // Açık oturumda canlı sayaç saniyede, yoksa dakikada bir yenilenir.
        TimelineView(.periodic(from: .now, by: hasActiveSession ? 1 : 30)) { context in
            let now = context.date
            let today = Identifiers.isoDate(now)
            let summary = TodayCalc.focusSummary(sessions: sessions, segments: segments, today: today, now: now)
            let active = TodayCalc.activeFocus(
                session: sessions.filter { $0.endedAt == nil && $0.deletedAt == nil }
                    .max { $0.startedAt < $1.startedAt },
                segments: segments, now: now)
            let week = TodayCalc.recentFocusTotals(sessions: sessions, segments: segments, now: now)
            let goal = DailyGoalCalc.progress(focusMs: summary.totalMs, goalMinutes: goalMinutes)
            content(summary: summary, active: active, week: week, goal: goal)
        }
    }

    @ViewBuilder
    private func content(
        summary: TodayCalc.FocusSummary, active: TodayCalc.ActiveFocus?,
        week: [FocusCalc.DailyFocusTotal], goal: DailyGoalCalc.Progress?
    ) -> some View {
        let hero = hero(summary: summary, active: active, goal: goal)
        let details = VStack(alignment: .leading, spacing: FokusSpacing.xl) {
            stats(summary)
            TodayWeekChart(totals: week)
        }
        if isWide {
            HStack(alignment: .center, spacing: FokusSpacing.xxl * 2) {
                hero.frame(maxWidth: .infinity)
                details.frame(maxWidth: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                hero
                details
            }
        }
    }

    // MARK: - Halka / toplam + eylem

    private func hero(
        summary: TodayCalc.FocusSummary, active: TodayCalc.ActiveFocus?, goal: DailyGoalCalc.Progress?
    ) -> some View {
        VStack(alignment: .center, spacing: FokusSpacing.lg) {
            total(summary: summary, active: active, goal: goal)
            if let active { activePanel(active) }
            startButton(isActive: active != nil)
            if goal == nil { goalHint }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func total(
        summary: TodayCalc.FocusSummary, active: TodayCalc.ActiveFocus?, goal: DailyGoalCalc.Progress?
    ) -> some View {
        let isBreak = active?.phase == .break
        if let goal {
            ZStack {
                ProgressRing(progress: goal.ratio, lineWidth: 10, tone: goal.isReached || isBreak ? .success : .accent)
                VStack(spacing: FokusSpacing.xs) {
                    Text("BUGÜN").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                    TodayDuration(ms: summary.totalMs, style: .numeralXL)
                    Text(DailyGoalCalc.remainingText(goal))
                        .fokusTextStyle(.footnote)
                        .foregroundStyle(goal.isReached ? FokusColor(.success) : FokusColor(.secondaryLabel))
                }
                .padding(.horizontal, FokusSpacing.xl)
            }
            .frame(width: 264, height: 264)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Bugünkü odak süresi")
            .accessibilityValue(
                "\(TodayDuration.text(summary.totalMs)). Günlük hedef \(DailyGoalCalc.goalText(minutes: goal.goalMinutes)), "
                    + DailyGoalCalc.remainingText(goal))
            .accessibilityIdentifier("today.focus.ring")
        } else {
            VStack(spacing: FokusSpacing.xs) {
                Text("BUGÜN").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                TodayDuration(ms: summary.totalMs, style: .numeralHero)
                if summary.totalMs <= 0 {
                    Text("Bugün henüz odak yok").fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
                }
            }
            .padding(.vertical, FokusSpacing.lg)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Bugünkü odak süresi")
            .accessibilityValue(TodayDuration.text(summary.totalMs))
            .accessibilityIdentifier("today.focus.total")
        }
    }

    /// Açık oturumun durumu ve canlı odak süresi (çizgili satır).
    private func activePanel(_ active: TodayCalc.ActiveFocus) -> some View {
        let isBreak = active.phase == .break
        return HStack {
            Label(isBreak ? "Moladasın" : "Odaktasın", systemImage: isBreak ? "cup.and.saucer" : "timer")
                .fokusTextStyle(.subheadline)
                .foregroundStyle(isBreak ? FokusColor(.success) : FokusColor(.accentInk))
            Spacer()
            Text(FocusFormat.clock(active.sessionFocusMs))
                .fokusTextStyle(.numeral)
                .foregroundStyle(.fkLabel)
        }
        .padding(.vertical, FokusSpacing.md)
        .overlay(alignment: .top) { Divider().overlay(.fkSeparator) }
        .overlay(alignment: .bottom) { Divider().overlay(.fkSeparator) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isBreak ? "Moladasın" : "Odaktasın")
        .accessibilityValue("Oturum odak süresi \(FocusFormat.durationText(active.sessionFocusMs))")
        .accessibilityIdentifier("today.focus.active")
    }

    private func startButton(isActive: Bool) -> some View {
        Button { navigation.open(.focus) } label: {
            if isActive {
                Text("Odağa dön")
            } else {
                Label("Odak başlat", systemImage: "play.fill")
            }
        }
        .buttonStyle(.fokusPrimary)
        .accessibilityIdentifier("today.focus.start")
    }

    private var goalHint: some View {
        Button { navigation.open(.settings) } label: {
            Text("Günlük hedef koymak için Ayarlar'a bak")
                .fokusTextStyle(.footnote)
                .foregroundStyle(.fkSecondaryLabel)
                .frame(minHeight: fokusMinTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today.focus.goalHint")
    }

    // MARK: - Özet rakamlar

    private func stats(_ summary: TodayCalc.FocusSummary) -> some View {
        VStack(spacing: 0) {
            Divider().overlay(.fkSeparator)
            HStack(alignment: .top, spacing: 0) {
                stat("Oturum", id: "today.focus.sessions", spoken: "\(summary.sessionCount)") {
                    Text("\(summary.sessionCount)").fokusTextStyle(.numeralLG).foregroundStyle(.fkLabel)
                }
                Divider().overlay(.fkSeparator)
                stat(
                    "Ortalama kesintisiz odak", id: "today.focus.average",
                    spoken: summary.averageFocusMs > 0 ? FocusFormat.durationText(summary.averageFocusMs) : "henüz yok"
                ) {
                    if summary.averageFocusMs > 0 {
                        TodayDuration(ms: summary.averageFocusMs, style: .numeralLG)
                    } else {
                        Text("—").fokusTextStyle(.numeralLG).foregroundStyle(.fkTertiaryLabel)
                    }
                }
                .padding(.leading, FokusSpacing.lg)
            }
            .padding(.vertical, FokusSpacing.lg)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stat<Value: View>(
        _ title: String, id: String, spoken: String, @ViewBuilder value: () -> Value
    ) -> some View {
        VStack(alignment: .leading, spacing: FokusSpacing.sm) {
            Text(title).fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
            value()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(spoken)
        .accessibilityIdentifier(id)
    }
}
