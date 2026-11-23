import FokusData
import FokusDesign
import FokusDomain
import Messages
import Observation
import SwiftData
import SwiftUI

/// iMessage uzantısının durumu ve mesaj üretimi. Veri App Group deposundan YALNIZCA OKUNUR; hiçbir şey
/// kullanıcı "gönder"e basmadan çıkmaz (`MSConversation.insert` mesajı yalnızca yazı alanına koyar).
@MainActor @Observable
final class MessagesModel {
    enum Tab: Hashable { case study, room }
    enum Availability: Equatable { case loading, ready, storeMissing }

    var tab: Tab = .study
    var availability: Availability = .loading
    var fields: StudyShareCard.Fields = .default
    var isExpanded = false

    /// Odak/ders verisinin okunmuş hâli (`reload`); alan seçimi değişince kart yeniden kurulur.
    private var sessions: [StudyShareCalc.Session] = []
    private var segments: [FocusSegmentSnapshot] = []
    private var subjectNames: [UUID: String] = [:]
    private var goalMinutes: Int?
    private(set) var displayName: String?

    // Oda daveti taslağı
    var durationMinutes = 50
    var startTime = MessagesModel.defaultStart(now: .now)

    /// Konuşmada seçili bir oda mesajı (varsa detay gösterilir).
    var selectedInvite: RoomInvite?
    var selectedSession: MSSession?
    /// Katıl'a basıldı ve güncellenmiş mesaj yazı alanına konuldu.
    var joinMessageInserted = false
    var errorText: String?

    // MARK: - Kimlik (cihaz başına rastgele; hesap/kişi bilgisi içermez)

    private static let participantKey = "messages.participantId"

    var participantId: UUID {
        let defaults = UserDefaults(suiteName: FokusAppGroup.identifier) ?? .standard
        if let stored = defaults.string(forKey: Self.participantKey), let id = UUID(uuidString: stored) {
            return id
        }
        let id = UUID()
        defaults.set(id.uuidString, forKey: Self.participantKey)
        return id
    }

    var participant: RoomInvite.Participant {
        RoomInvite.Participant(id: participantId, name: displayName ?? RoomInvite.fallbackName)
    }

    // MARK: - Veri

    func reload(now: Date = .now) {
        do {
            let context = try FokusSystem.context()
            let liveSessions = try context.fetch(FetchDescriptor<FocusSession>()).filter(\.isLive)
            segments = try context.fetch(FetchDescriptor<FocusSegment>()).filter(\.isLive).map(\.snapshot)
            sessions = liveSessions.map { .init(snapshot: $0.snapshot, subjectId: $0.subjectId) }
            let subjects = try context.fetch(FetchDescriptor<Subject>()).filter(\.isLive)
            subjectNames = Dictionary(subjects.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
            let profile = try ProfileRepository(context: context).current()
            goalMinutes = profile?.dailyFocusGoalMinutes
            displayName = profile?.displayName.flatMap { ShareLink.sanitizedName($0) }
            availability = .ready
        } catch {
            availability = .storeMissing
        }
        startTime = Self.defaultStart(now: now)
    }

    var card: StudyShareCard {
        StudyShareCalc.card(
            sessions: sessions, segments: segments, subjectNames: subjectNames, goalMinutes: goalMinutes,
            displayName: displayName, fields: fields, now: .now)
    }

    // MARK: - Oda taslağı

    static func defaultStart(now: Date, calendar: Calendar = .current) -> Date {
        let plain = now.addingTimeInterval(10 * 60)
        let minute = calendar.component(.minute, from: plain)
        let rounded = (minute + 4) / 5 * 5
        return calendar.date(
            bySettingHour: calendar.component(.hour, from: plain), minute: 0, second: 0, of: plain
        )?.addingTimeInterval(TimeInterval(rounded) * 60) ?? plain
    }

    /// Seçilen saatin sıradaki gerçekleşmesi: bugünse bugün, geçmişteyse (1 dk'dan fazla) yarın.
    func resolvedStart(now: Date = .now, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.hour, .minute], from: startTime)
        let today = calendar.date(
            bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: now) ?? now
        if today >= now.addingTimeInterval(-60) { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }

    var draftInvite: RoomInvite {
        RoomInvite(
            id: UUID(), startsAt: resolvedStart(), durationMinutes: durationMinutes, participants: [participant])
    }

    // MARK: - Seçili mesaj

    func select(_ message: MSMessage?) {
        joinMessageInserted = false
        errorText = nil
        guard let message, let url = message.url, let invite = try? RoomInvite(url: url) else {
            selectedInvite = nil
            selectedSession = nil
            return
        }
        selectedInvite = invite
        selectedSession = message.session
    }

    // MARK: - Mesaj üretimi

    func studyMessage() -> MSMessage {
        let card = card
        let message = MSMessage(session: MSSession())
        message.url = card.url
        message.summaryText = card.summaryText
        message.layout = layout(
            image: ShareImage.render(StudyShareCardView(card: card)), caption: card.summaryText,
            subcaption: card.name)
        return message
    }

    func inviteMessage(_ invite: RoomInvite, session: MSSession) -> MSMessage {
        let message = MSMessage(session: session)
        message.url = invite.url
        message.summaryText = invite.summaryText
        message.layout = layout(
            image: ShareImage.render(RoomInviteCardView(invite: invite)), caption: "Ortak odak daveti",
            subcaption: invite.summaryText)
        return message
    }

    func newInviteMessage() -> MSMessage { inviteMessage(draftInvite, session: MSSession()) }

    /// Seçili odaya katılımı uygular; yazı alanına konacak güncellenmiş mesajı döndürür.
    func joinMessage() -> MSMessage? {
        guard let invite = selectedInvite, let session = selectedSession else { return nil }
        switch invite.joining(participant, now: .now) {
        case .joined(let updated), .alreadyJoined(let updated):
            selectedInvite = updated
            return inviteMessage(updated, session: session)
        case .full:
            errorText = "Oda dolu."
        case .ended:
            errorText = "Bu oda bitti."
        }
        return nil
    }

    private func layout(image: UIImage?, caption: String, subcaption: String?) -> MSMessageTemplateLayout {
        let layout = MSMessageTemplateLayout()
        layout.image = image
        layout.caption = caption
        layout.subcaption = subcaption
        return layout
    }
}

/// SwiftUI kartını mesaj görseline çevirir (3x, koyu zemin).
@MainActor
enum ShareImage {
    static func render<Content: View>(_ content: Content) -> UIImage? {
        FokusFonts.registerAll()
        let renderer = ImageRenderer(
            content: content.environment(\.fokusPalette, .default).environment(\.colorScheme, .dark))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(ShareCardLayout.size)
        return renderer.uiImage
    }
}
