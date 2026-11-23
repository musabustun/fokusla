import SwiftUI

/// "Yazı" sekmesi: sayaç yazı tipi karoları.
struct StandByEditorClockTab: View {
    @Binding var preferences: StandByPreferences

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FokusSpacing.md) {
                ForEach(StandByClockStyle.allCases) { style in tile(style) }
            }
            .padding(.vertical, FokusSpacing.xs)
        }
    }

    private func tile(_ style: StandByClockStyle) -> some View {
        let isSelected = preferences.clockStyle == style
        return Button {
            preferences = preferences.with(\.clockStyle, style)
        } label: {
            VStack(spacing: FokusSpacing.sm) {
                Text("12:34").font(style.font(size: 34)).foregroundStyle(.fkLabel).lineLimit(1)
                HStack(spacing: FokusSpacing.xs) {
                    Text(style.displayName).font(.footnote).foregroundStyle(.fkSecondaryLabel)
                    if isSelected {
                        Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(.fkAccentInk)
                    }
                }
            }
            .padding(FokusSpacing.md)
            .frame(minWidth: 120, minHeight: fokusMinTapTarget)
            .standByEditorTileBackground(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("immersive.editor.clock.\(style.rawValue)")
    }
}

/// "Renk" sekmesi: uygulama paleti + tüm paletler ve rakam tonu anahtarı.
struct StandByEditorColorTab: View {
    @Binding var preferences: StandByPreferences
    let appPalette: FokusPalette

    private static let swatchSize: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.lg) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FokusSpacing.md) {
                    swatch(palette: appPalette, accent: nil, label: "Uygulama", id: "app", isApp: true)
                    ForEach(FokusPalette.allCases) { palette in
                        swatch(palette: palette, accent: palette, label: palette.displayName, id: palette.rawValue, isApp: false)
                    }
                }
                .padding(FokusSpacing.xs)
            }
            Toggle(
                "Rakamlar vurgu renginde",
                isOn: Binding(
                    get: { preferences.tintedDigits },
                    set: { preferences = preferences.with(\.tintedDigits, $0) })
            )
            .tint(FokusColor(.accent))
            .frame(minHeight: fokusMinTapTarget)
            .accessibilityIdentifier("immersive.editor.tintedDigits")
        }
    }

    private func swatch(palette: FokusPalette, accent: FokusPalette?, label: String, id: String, isApp: Bool) -> some View {
        let isSelected = preferences.accent == accent
        return Button {
            preferences = preferences.with(\.accent, accent)
        } label: {
            ZStack {
                Circle().fill(FokusColor.color(.accent, palette: palette))
                if isApp {
                    Image(systemName: "sparkle").font(.footnote.weight(.bold)).foregroundStyle(.fkAccentContrast)
                }
            }
            .frame(width: Self.swatchSize, height: Self.swatchSize)
            .padding(FokusSpacing.xs)
            .overlay(Circle().strokeBorder(isSelected ? AnyShapeStyle(.fkLabel) : AnyShapeStyle(.clear), lineWidth: 2))
            .frame(minWidth: fokusMinTapTarget, minHeight: fokusMinTapTarget)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("immersive.editor.accent.\(id)")
    }
}

/// "Zemin" sekmesi: zemin karoları ve gece kırmızısı seçimi.
struct StandByEditorBackdropTab: View {
    @Binding var preferences: StandByPreferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.lg) {
                HStack(spacing: FokusSpacing.sm) {
                    ForEach(StandByBackdrop.allCases) { backdrop in tile(backdrop) }
                }
                VStack(alignment: .leading, spacing: FokusSpacing.sm) {
                    Text("Gece kırmızısı").font(.headline).foregroundStyle(.fkLabel)
                    nightChoice
                    Text("Otomatik: 22.00–07.00").font(.footnote).foregroundStyle(.fkSecondaryLabel)
                }
            }
        }
    }

    private func tile(_ backdrop: StandByBackdrop) -> some View {
        let isSelected = preferences.backdrop == backdrop
        return Button {
            preferences = preferences.with(\.backdrop, backdrop)
        } label: {
            VStack(spacing: FokusSpacing.xs) {
                StandByBackdropSwatch(backdrop: backdrop)
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: FokusRadius.sm))
                Text(backdrop.displayName).font(.footnote).foregroundStyle(.fkLabel).lineLimit(1)
            }
            .padding(FokusSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: fokusMinTapTarget)
            .standByEditorTileBackground(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(backdrop.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("immersive.editor.backdrop.\(backdrop.rawValue)")
    }

    private var nightChoice: some View {
        HStack(spacing: FokusSpacing.xs) {
            ForEach(StandByNightMode.allCases) { mode in
                let isSelected = preferences.nightMode == mode
                Button {
                    preferences = preferences.with(\.nightMode, mode)
                } label: {
                    Text(mode.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .fkAccentContrast : .fkLabel)
                        .frame(maxWidth: .infinity, minHeight: fokusMinTapTarget)
                        .background(Capsule().fill(isSelected ? .fkAccent : .fkFill))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("immersive.editor.night.\(mode.rawValue)")
            }
        }
    }
}

/// Zemin türünün küçük, durağan önizlemesi (yalnızca basit şekiller).
private struct StandByBackdropSwatch: View {
    let backdrop: StandByBackdrop
    @Environment(\.fokusPalette) private var palette

    var body: some View {
        ZStack {
            switch backdrop {
            case .plain:
                Rectangle().fill(.fkBackground)
            case .gradient:
                Rectangle().fill(.fkBackground)
                Rectangle().fill(RadialGradient(
                    colors: [FokusColor.color(.accent, palette: palette).opacity(0.35), .clear],
                    center: .center, startRadius: 0, endRadius: 60))
            case .aura:
                Rectangle().fill(.fkBackground)
                Circle().fill(.fkAccent.opacity(0.4)).frame(width: 36).blur(radius: 10).offset(x: -18, y: -6)
                Circle().fill(.fkAccentSubtle).frame(width: 30).blur(radius: 10).offset(x: 20, y: 8)
            case .black:
                // Gerçek siyahı temsil eder: token kuralının tek istisnası (OLED zemini).
                Color.black
            }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// Düzenleyici karosu zemini: seçiliyse vurgu çizgisi, değilse ince ayraç.
    func standByEditorTileBackground(isSelected: Bool) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: FokusRadius.md).fill(.fkSurface))
            .overlay(
                RoundedRectangle(cornerRadius: FokusRadius.md)
                    .strokeBorder(isSelected ? AnyShapeStyle(.fkAccent) : AnyShapeStyle(.fkSeparator), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: FokusRadius.md))
    }
}
