import FokusDesign
import FokusDomain
import SwiftUI

/// Uzantının kök görünümü: küçükken iki büyük giriş, genişleyince "Bugün" / "Oda" sekmeleri,
/// konuşmada bir oda mesajı seçiliyse oda ayrıntısı.
struct MessagesRootView: View {
    let model: MessagesModel
    let actions: MessagesActions

    var body: some View {
        Group {
            if let invite = model.selectedInvite {
                RoomDetailView(model: model, actions: actions, invite: invite)
            } else if !model.isExpanded {
                compactEntry
            } else {
                composer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.fkBackground)
    }

    // MARK: Küçük görünüm

    private var compactEntry: some View {
        VStack(spacing: FokusSpacing.md) {
            entryButton(title: "Bugünkü çalışmam", detail: "Süre ve hedefini kart olarak paylaş", tab: .study)
            entryButton(title: "Odaya davet et", detail: "Birlikte çalışmak için saat ve süre seç", tab: .room)
        }
        .padding(FokusSpacing.lg)
    }

    private func entryButton(title: String, detail: String, tab: MessagesModel.Tab) -> some View {
        Button {
            model.tab = tab
            actions.expand()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fokusTextStyle(.headline).foregroundStyle(.fkLabel)
                Text(detail).fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
            }
            .frame(maxWidth: .infinity, minHeight: fokusMinTapTarget, alignment: .leading)
            .padding(FokusSpacing.md)
            .overlay(RoundedRectangle(cornerRadius: FokusRadius.lg).stroke(.fkSeparatorStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Genişletilmiş görünüm

    private var composer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.lg) {
                Picker("Paylaşım türü", selection: Bindable(model).tab) {
                    Text("Bugün").tag(MessagesModel.Tab.study)
                    Text("Oda").tag(MessagesModel.Tab.room)
                }
                .pickerStyle(.segmented)
                switch model.tab {
                case .study: StudyComposeView(model: model, actions: actions)
                case .room: RoomComposeView(model: model, actions: actions)
                }
                if let error = model.errorText {
                    Text(error).fokusTextStyle(.footnote).foregroundStyle(.fkDanger)
                }
            }
            .padding(FokusSpacing.lg)
        }
    }
}

/// Büyük, tek ana eylemli düğme (kehribar hap).
struct ShareActionButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fokusTextStyle(.headline)
                .foregroundStyle(.fkAccentContrast)
                .frame(maxWidth: .infinity, minHeight: fokusMinTapTarget)
                .background(.fkAccent, in: Capsule())
                .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - Bugün

struct StudyComposeView: View {
    let model: MessagesModel
    let actions: MessagesActions

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.lg) {
            if model.availability == .storeMissing {
                Text("Önce Fokus'u bir kez aç; çalışma verin burada görünsün.")
                    .fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
            } else {
                StudyShareCardView(card: model.card)
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: FokusSpacing.xs) {
                    Text("KARTTA NELER GÖRÜNSÜN").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                    fieldToggle("Hedef halkası", field: .goal)
                    fieldToggle("Ders dağılımı", field: .subjects)
                    fieldToggle("Seri (kaç gün üst üste)", field: .streak)
                }
                Text("Kart yazı alanına konur; sen göndere basana kadar kimseye gitmez.")
                    .fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
                ShareActionButton(title: "Kartı hazırla") { actions.insert(model.studyMessage()) }
            }
        }
    }

    private func fieldToggle(_ title: String, field: StudyShareCard.Fields) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: { model.fields.contains(field) },
                set: { isOn in
                    if isOn { model.fields.insert(field) } else { model.fields.remove(field) }
                })
        )
        .fokusTextStyle(.body)
        .frame(minHeight: fokusMinTapTarget)
    }
}

// MARK: - Oda daveti

struct RoomComposeView: View {
    let model: MessagesModel
    let actions: MessagesActions

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.lg) {
            RoomInviteCardView(invite: model.draftInvite)
                .frame(maxWidth: .infinity)
            DatePicker("Başlangıç saati", selection: Bindable(model).startTime, displayedComponents: .hourAndMinute)
                .fokusTextStyle(.body)
                .frame(minHeight: fokusMinTapTarget)
            VStack(alignment: .leading, spacing: FokusSpacing.sm) {
                Text("SÜRE").fokusTextStyle(.eyebrow).foregroundStyle(.fkSecondaryLabel)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FokusSpacing.sm) {
                        ForEach(RoomInvite.durationOptions, id: \.self) { minutes in durationChip(minutes) }
                    }
                }
            }
            Text("Arkadaşların \"Katıl\"a basınca Fokus açılır; odağı herkes kendisi başlatır. Katılanlar kartta görünür.")
                .fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
            ShareActionButton(title: "Daveti hazırla") { actions.insert(model.newInviteMessage()) }
        }
    }

    private func durationChip(_ minutes: Int) -> some View {
        let selected = model.durationMinutes == minutes
        return Button {
            model.durationMinutes = minutes
        } label: {
            Text("\(minutes) dk")
                .fokusTextStyle(.callout)
                .foregroundStyle(selected ? FokusColor(.background) : FokusColor(.label))
                .padding(.horizontal, FokusSpacing.lg)
                .frame(minHeight: fokusMinTapTarget)
                .background(selected ? FokusColor(.label) : FokusColor(.fill), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Seçili oda mesajı

struct RoomDetailView: View {
    let model: MessagesModel
    let actions: MessagesActions
    let invite: RoomInvite

    private var hasJoined: Bool { invite.participants.contains { $0.id == model.participantId } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.lg) {
                RoomInviteCardView(invite: invite).frame(maxWidth: .infinity)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(phaseText(invite.phase(now: context.date)))
                        .fokusTextStyle(.title3).foregroundStyle(.fkLabel)
                }
                if model.joinMessageInserted {
                    Text("Mesaj hazır. Gönder'e basınca oda kartı herkes için güncellenir.")
                        .fokusTextStyle(.footnote).foregroundStyle(.fkAccentInk)
                }
                if let error = model.errorText {
                    Text(error).fokusTextStyle(.footnote).foregroundStyle(.fkDanger)
                }
                if invite.phase(now: .now) != .ended {
                    if hasJoined && !model.joinMessageInserted {
                        Text("Bu odadasın.").fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                    } else if !hasJoined {
                        ShareActionButton(title: "Katıl") {
                            if let message = model.joinMessage() { actions.insert(message) }
                        }
                    }
                    Button {
                        actions.open(invite.url)
                    } label: {
                        Text("Fokus'ta aç")
                            .fokusTextStyle(.headline).foregroundStyle(.fkLabel)
                            .frame(maxWidth: .infinity, minHeight: fokusMinTapTarget)
                            .overlay(Capsule().stroke(.fkSeparatorStrong, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(FokusSpacing.lg)
        }
    }

    private func phaseText(_ phase: RoomInvite.Phase) -> String {
        switch phase {
        case .upcoming(let seconds): "Başlamasına \(SocialFormat.formatClock(seconds * 1000))"
        case .live(let seconds): "Sürüyor · \(SocialFormat.formatClock(seconds * 1000)) kaldı"
        case .ended: "Bu oda bitti"
        }
    }
}
