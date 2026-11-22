import FokusData
import FokusDesign
import FokusDomain
import OSLog
import SwiftData
import SwiftUI
import UIKit

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "reminders")

/// Günlük odak hedefi + yerel hatırlatmalar. Hatırlatma tercihleri cihaza özeldir (UserDefaults);
/// hedef profilde saklanır ve CloudKit ile eşitlenir.
struct SettingsGoalReminderSection: View {
    let profile: UserProfile?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.notificationService) private var notificationService
    @Environment(\.scenePhase) private var scenePhase

    @State private var settings = ReminderPreferences().load()
    @State private var authorization: NotificationAuthorization = .notDetermined
    @State private var showsPermissionAlert = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.xl) {
            goalSection
            reminderSection
        }
        .task { await refreshAuthorization() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refreshAuthorization() } }
        }
        .alert("Bildirim izni kapalı", isPresented: $showsPermissionAlert) {
            Button("Ayarlar'ı aç", action: openSystemSettings)
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Hatırlatmaları kullanmak için Fokus'a bildirim izni vermen gerekiyor.")
        }
    }

    // MARK: - Günlük hedef

    private var goalSection: some View {
        LineSection(
            "Günlük hedef",
            footer: "Bugün ekranı bu hedefe göre ilerlemeni gösterir. Kapalıyken hedef gösterilmez."
        ) {
            LineRow("Günlük odak hedefi") {
                Picker("Günlük odak hedefi", selection: goalBinding) {
                    Text("Kapalı").tag(Int?.none)
                    ForEach(DailyGoalCalc.options, id: \.self) { minutes in
                        Text(DailyGoalCalc.goalText(minutes: minutes)).tag(Int?.some(minutes))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings.goal")
            }
        }
    }

    private var goalBinding: Binding<Int?> {
        Binding(
            get: { DailyGoalCalc.normalized(profile?.dailyFocusGoalMinutes) },
            set: { newValue in
                do {
                    try ProfileRepository(context: modelContext).setDailyFocusGoal(minutes: newValue)
                    reschedule()
                } catch {
                    logger.error("Hedef kaydedilemedi: \(error.localizedDescription, privacy: .public)")
                    errorMessage = "Hedef kaydedilemedi. Lütfen tekrar dene."
                }
            }
        )
    }

    // MARK: - Hatırlatmalar

    private var reminderSection: some View {
        LineSection("Hatırlatmalar", footer: reminderFooter) {
            SettingsToggleRow(
                title: "Rutin hatırlatması", subtitle: "O gün planlı rutinlerinin sayısını söyler",
                isOn: toggleBinding(\.routineEnabled)
            )
            .accessibilityIdentifier("settings.reminder.routine")
            if settings.routineEnabled {
                timeRow("Rutin saati", time: timeBinding(\.routineTime), id: "settings.reminder.routineTime")
            }
            SettingsToggleRow(
                title: "Çalışma hatırlatması", subtitle: "Seçtiğin saatte günlük hedefini hatırlatır",
                isOn: toggleBinding(\.studyEnabled)
            )
            .accessibilityIdentifier("settings.reminder.study")
            if settings.studyEnabled {
                timeRow("Çalışma saati", time: timeBinding(\.studyTime), id: "settings.reminder.studyTime")
            }
            if authorization == .denied {
                SettingsButtonRow(title: "Bildirim ayarlarını aç", showsChevron: true, action: openSystemSettings)
                    .accessibilityIdentifier("settings.reminder.openSettings")
            }
        }
    }

    private var reminderFooter: String {
        if authorization == .denied {
            return "Bildirim izni kapalı; hatırlatmalar için sistem ayarlarından izin vermelisin."
        }
        return "Hatırlatmalar yalnızca cihazında planlanır; sunucu kullanılmaz. Hedefe ulaştığın gün çalışma hatırlatması gönderilmez."
    }

    private func timeRow(_ title: String, time: Binding<Date>, id: String) -> some View {
        LineRow(title) {
            DatePicker(title, selection: time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .accessibilityIdentifier(id)
        }
    }

    private func toggleBinding(_ keyPath: WritableKeyPath<ReminderSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                if newValue {
                    Task { await enable(keyPath) }
                } else {
                    update { $0[keyPath: keyPath] = false }
                }
            }
        )
    }

    private func timeBinding(_ keyPath: WritableKeyPath<ReminderSettings, ReminderTime>) -> Binding<Date> {
        Binding(
            get: { Self.date(for: settings[keyPath: keyPath]) },
            set: { newDate in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                let time = ReminderTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
                update { $0[keyPath: keyPath] = time }
            }
        )
    }

    /// Açmadan önce izin akışını yürütür: sorulmadıysa sorar; reddedildiyse Ayarlar'a yönlendirir.
    private func enable(_ keyPath: WritableKeyPath<ReminderSettings, Bool>) async {
        guard let notificationService else { return }
        var status = await notificationService.authorizationStatus()
        if status == .notDetermined {
            _ = await notificationService.requestAuthorization()
            status = await notificationService.authorizationStatus()
        }
        authorization = status
        guard status.canSchedule else {
            showsPermissionAlert = true
            return
        }
        update { $0[keyPath: keyPath] = true }
    }

    private func update(_ change: (inout ReminderSettings) -> Void) {
        var next = settings
        change(&next)
        settings = next
        ReminderPreferences().save(next)
        reschedule()
    }

    private func reschedule() {
        guard let notificationService else { return }
        let context = modelContext
        Task { await ReminderScheduler(service: notificationService).reschedule(context: context) }
    }

    private func refreshAuthorization() async {
        guard let notificationService else { return }
        authorization = await notificationService.authorizationStatus()
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private static func date(for time: ReminderTime) -> Date {
        Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: .now) ?? .now
    }
}
