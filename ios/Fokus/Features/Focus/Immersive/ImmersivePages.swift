import FokusDesign
import FokusDomain
import SwiftUI

/// Açık oturumun ders/konu bilgisi (kronometre ve "Ders" kartı kullanır).
struct ImmersiveSubjectInfo: Equatable {
    var exam: String
    var name: String
    var topic: String?

    /// "TYT · Matematik · Türev" biçiminde tek satır.
    var line: String { [exam, name, topic].compactMap { $0 }.joined(separator: " · ") }
}

/// Sayfaların ortak girdisi (tüm değerler dışarıdan gelir; sayfalar saf görünümdür).
@MainActor
struct ImmersivePageContext {
    var snapshot: ImmersiveSnapshot
    var subject: ImmersiveSubjectInfo?
    var now: Date
    /// Ekranın güvenli alan boşlukları (sayfalar kenarlara kadar uzanır, içerik bunlara göre dizilir).
    var insets: EdgeInsets
    /// Altta sayfa göstergesi ve (sabitlenmişse) kontrol çubuğu için ayrılan yükseklik.
    var bottomReserve: CGFloat
    var clockStyle: StandByClockStyle = .mono
    /// Büyük rakamların rengi (molada success, tintedDigits açıksa accentInk, aksi halde label).
    var digitColor: FokusColor = FokusColor(.label)
    var isNight = false
    /// Günlük odak hedefi (dakika); `nil` = kapalı.
    var dailyGoalMinutes: Int?
    var music = ImmersiveMusic.none
    /// Tam ekran tercihleri (müzik widget'ı ve köşe çipi hangi sayfada çıkar?).
    var preferences = StandByPreferences.default
    /// Müzik widget'ının yan/alt bölgesi içerik alanını daralttı: sayfalar yatay "geniş" düzen yerine kompakt
    /// (dikey yığın) düzeni seçer.
    var isCompactColumn = false
    /// Köşe çipi satırı için üstte ayrılan ek yükseklik (çip sayfa içeriğinin üstüne binmesin).
    var chipTopReserve: CGFloat = 0

    /// Bu sayfada müzik widget'ı (iki bölgeli düzen) çizilsin mi?
    func showsMusicWidget(on page: StandByPage) -> Bool {
        preferences.showsMusicWidget(on: page, isMusicAvailable: music.isAvailable)
    }

    /// Bu sayfa köşe çipine yer ayırmalı mı? (Kronometre başlığı kendi boşluğunu zaten ayırır.)
    func reservesChipRow(on page: StandByPage) -> Bool {
        page != .stopwatch && preferences.showsChip(on: page, isMusicAvailable: music.isAvailable)
    }

    /// Köşe çipi bu sayfada görünüyorsa üstte çip satırı kadar yer ayrılmış kopya.
    func reservingChipRow(on page: StandByPage) -> ImmersivePageContext {
        var copy = self
        copy.chipTopReserve = reservesChipRow(on: page) ? fokusMinTapTarget + FokusSpacing.sm : 0
        return copy
    }

    var contentPadding: EdgeInsets {
        EdgeInsets(
            top: max(insets.top, FokusSpacing.lg) + chipTopReserve,
            leading: max(insets.leading, FokusSpacing.xl),
            bottom: insets.bottom + bottomReserve,
            trailing: max(insets.trailing, FokusSpacing.xl))
    }

    /// Düzenleme önizlemesi: kenar boşlukları ve alt rezerv sıfır, yalnızca iç boşluk.
    func forPreview() -> ImmersivePageContext {
        var copy = self
        copy.insets = EdgeInsets()
        copy.bottomReserve = 0
        return copy
    }
}

extension FocusTimerPhase {
    var immersivePhaseColor: FokusColor {
        switch self {
        case .idle: FokusColor(.secondaryLabel)
        case .focus: FokusColor(.accentInk)
        case .break: FokusColor(.success)
        }
    }
}

/// Faz etiketi: odakta vurgu noktası + "ODAK", molada "MOLA" (mola tonu).
struct ImmersivePhaseLabel: View {
    let phase: FocusTimerPhase
    var isDimmed = false

    var body: some View {
        HStack(spacing: FokusSpacing.sm) {
            if phase == .focus {
                Circle().fill(.fkAccent).frame(width: 6, height: 6).accessibilityHidden(true)
            }
            Text(phase.label)
                .fokusTextStyle(.eyebrow)
                .foregroundStyle(phase.immersivePhaseColor)
                .accessibilityIdentifier("immersive.phase")
        }
        .opacity(isDimmed ? 0.45 : 1)
    }
}

/// İkincil satır: "Bugün 2 sa 10 dk" / "Oturum 25 dk" (küçük, büyük sayacın altında).
struct ImmersiveSecondaryLine: View {
    let secondary: ImmersiveSnapshot.Secondary?
    var isDimmed = false

    var body: some View {
        Group {
            if let secondary {
                Text("\(secondary.label) \(FocusFormat.durationText(secondary.ms))")
                    .fokusTextStyle(.subheadline)
                    .foregroundStyle(.fkSecondaryLabel)
                    .lineLimit(1)
                    .opacity(isDimmed ? 0.5 : 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(secondary.label)
                    .accessibilityValue(FocusFormat.durationText(secondary.ms))
                    .accessibilityIdentifier("immersive.secondary")
            } else {
                Text(" ").fokusTextStyle(.subheadline).accessibilityHidden(true)
            }
        }
        .frame(minHeight: 20)
    }
}

/// Süre değeri için VoiceOver ve test öğesi (`immersive.clock`).
private struct ImmersiveClockAccessibility: ViewModifier {
    let phase: FocusTimerPhase
    let ms: Double

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(phase == .break ? "Mola süresi" : "Oturum süresi")
            .accessibilityValue(FocusFormat.clock(ms))
            .accessibilityAddTraits(phase.isRunning ? .updatesFrequently : [])
            .accessibilityIdentifier("immersive.clock")
    }
}

extension View {
    func immersiveClockAccessibility(phase: FocusTimerPhase, ms: Double) -> some View {
        modifier(ImmersiveClockAccessibility(phase: phase, ms: ms))
    }

    /// Sayfa kapsayıcısı: önce `.contain`, sonra `immersive.page.<raw>` kimliği.
    func immersivePageContainer(_ page: StandByPage) -> some View {
        accessibilityElement(children: .contain).accessibilityIdentifier(page.accessibilityIdentifier)
    }
}

/// Üstte ortalanmış küçük gerçek saat + tarih (köşe çipi ve düğmelerle çakışmaz).
struct ImmersiveClockHeader: View {
    let now: Date
    var isDimmed = false

    private static let turkish = Locale(identifier: "tr_TR")

    var body: some View {
        VStack(spacing: 2) {
            Text(now, format: .dateTime.hour().minute().locale(Self.turkish))
                .fokusTextStyle(.numeralSM)
                .foregroundStyle(.fkLabel)
            Text(now, format: .dateTime.weekday(.wide).day().month(.wide).locale(Self.turkish))
                .fokusTextStyle(.caption)
                .foregroundStyle(.fkSecondaryLabel)
        }
        .opacity(isDimmed ? 0.5 : 1)
        .frame(maxWidth: .infinity, minHeight: fokusMinTapTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Saat")
        .accessibilityValue(
            Text(now, format: .dateTime.hour().minute().weekday(.wide).day().month(.wide).locale(Self.turkish)))
    }
}
