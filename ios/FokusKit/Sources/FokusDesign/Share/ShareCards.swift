import FokusDomain
import SwiftUI

/// iMessage kartları (çalışma özeti + oda daveti): `MSMessage` görseli olarak ImageRenderer ile çizilir ve
/// uzantıda önizlenir. Sabit boyutlu (4:3), koyu "Gece mesaisi" yüzeyi; yalnızca tasarım tokenları.
public enum ShareCardLayout {
    public static let size = CGSize(width: 320, height: 240)
}

private struct ShareCardChrome<Content: View>: View {
    let eyebrow: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.md) {
            HStack {
                Text(eyebrow).fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                Spacer(minLength: FokusSpacing.sm)
                Text("FOKUS").fokusTextStyle(.eyebrow).foregroundStyle(.fkAccentInk)
            }
            content
        }
        .padding(FokusSpacing.xl - FokusSpacing.xs)
        .frame(width: ShareCardLayout.size.width, height: ShareCardLayout.size.height, alignment: .topLeading)
        .background(.fkBackground)
        .overlay(RoundedRectangle(cornerRadius: FokusRadius.xl).stroke(.fkSeparator, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: FokusRadius.xl))
        .environment(\.colorScheme, .dark)
    }
}

/// "Bugün şu kadar çalıştım" kartı.
public struct StudyShareCardView: View {
    private let card: StudyShareCard

    public init(card: StudyShareCard) { self.card = card }

    public var body: some View {
        ShareCardChrome(eyebrow: "BUGÜN · \(ShareCardText.dayLabel(card.day).uppercased(with: Locale(identifier: "tr_TR")))") {
            HStack(alignment: .center, spacing: FokusSpacing.lg) {
                VStack(alignment: .leading, spacing: FokusSpacing.xs) {
                    ShareDurationText(minutes: card.focusMinutes)
                    Text("odaklandım").fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                }
                Spacer(minLength: 0)
                if let ratio = card.goalRatio {
                    ProgressRing(progress: ratio, lineWidth: 7, tone: ratio >= 1 ? .success : .accent) {
                        Text("%\(Int((ratio * 100).rounded()))").fokusTextStyle(.numeralSM).foregroundStyle(.fkLabel)
                    }
                    .frame(width: 76, height: 76)
                }
            }
            if !card.subjects.isEmpty {
                VStack(spacing: FokusSpacing.xs) {
                    ForEach(card.subjects, id: \.name) { subject in
                        HStack {
                            Text(subject.name).fokusTextStyle(.footnote).foregroundStyle(.fkLabel).lineLimit(1)
                            Spacer(minLength: FokusSpacing.sm)
                            Text(SocialFormat.formatDurationShort(Double(subject.minutes) * 60_000))
                                .fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
                        }
                    }
                }
                .padding(.top, FokusSpacing.xs)
                .overlay(alignment: .top) { Rectangle().fill(.fkSeparator).frame(height: 1) }
            }
            Spacer(minLength: 0)
            HStack {
                if let streak = card.streakDays {
                    Text("\(streak) gün üst üste").fokusTextStyle(.footnote).foregroundStyle(.fkAccentInk)
                }
                Spacer(minLength: FokusSpacing.sm)
                if let name = card.name {
                    Text(name).fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel).lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.summaryText)
    }
}

/// Oda daveti kartı: başlangıç saati, süre, katılımcılar. Statik görsel; kalan süre gibi canlı değerler yok
/// (görsel gönderilirken bir kez çizilir). Canlı durum uzantı/uygulama içinde bağlantıdan hesaplanır.
public struct RoomInviteCardView: View {
    private static let visibleParticipants = 3
    private let invite: RoomInvite
    private let calendar: Calendar

    public init(invite: RoomInvite, calendar: Calendar = .current) {
        self.invite = invite
        self.calendar = calendar
    }

    public var body: some View {
        ShareCardChrome(eyebrow: "ORTAK ODAK") {
            HStack(alignment: .firstTextBaseline, spacing: FokusSpacing.sm) {
                Text(ShareCardText.timeLabel(invite.startsAt, calendar: calendar))
                    .fokusTextStyle(.numeralLG).foregroundStyle(.fkLabel)
                Text("\(invite.durationMinutes) dk").fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
            }
            Text(ShareCardText.dateLabel(invite.startsAt, calendar: calendar))
                .fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
            VStack(spacing: FokusSpacing.xs) {
                ForEach(Array(invite.participants.prefix(Self.visibleParticipants).enumerated()), id: \.element.id) { index, person in
                    HStack {
                        Text(person.name).fokusTextStyle(.callout).foregroundStyle(.fkLabel).lineLimit(1)
                        Spacer(minLength: FokusSpacing.sm)
                        if index == 0 { Text("kurdu").fokusTextStyle(.footnote).foregroundStyle(.fkAccentInk) }
                    }
                }
                if invite.participants.count > Self.visibleParticipants {
                    Text("+\(invite.participants.count - Self.visibleParticipants) kişi daha")
                        .fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, FokusSpacing.xs)
            .overlay(alignment: .top) { Rectangle().fill(.fkSeparator).frame(height: 1) }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(invite.summaryText)
    }
}

/// "3 sa 25 dk" — rakamlar iri, birimler ikincil.
private struct ShareDurationText: View {
    let minutes: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if minutes >= 60 {
                Text("\(minutes / 60)").fokusTextStyle(.numeralXL).foregroundStyle(.fkLabel)
                Text("sa").fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
            }
            if minutes % 60 != 0 || minutes == 0 {
                Text("\(minutes % 60)").fokusTextStyle(.numeralXL).foregroundStyle(.fkLabel)
                Text("dk").fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// Kartlardaki tarih/saat biçimleri (tr-TR).
public enum ShareCardText {
    private static func formatter(_ format: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter
    }

    /// `ISODate` → "23 Kasım". Geçersizse günün kendisi.
    public static func dayLabel(_ day: ISODate, calendar: Calendar = .current) -> String {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
            let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return day }
        return formatter("d MMMM", calendar: calendar).string(from: date)
    }

    public static func timeLabel(_ date: Date, calendar: Calendar = .current) -> String {
        formatter("HH:mm", calendar: calendar).string(from: date)
    }

    /// "23 Kasım Pazartesi"
    public static func dateLabel(_ date: Date, calendar: Calendar = .current) -> String {
        formatter("d MMMM EEEE", calendar: calendar).string(from: date)
    }
}
