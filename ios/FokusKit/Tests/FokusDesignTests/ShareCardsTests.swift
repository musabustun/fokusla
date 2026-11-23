import FokusDomain
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers

@testable import FokusDesign

// iMessage kartları: ImageRenderer ile boyutu ve tarih/saat biçimlerini doğrular. `FOKUS_SHARE_SHOTS_DIR`
// verilirse örnek PNG'leri oraya yazar (ekran görüntüsü için; varsayılan yazmaz).

@MainActor
struct ShareCardsTests {
    private let istanbul: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }()

    private func render<V: View>(_ view: V, name: String, scheme: ColorScheme = .dark) throws -> CGImage {
        FokusFonts.registerAll()
        let renderer = ImageRenderer(
            content: view.environment(\.fokusPalette, .default).environment(\.colorScheme, scheme))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(ShareCardLayout.size)
        let image = try #require(renderer.cgImage)
        if let directory = ProcessInfo.processInfo.environment["FOKUS_SHARE_SHOTS_DIR"] {
            let url = URL(fileURLWithPath: directory).appending(path: "\(name).png")
            try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            if let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) {
                CGImageDestinationAddImage(destination, image, nil)
                CGImageDestinationFinalize(destination)
            }
        }
        return image
    }

    private let fullCard = StudyShareCard(
        day: "2026-11-23", focusMinutes: 205, goalMinutes: 240,
        subjects: [
            .init(name: "Matematik", minutes: 120), .init(name: "Fizik", minutes: 60), .init(name: "Kimya", minutes: 25),
        ], streakDays: 5, name: "Beyza")

    @Test func studyCardsRenderAtCardSize() throws {
        let cards: [(String, StudyShareCard)] = [
            ("study-full", fullCard),
            ("study-minimal", StudyShareCard(day: "2026-11-23", focusMinutes: 45)),
            ("study-empty", StudyShareCard(day: "2026-11-23", focusMinutes: 0, goalMinutes: 120)),
            ("study-goal-reached", StudyShareCard(day: "2026-11-23", focusMinutes: 300, goalMinutes: 240, name: "Beyza")),
        ]
        for (name, card) in cards {
            let image = try render(StudyShareCardView(card: card), name: name)
            #expect(image.width == Int(ShareCardLayout.size.width) * 3, "\(name) genişliği")
            #expect(image.height == Int(ShareCardLayout.size.height) * 3, "\(name) yüksekliği")
        }
    }

    @Test func roomCardsRenderWithManyParticipants() throws {
        let people = (0..<6).map { RoomInvite.Participant(id: UUID(), name: ["Beyza", "Ali", "Ayşe", "Mert", "Zeynep", "Can"][$0]) }
        let invite = RoomInvite(
            id: UUID(), startsAt: Date(timeIntervalSince1970: 1_795_800_000), durationMinutes: 50, participants: people)
        let image = try render(RoomInviteCardView(invite: invite, calendar: istanbul), name: "room-many")
        #expect(image.width == Int(ShareCardLayout.size.width) * 3)
        _ = try render(
            RoomInviteCardView(
                invite: RoomInvite(
                    id: UUID(), startsAt: invite.startsAt, durationMinutes: 25, participants: [people[0]]),
                calendar: istanbul),
            name: "room-new")
    }

    @Test func labelsAreTurkish() {
        #expect(ShareCardText.dayLabel("2026-11-23", calendar: istanbul) == "23 Kasım")
        #expect(ShareCardText.dayLabel("bozuk", calendar: istanbul) == "bozuk")
        let date = istanbul.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 21, minute: 30))!
        #expect(ShareCardText.timeLabel(date, calendar: istanbul) == "21:30")
        #expect(ShareCardText.dateLabel(date, calendar: istanbul) == "23 Kasım Pazartesi")
    }
}
