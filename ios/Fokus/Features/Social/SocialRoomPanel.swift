import FokusData
import FokusDesign
import FokusDomain
import SwiftUI

/// Paralel odak: içindeysem oda, değilsem oda oluştur / katıl.
struct SocialRoomPanel: View {
    let social: any SocialService
    let room: SocialRoom?
    let friendRooms: [RoomSummary]
    let own: SocialPresence
    let now: Date

    var body: some View {
        if let room {
            SocialRoomView(social: social, room: room, own: own, now: now)
        } else {
            SocialRoomLobby(social: social, friendRooms: friendRooms)
        }
    }
}

private struct SocialRoomLobby: View {
    let social: any SocialService
    let friendRooms: [RoomSummary]

    private enum Sheet: String, Identifiable {
        case create, join
        var id: String { rawValue }
    }

    @State private var sheet: Sheet?
    @State private var joiningId: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.xl) {
            VStack(alignment: .leading, spacing: FokusSpacing.sm) {
                Text("Paralel odak").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                    .accessibilityAddTraits(.isHeader)
                Text("Odada herkes kendi kronometresiyle çalışır; yalnızca durumlar ve süreler görünür.")
                    .fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
                HStack(spacing: FokusSpacing.sm) {
                    Button("Oda oluştur") { sheet = .create }
                        .buttonStyle(.fokusSecondary)
                        .accessibilityIdentifier("social.room.create")
                    Button("Kodla katıl") { sheet = .join }
                        .buttonStyle(.fokusPlain)
                        .accessibilityIdentifier("social.room.join")
                }
            }
            VStack(alignment: .leading, spacing: FokusSpacing.sm) {
                Text("Arkadaşlarının odaları").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    Divider().overlay(.fkSeparator)
                    if friendRooms.isEmpty {
                        Text("Şu an açık oda yok. Bir oda oluşturup arkadaşlarını çağırabilirsin.")
                            .fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                            .padding(.vertical, FokusSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Divider().overlay(.fkSeparator)
                    }
                    ForEach(friendRooms) { summary in summaryRow(summary) }
                }
                if let errorMessage {
                    SocialErrorText(message: errorMessage, identifier: "social.room.error")
                }
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .create: SocialCreateRoomSheet(social: social)
            case .join: SocialJoinRoomSheet(social: social)
            }
        }
        .socialContainer("social.lobby")
    }

    private func summaryRow(_ summary: RoomSummary) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: FokusSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.name).fokusTextStyle(.body).foregroundStyle(.fkLabel).lineLimit(1)
                    Text("@\(summary.host.username) · \(summary.memberCount) kişi · \(summary.focusingCount) odakta")
                        .fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                }
                Spacer(minLength: FokusSpacing.sm)
                Button("Katıl") { join(summary.id) }
                    .buttonStyle(SocialChipButtonStyle())
                    .disabled(joiningId == summary.id)
                    .accessibilityLabel("\(summary.name) odasına katıl")
                    .accessibilityIdentifier("social.room.join.\(summary.id)")
            }
            .frame(minHeight: fokusMinTapTarget)
            .padding(.vertical, FokusSpacing.sm)
            Divider().overlay(.fkSeparator)
        }
    }

    private func join(_ roomId: String) {
        joiningId = roomId
        errorMessage = nil
        Task {
            defer { joiningId = nil }
            do { try await social.joinRoom(.room(id: roomId)) } catch let error as SocialError {
                errorMessage = error.userMessage
            } catch {
                errorMessage = "Bir şeyler ters gitti. Lütfen tekrar dene."
            }
        }
    }
}

private struct SocialRoomView: View {
    let social: any SocialService
    let room: SocialRoom
    let own: SocialPresence
    let now: Date

    @Environment(AppNavigation.self) private var navigation: AppNavigation?
    @State private var isLeaving = false
    @State private var errorMessage: String?

    private var memberStates: [(member: RoomMember, presence: SocialPresence?, state: PresenceState, sessionMs: Double)] {
        room.members.map { member in
            let presence = member.isSelf ? own : member.presence
            return (
                member, presence, SocialCalc.effectivePresenceState(presence, now: now),
                SocialCalc.liveSessionMs(presence, now: now)
            )
        }
    }

