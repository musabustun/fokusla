import AppIntents

/// Siri ve Kestirmeler uygulamasında hazır görünen Fokus kestirmeleri (Türkçe ifadeler).
/// Her ifade uygulama adını içermek zorundadır (`\(.applicationName)`).
struct FokusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: [
                "\(.applicationName) odak başlat",
                "\(.applicationName) ile odaklan",
                "\(.applicationName) odaklanmaya başla",
                "\(.applicationName) \(\.$subject) odağı başlat",
            ],
            shortTitle: "Odak başlat",
            systemImageName: "timer")
        AppShortcut(
            intent: FinishFocusIntent(),
            phrases: [
                "\(.applicationName) odağı bitir",
                "\(.applicationName) odağı durdur",
            ],
            shortTitle: "Odağı bitir",
            systemImageName: "stop.circle")
        AppShortcut(
            intent: TodayFocusIntent(),
            phrases: [
                "\(.applicationName) bugün ne kadar çalıştım",
                "\(.applicationName) bugünkü odak süresi",
            ],
            shortTitle: "Bugün ne kadar çalıştım?",
            systemImageName: "chart.bar")
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "\(.applicationName) görev ekle",
                "\(.applicationName) yeni görev",
            ],
            shortTitle: "Görev ekle",
            systemImageName: "checklist")
    }
}
