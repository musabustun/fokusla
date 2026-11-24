import FokusData
import FokusDesign
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "settings")

/// "Hesabı sil" ve "Tüm verileri sil" akışları (web `DeleteAccountSheet` + `WipeDataSheet`).
/// Hesap silme: önce hesabı onaylatır, sonra YEREL verilere ne olacağını AYRICA sorar.
/// Veri silme: çift onay; başarılı silmeden sonra kök kapı onboarding'e döner.
struct DangerFlowSheet: View {
    enum Flow { case deleteAccount, wipeData }

    enum Step {
        case deleteConfirm, localDataQuestion, wipeWarn, wipeFinal
    }

    let flow: Flow
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.syncService) private var syncService
    @Environment(\.notificationService) private var notificationService
    @Environment(\.socialService) private var socialService

    @State private var step: Step
    @State private var outcome: AccountDeletionOutcome?
    @State private var errorMessage: String?
    @State private var isWorking = false

    init(flow: Flow, onClose: @escaping () -> Void) {
        self.flow = flow
        self.onClose = onClose
        _step = State(initialValue: flow == .deleteAccount ? .deleteConfirm : .wipeWarn)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: FokusSpacing.lg) {
                content
                if let errorMessage { SettingsMessage(text: errorMessage, isError: true) }
                Spacer(minLength: 0)
                VStack(spacing: FokusSpacing.sm) { actions }
            }
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.vertical, FokusSpacing.lg)
            .background(.fkBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isWorking)
        .accessibilityIdentifier("settings.dangerSheet")
    }

    private var title: String {
        switch step {
        case .deleteConfirm: "Hesabı sil"
        case .localDataQuestion: "Cihazdaki veriler"
        case .wipeWarn: "Tüm veriler silinsin mi?"
        case .wipeFinal: "Emin misin?"
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .deleteConfirm:
            paragraphs([
                "Hesabını silersen Apple ile giriş bağlantın kalkar ve iCloud eşitlemesi kapanır. Bu cihazdaki verilerine ne olacağını bir sonraki adımda ayrıca soracağız.",
                "Sosyal profilin (kullanıcı adın, arkadaşlıkların, odan) iCloud'dan silinir. Fokus'un kendi sunucusu yoktur.",
            ])
        case .localDataQuestion:
            paragraphs(localDataParagraphs)
        case .wipeWarn:
            paragraphs([
                "Odak oturumların, test sonuçların, kitapların, görevlerin, profilin, sosyal profilin ve girişin silinir. Uygulama ilk açılış ekranına döner.",
                "Silmeden önce \"Verileri dışa aktar\" ile bir yedek almanı öneririz.",
                "iCloud eşitlemesi açıksa silme diğer cihazlarına da yansıyabilir.",
            ])
        case .wipeFinal:
            paragraphs(["Son onay: silinen veriler geri getirilemez."])
        }
    }

    private var localDataParagraphs: [String] {
        var lines = ["Hesabın bu cihazdan ayrıldı. Verilerin hesaptan bağımsız olarak cihazında saklanıyor; istersen onları da silebilirsin."]
        if outcome == .manualRevocationNeeded {
            lines.append(
                "Apple'ın giriş izni sunucu olmadan buradan iptal edilemez. İptal etmek için: Ayarlar › Apple Hesabın › Apple ile Giriş Kullanan Uygulamalar › Fokus › \"Apple ile Giriş'i Durdur\".")
        }
        return lines
    }

    @ViewBuilder private var actions: some View {
        switch step {
        case .deleteConfirm:
            Button("Hesabımı sil", action: deleteAccount)
                .buttonStyle(.fokusDestructive)
                .disabled(isWorking)
                .accessibilityIdentifier("settings.danger.deleteAccount")
            Button("Vazgeç", action: onClose).buttonStyle(.fokusPlain)
                .accessibilityIdentifier("settings.danger.cancel")
        case .localDataQuestion:
            Button("Verilerimi cihazda tut", action: onClose).buttonStyle(.fokusPrimary)
                .accessibilityIdentifier("settings.danger.keepData")
            Button("Cihazdaki verileri de sil…") { step = .wipeWarn }
                .buttonStyle(.fokusDestructive)
                .accessibilityIdentifier("settings.danger.toWipe")
        case .wipeWarn:
            Button("Devam") { step = .wipeFinal }
                .buttonStyle(.fokusDestructive)
                .accessibilityIdentifier("settings.danger.continue")
            Button("Vazgeç", action: onClose).buttonStyle(.fokusPlain)
                .accessibilityIdentifier("settings.danger.cancel")
        case .wipeFinal:
            Button("Her şeyi kalıcı olarak sil", action: wipe)
                .buttonStyle(.fokusDestructive)
                .disabled(isWorking)
                .accessibilityIdentifier("settings.danger.wipe")
            Button("Vazgeç", action: onClose).buttonStyle(.fokusPlain)
                .accessibilityIdentifier("settings.danger.cancel")
        }
    }

    private func paragraphs(_ texts: [String]) -> some View {
        VStack(alignment: .leading, spacing: FokusSpacing.md) {
            ForEach(texts, id: \.self) { text in
                Text(text).fokusTextStyle(.body).foregroundStyle(.fkSecondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func deleteAccount() {
        isWorking = true
        errorMessage = nil
        let service = AccountService(context: modelContext, sync: syncService)
        Task {
            defer { isWorking = false }
            do {
                try await deleteSocialProfile()
                outcome = try await service.deleteAccount()
                step = .localDataQuestion
            } catch let error as SocialError {
                errorMessage = "Sosyal profilin silinemedi. \(error.userMessage)"
            } catch {
                logger.error("Hesap silinemedi: \(error.localizedDescription, privacy: .public)")
                errorMessage = "Hesap silinemedi. Lütfen tekrar dene."
            }
        }
    }

    /// Sosyal'i bu cihazda hiç kullanmamış kişide (ör. çevrimdışı ya da iCloud'suz) silme engellenmez.
    private func deleteSocialProfile() async throws {
        guard let socialService else { return }
        do {
            try await socialService.deleteAccount()
        } catch {
            logger.error("Sosyal profil silinemedi: \(String(describing: error), privacy: .public)")
            if socialService.mayHaveProfile { throw error }
        }
    }

    private func wipe() {
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                try await deleteSocialProfile()
                try wipeLocalData()
                if let notificationService { await ReminderScheduler(service: notificationService).cancelAll() }
                onClose()
            } catch let error as SocialError {
                errorMessage = "Sosyal profilin silinemedi. \(error.userMessage)"
            } catch {
                logger.error("Veriler silinemedi: \(error.localizedDescription, privacy: .public)")
                errorMessage = "Veriler silinemedi. Lütfen tekrar dene."
            }
        }
    }

    private func wipeLocalData() throws {
        try LocalDataService(context: modelContext).deleteAll()
        try CurriculumSeeder.ensureSeeded(context: modelContext)
        syncService?.setEnabled(false)
        ReminderPreferences().reset()
    }
}
