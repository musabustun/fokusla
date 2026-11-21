import FokusAudio
import FokusDesign
import Observation
import SwiftUI

/// Tam ekran odağın "ses" sayfasındaki odak sesleri bölümü: 5 ses türü, ses seviyesi, uyku
/// zamanlayıcısı ve "diğer seslerle karıştır" anahtarı. Yalnızca `FocusSoundControlling`
/// sözleşmesine bağlıdır (gerçek uygulama `FocusSoundPlayer`; önizlemede sahte uygulama).
struct FocusSoundSection: View {
    let sound: any FocusSoundControlling

    /// Menüde en son seçilen hazır süre (onay işareti için); zamanlayıcı yoksa yok sayılır.
    @State private var selectedSleepMinutes: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.xl) {
            LineSection("Odak sesleri") {
                ForEach(FocusSoundKind.allCases) { kind in
                    FocusSoundKindRow(
                        kind: kind,
                        isSelected: sound.currentKind == kind,
                        isPlaying: sound.currentKind == kind && sound.isPlaying
                    ) {
                        if sound.currentKind == kind && sound.isPlaying {
                            sound.stop()
                        } else {
                            sound.play(kind)
                        }
                    }
                }
            }

            LineSection {
                volumeRow
                sleepTimerRow
                mixRow
            }

            if let message = sound.errorMessage {
                Text(message)
                    .fokusTextStyle(.footnote)
                    .foregroundStyle(.fkDanger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("sound.error")
            }
        }
    }

    // MARK: Ses seviyesi

    private var volumeRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: FokusSpacing.md) {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(.fkSecondaryLabel)
                    .accessibilityHidden(true)
                Slider(
                    value: Binding(get: { sound.volume }, set: { sound.volume = $0 }),
                    in: 0...1
                )
                .tint(FokusColor(.accent))
                .frame(minHeight: fokusMinTapTarget)
                .accessibilityLabel("Ses seviyesi")
                .accessibilityValue("Yüzde \(Int((sound.volume * 100).rounded()))")
                .accessibilityIdentifier("sound.volume")
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(.fkSecondaryLabel)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: fokusMinTapTarget)
            .padding(.vertical, FokusSpacing.sm)
            Divider().overlay(.fkSeparator)
        }
    }

    // MARK: Uyku zamanlayıcısı

    private var hasActiveSound: Bool { sound.currentKind != nil }

    private var sleepTimerRow: some View {
        VStack(spacing: 0) {
            Menu {
                Button {
                    selectedSleepMinutes = nil
                    sound.setSleepTimer(minutes: nil)
                } label: {
                    if sound.sleepTimerEndsAt == nil {
                        Label("Kapalı", systemImage: "checkmark")
                    } else {
                        Text("Kapalı")
                    }
                }
                ForEach(SleepTimerPresets.minutes, id: \.self) { minutes in
                    Button {
                        selectedSleepMinutes = minutes
                        sound.setSleepTimer(minutes: minutes)
                    } label: {
                        if sound.sleepTimerEndsAt != nil && selectedSleepMinutes == minutes {
                            Label("\(minutes) dakika", systemImage: "checkmark")
                        } else {
                            Text("\(minutes) dakika")
                        }
                    }
                }
            } label: {
                HStack(spacing: FokusSpacing.md) {
                    Text("Uyku zamanlayıcısı")
                        .fokusTextStyle(.body)
                        .foregroundStyle(.fkLabel)
                    Spacer(minLength: FokusSpacing.sm)
                    SleepTimerValueText(endsAt: sound.sleepTimerEndsAt)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.fkTertiaryLabel)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: fokusMinTapTarget)
                .padding(.vertical, FokusSpacing.md)
                .contentShape(Rectangle())
            }
            .disabled(!hasActiveSound)
            .opacity(hasActiveSound ? 1 : 0.4)
            .accessibilityLabel("Uyku zamanlayıcısı")
            .accessibilityValue(SleepTimerFormat.spoken(endsAt: sound.sleepTimerEndsAt, now: .now))
            .accessibilityHint(hasActiveSound ? "Süre seçmek için çift dokun" : "Önce bir ses başlat")
            .accessibilityIdentifier("sound.sleepTimer")
            Divider().overlay(.fkSeparator)
        }
    }

    // MARK: Karıştırma

    private var mixRow: some View {
        VStack(spacing: 0) {
            Toggle(
                isOn: Binding(get: { sound.mixesWithOtherAudio }, set: { sound.mixesWithOtherAudio = $0 })
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Diğer seslerle karıştır")
                        .fokusTextStyle(.body)
                        .foregroundStyle(.fkLabel)
                    Text("Spotify gibi uygulamalarla birlikte çalar")
                        .fokusTextStyle(.subheadline)
                        .foregroundStyle(.fkSecondaryLabel)
                }
            }
            .tint(FokusColor(.accent))
            .frame(minHeight: fokusMinTapTarget)
            .padding(.vertical, FokusSpacing.md)
            .accessibilityIdentifier("sound.mix")
            Divider().overlay(.fkSeparator)
        }
    }
}

// MARK: - Ses türü satırı