    var body: some View {
        let states = memberStates
        let focusingCount = states.filter { $0.state == .focusing }.count
        let roomMs = states.map(\.sessionMs).max() ?? 0
        let isHost = room.members.first(where: \.isSelf)?.isHost ?? false
        let ownState = SocialCalc.effectivePresenceState(own, now: now)

        VStack(alignment: .leading, spacing: FokusSpacing.lg) {
            HStack {
                Text(room.name)
                    .fokusTextStyle(.title2)
                    .foregroundStyle(.fkLabel)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("social.room.title")
                Spacer()
                Image(systemName: "door.left.hand.open")
                    .foregroundStyle(.fkSecondaryLabel)
                    .accessibilityHidden(true)
            }
            HStack(alignment: .top, spacing: FokusSpacing.lg) {
                Metric(label: "Katılımcı", value: "\(room.members.count)", size: .lg)
                Metric(label: "Odakta", value: "\(focusingCount)", size: .lg, tone: .success)
                Metric(label: "Oda süresi", value: SocialFormat.formatClock(roomMs), size: .lg)
            }
            inviteRow
            VStack(alignment: .leading, spacing: FokusSpacing.xs) {
                Text("Odadakiler (\(room.members.count))")
                    .fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    Divider().overlay(.fkSeparator)
                    ForEach(states, id: \.member.userId) { memberRow($0) }
                }
            }
            VStack(alignment: .leading, spacing: FokusSpacing.sm) {
                Text(ownState == .offline
                    ? "Henüz başlamadın. Kronometreni Odak ekranında başlat; durumun burada görünür."
                    : "Süren Odak ekranındaki kronometreden gelir.")
                    .fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
                Button("Odak'a git") { navigation?.open(.focus) }
                    .buttonStyle(.fokusSecondary)
                    .accessibilityIdentifier("social.room.goFocus")
                Button(isHost ? "Odayı kapat" : "Odadan çık", action: leave)
                    .buttonStyle(.fokusDestructive)
                    .disabled(isLeaving)
                    .accessibilityIdentifier("social.room.leave")
                if let errorMessage {
                    SocialErrorText(message: errorMessage, identifier: "social.room.error")
                }
            }
        }
        .socialContainer("social.room")
    }

    private var inviteRow: some View {
        VStack(spacing: 0) {
            Divider().overlay(.fkSeparator)
            HStack(spacing: FokusSpacing.xs) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Oda davet kodu").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                    Text(room.inviteCode)
                        .fokusTextStyle(.numeralSM).tracking(2).foregroundStyle(.fkLabel)
                        .accessibilityLabel("Oda davet kodu \(room.inviteCode.map(String.init).joined(separator: " "))")
                        .accessibilityIdentifier("social.room.inviteCode")
                }
                Spacer(minLength: FokusSpacing.sm)
                SocialCopyButton(
                    text: room.inviteCode, accessibilityLabel: "Oda davet kodunu kopyala",
                    identifier: "social.room.copyCode")
                ShareLink(item: SocialFormat.roomInviteMessage(code: room.inviteCode, name: room.name)) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: fokusMinTapTarget, height: fokusMinTapTarget)
                }
                .accessibilityLabel("Oda davet kodunu paylaş")
                .accessibilityIdentifier("social.room.shareCode")
            }
            .padding(.vertical, FokusSpacing.xs)
            Divider().overlay(.fkSeparator)
        }
    }

    private func memberRow(
        _ item: (member: RoomMember, presence: SocialPresence?, state: PresenceState, sessionMs: Double)
    ) -> some View {
        let line = SocialFormat.formatPresenceLine(
            item.state, SocialCalc.liveStateMs(item.presence, now: now))
        var label = "@\(item.member.username)"
        if item.member.isSelf { label += " (sen)" }
        if item.member.isHost { label += ", ev sahibi" }
        label += ", \(line)"
        if item.state != .offline {
            label += ", oturum \(SocialFormat.formatClockLabel(item.sessionMs))"
        }
        return VStack(spacing: 0) {
            HStack(spacing: FokusSpacing.md) {
                PresenceDot(state: item.state)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: FokusSpacing.xs) {
                        Text("@\(item.member.username)").fokusTextStyle(.body).foregroundStyle(.fkLabel).lineLimit(1)
                        if item.member.isSelf {
                            Text("(sen)").fokusTextStyle(.body).foregroundStyle(.fkSecondaryLabel)
                        }
                        if item.member.isHost {
                            Text("Ev sahibi")
                                .fokusTextStyle(.caption)
                                .foregroundStyle(.fkAccentInk)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.fkAccentSubtle, in: RoundedRectangle(cornerRadius: FokusRadius.sm))
                        }
                    }
                    Text(line).fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                }
                Spacer(minLength: FokusSpacing.sm)
                if item.state != .offline {
                    Text(SocialFormat.formatClock(item.sessionMs)).fokusTextStyle(.numeralSM)
                }
            }
            .frame(minHeight: fokusMinTapTarget)
            .padding(.vertical, FokusSpacing.sm)
            Divider().overlay(.fkSeparator)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityIdentifier("social.member.\(item.member.username)")
    }

    private func leave() {
        isLeaving = true
        errorMessage = nil
        Task {
            await social.leaveRoom()
            isLeaving = false
        }
    }
}
