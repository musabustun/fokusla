import FokusData
import FokusDesign
import FokusDomain
import SwiftUI

/// Arkadaş listesi: odakta → molada → çevrimdışı; sağda bugünkü toplam süre.
struct SocialFriendsSection: View {
    let social: any SocialService
    let friends: [SocialFriend]
    let now: Date
    let onAddFriend: () -> Void

    // Kimlik tutulur; sayfa canlı listeden okunur (durum güncellemeleri sayfaya da yansır).
    @State private var selectedId: String?

    private struct Row: Identifiable {
        let friend: SocialFriend
        let state: PresenceState
        var id: String { friend.userId }
    }

    private static let order: [PresenceState: Int] = [.focusing: 0, .onBreak: 1, .offline: 2]

    private var rows: [Row] {
        friends
            .map { Row(friend: $0, state: SocialCalc.effectivePresenceState($0.presence, now: now)) }
            .enumerated()
            .sorted { lhs, rhs in
                let (l, r) = (Self.order[lhs.element.state] ?? 2, Self.order[rhs.element.state] ?? 2)
                return l == r ? lhs.offset < rhs.offset : l < r
            }
            .map(\.element)
    }

    var body: some View {
        let rows = rows
        let focusingCount = rows.filter { $0.state == .focusing }.count
        VStack(alignment: .leading, spacing: FokusSpacing.sm) {
            SocialSectionHeader("Arkadaşlar (\(friends.count))") {
                Button("Arkadaş ekle", action: onAddFriend)
                    .buttonStyle(SocialChipButtonStyle())
                    .accessibilityIdentifier("social.friends.add")
            }
            VStack(spacing: 0) {
                Divider().overlay(.fkSeparator)
                ForEach(rows) { row in
                    Button { selectedId = row.id } label: { friendRow(row) }
                        .buttonStyle(.fokusRow)
                        .accessibilityIdentifier("social.friend.\(row.friend.username)")
                }
            }
            Text(
                friends.isEmpty
                    ? "Henüz arkadaşın yok. Kullanıcı adıyla istek gönderebilir ya da davet bağlantısı paylaşabilirsin."
                    : "\(focusingCount) arkadaşın şu an odakta. Sağdaki süre bugünkü toplam odak süresidir."
            )
            .fokusTextStyle(.footnote)
            .foregroundStyle(.fkSecondaryLabel)
        }
        .sheet(
            isPresented: Binding(get: { selectedId != nil }, set: { if !$0 { selectedId = nil } })
        ) {
            SocialFriendSheet(
                social: social, friend: friends.first { $0.userId == selectedId }, now: now)
        }
        .socialContainer("social.friends")
    }

    private func friendRow(_ row: Row) -> some View {
        let presence = row.friend.presence
        let line = SocialFormat.formatPresenceLine(
            row.state, SocialCalc.liveStateMs(presence, now: now))
        let today = SocialFormat.formatDurationShort(SocialCalc.liveTodayFocusMs(presence, now: now))
        return VStack(spacing: 0) {
            HStack(spacing: FokusSpacing.md) {
                PresenceDot(state: row.state)
                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(row.friend.username)").fokusTextStyle(.body).foregroundStyle(.fkLabel).lineLimit(1)
                    Text(line).fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                }
                Spacer(minLength: FokusSpacing.sm)
                Text(today)
                    .fokusTextStyle(.numeralSM)
                    .foregroundStyle(row.state == .focusing ? FokusColor.fkLabel : .fkSecondaryLabel)
                LineChevron()
            }
            .frame(minHeight: fokusMinTapTarget)
            .padding(.vertical, FokusSpacing.md)
            Divider().overlay(.fkSeparator)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("@\(row.friend.username), \(line), bugün \(today)")
        .accessibilityHint("Arkadaş ayrıntılarını açar")
    }
}

/// Arkadaş ayrıntısı: durum, bugünkü süre, arkadaşlıktan çıkar.
private struct SocialFriendSheet: View {
    let social: any SocialService
    let friend: SocialFriend?
    let now: Date

    @Environment(\.dismiss) private var dismiss
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        SocialSheetScaffold(
            title: friend.map { "@\($0.username)" } ?? "Arkadaş", description: nil,
            identifier: "social.friendSheet"
        ) {
            if let friend {
                let state = SocialCalc.effectivePresenceState(friend.presence, now: now)
                VStack(spacing: 0) {
                    Divider().overlay(.fkSeparator)
                    detailRow("Durum") {
                        HStack(spacing: FokusSpacing.sm) {
                            PresenceDot(state: state)
                            Text(SocialFormat.formatPresenceLine(
                                state, SocialCalc.liveStateMs(friend.presence, now: now)))
                        }
                    }
                    detailRow("Bugün") {
                        Text(SocialFormat.formatDurationShort(
                            SocialCalc.liveTodayFocusMs(friend.presence, now: now)))
                            .fokusTextStyle(.numeralSM)
                    }
                }
                if let errorMessage { SocialErrorText(message: errorMessage, identifier: "social.friendSheet.error") }
                Button("Arkadaşlıktan çıkar") {
                    run { try await social.removeFriend(userId: friend.userId) }
                }
                .buttonStyle(.fokusDestructive)
                .disabled(isBusy)
                .accessibilityIdentifier("social.friendSheet.remove")
                HStack {
                    Text("Engellediğin kişinin istekleri sana ulaşmaz.")
                        .fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
                    Spacer(minLength: FokusSpacing.sm)
                    SocialSafetyMenu(username: friend.username) {
                        run { try await social.blockFriend(userId: friend.userId) }
                    }
                    .disabled(isBusy)
                }
            }
        }
        .onChange(of: friend == nil) { _, isGone in if isGone { dismiss() } }
    }

    private func detailRow<V: View>(_ title: String, @ViewBuilder value: () -> V) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).fokusTextStyle(.body).foregroundStyle(.fkSecondaryLabel)
                Spacer()
                value().fokusTextStyle(.body).foregroundStyle(.fkLabel)
            }
            .frame(minHeight: fokusMinTapTarget)
            Divider().overlay(.fkSeparator)
        }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        isBusy = true
        errorMessage = nil
        Task {
            defer { isBusy = false }
            do {
                try await action()
                dismiss()
            } catch {
                errorMessage = SocialError.message(for: error)
            }
        }
    }
}