private struct FocusSoundKindRow: View {
    let kind: FocusSoundKind
    let isSelected: Bool
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: FokusSpacing.md) {
                    Image(systemName: kind.symbolName)
                        .font(.title3)
                        .foregroundStyle(isSelected ? FokusColor(.accent) : FokusColor(.secondaryLabel))
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title)
                            .fokusTextStyle(.body)
                            .foregroundStyle(isSelected ? FokusColor(.accentInk) : FokusColor(.label))
                        Text(kind.subtitle)
                            .fokusTextStyle(.subheadline)
                            .foregroundStyle(.fkSecondaryLabel)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: FokusSpacing.sm)
                    if isSelected {
                        Image(systemName: isPlaying ? "checkmark.circle.fill" : "pause.circle")
                            .foregroundStyle(.fkAccent)
                            .accessibilityHidden(true)
                    }
                }
                .frame(minHeight: fokusMinTapTarget)
                .padding(.vertical, FokusSpacing.md)
                Divider().overlay(.fkSeparator)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.fokusRow)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.title). \(kind.subtitle)")
        .accessibilityValue(isPlaying ? "Çalıyor" : (isSelected ? "Duraklatıldı" : "Kapalı"))
        .accessibilityHint(isPlaying ? "Durdurmak için çift dokun" : "Çalmak için çift dokun")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("sound.kind.\(kind.rawValue)")
    }
}

// MARK: - Kalan süre

/// Kalan süreyi dakikada bir tazeleyen metin ("23 dk kaldı" / "Kapalı").
private struct SleepTimerValueText: View {
    let endsAt: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            Text(SleepTimerFormat.short(endsAt: endsAt, now: context.date))
                .font(.body)
                .foregroundStyle(.fkSecondaryLabel)
        }
    }
}

/// Uyku zamanlayıcısı metinleri (Türkçe).
enum SleepTimerFormat {
    /// Kalan dakika (yukarı yuvarlanır; en az 1). Zamanlayıcı yoksa `nil`.
    static func remainingMinutes(endsAt: Date?, now: Date) -> Int? {
        guard let endsAt else { return nil }
        let seconds = endsAt.timeIntervalSince(now)
        guard seconds > 0 else { return 0 }
        return max(1, Int((seconds / 60).rounded(.up)))
    }

    static func short(endsAt: Date?, now: Date) -> String {
        guard let minutes = remainingMinutes(endsAt: endsAt, now: now) else { return "Kapalı" }
        return minutes == 0 ? "Bitiyor" : "\(minutes) dk kaldı"
    }

    static func spoken(endsAt: Date?, now: Date) -> String {
        guard let minutes = remainingMinutes(endsAt: endsAt, now: now) else { return "Kapalı" }
        return minutes == 0 ? "Bitiyor" : "\(minutes) dakika kaldı"
    }
}

// MARK: - Önizleme

/// Yalnızca önizleme: ses üretmeyen, durumu tutan sahte uygulama.
@MainActor
@Observable
private final class PreviewFocusSound: FocusSoundControlling {
    var currentKind: FocusSoundKind?
    var isPlaying: Bool
    var volume = 0.5
    var mixesWithOtherAudio = true
    var sleepTimerEndsAt: Date?
    var errorMessage: String?

    init(
        kind: FocusSoundKind? = nil, sleepMinutes: Int? = nil, errorMessage: String? = nil
    ) {
        currentKind = kind
        isPlaying = kind != nil
        sleepTimerEndsAt = sleepMinutes.map { Date().addingTimeInterval(Double($0) * 60) }
        self.errorMessage = errorMessage
    }

    func play(_ kind: FocusSoundKind) {
        currentKind = kind
        isPlaying = true
    }

    func stop() {
        currentKind = nil
        isPlaying = false
        sleepTimerEndsAt = nil
    }

    func setSleepTimer(minutes: Int?) {
        sleepTimerEndsAt = minutes.map { Date().addingTimeInterval(Double($0) * 60) }
    }
}

private struct FocusSoundSectionPreview: View {
    let scheme: ColorScheme
    let palette: FokusPalette
    @State private var sound: PreviewFocusSound

    init(
        _ scheme: ColorScheme, palette: FokusPalette = .default, kind: FocusSoundKind? = .rain,
        sleepMinutes: Int? = 23, errorMessage: String? = nil
    ) {
        FokusFonts.registerAll()
        self.scheme = scheme
        self.palette = palette
        _sound = State(
            initialValue: PreviewFocusSound(kind: kind, sleepMinutes: sleepMinutes, errorMessage: errorMessage))
    }

    var body: some View {
        ScrollView {
            FocusSoundSection(sound: sound)
                .padding(FokusSpacing.screenHorizontal)
        }
        .background(.fkBackground)
        .environment(\.fokusPalette, palette)
        .preferredColorScheme(scheme)
    }
}

#Preview("Odak sesleri — koyu") {
    FocusSoundSectionPreview(.dark)
}

#Preview("Odak sesleri — açık") {
    FocusSoundSectionPreview(.light)
}

#Preview("Odak sesleri — kapalı, hata (koyu, matcha)") {
    FocusSoundSectionPreview(
        .dark, palette: .matcha, kind: nil, sleepMinutes: nil,
        errorMessage: "Ses oturumu açılamadı. Başka bir uygulama sesi kullanıyor olabilir.")
}
