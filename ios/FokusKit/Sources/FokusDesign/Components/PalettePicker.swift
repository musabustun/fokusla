import SwiftUI

/// Bir paletin küçük canlı önizlemesi (web `PalettePreview`): o paletin zemini, ilerleme halkası
/// ve ana düğme hapı. Paleti yalnızca bu kutu için ortama yazar; ham renk yok. Dekoratiftir.
public struct PalettePreview: View {
    private let palette: FokusPalette

    public init(palette: FokusPalette) {
        self.palette = palette
    }

    public var body: some View {
        HStack {
            ProgressRing(progress: 0.66, lineWidth: 4)
                .frame(width: 36, height: 36)
            Spacer(minLength: FokusSpacing.sm)
            VStack(alignment: .trailing, spacing: 6) {
                Capsule().fill(.fkSeparatorStrong).frame(width: 32, height: 4)
                Capsule().fill(.fkAccent).frame(width: 48, height: 16)
            }
        }
        .padding(FokusSpacing.md)
        .background(.fkBackground, in: RoundedRectangle(cornerRadius: FokusRadius.md))
        .overlay(RoundedRectangle(cornerRadius: FokusRadius.md).strokeBorder(.fkSeparator, lineWidth: 1))
        .environment(\.fokusPalette, palette)
        .accessibilityHidden(true)
    }
}

/// Renk teması (palet) seçici (web `PalettePicker`): her palet adı ve canlı önizlemesiyle bir
/// seçenek; iPhone'da 2, iPad'de 3 sütun. Seçim anında `selection`'a yazılır.
public struct PalettePicker: View {
    @Binding private var selection: FokusPalette
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(selection: Binding<FokusPalette>) {
        _selection = selection
    }

    public var body: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: FokusSpacing.md),
            count: sizeClass == .regular ? 3 : 2
        )
        LazyVGrid(columns: columns, spacing: FokusSpacing.md) {
            ForEach(FokusPalette.allCases) { palette in
                option(palette)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Renk teması")
    }

    private func option(_ palette: FokusPalette) -> some View {
        let isSelected = palette == selection
        return Button {
            if reduceMotion {
                selection = palette
            } else {
                withAnimation(FokusMotion.baseAnimation) { selection = palette }
            }
        } label: {
            VStack(alignment: .leading, spacing: FokusSpacing.sm) {
                PalettePreview(palette: palette)
                HStack {
                    Text(palette.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.fkLabel)
                    Spacer(minLength: FokusSpacing.xs)
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.fkAccentInk)
                        .opacity(isSelected ? 1 : 0)
                }
                .padding(.horizontal, FokusSpacing.xs)
            }
            .padding(FokusSpacing.sm)
            .frame(minHeight: fokusMinTapTarget)
            .background(
                isSelected ? AnyShapeStyle(.fkFill) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: FokusRadius.lg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: FokusRadius.lg)
                    .strokeBorder(isSelected ? FokusColor(.accentInk) : FokusColor(.separator), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: FokusRadius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(palette.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("palette.\(palette.rawValue)")
    }
}

#Preview("Koyu") {
    @Previewable @State var palette = FokusPalette.default
    FokusPreviewCanvas(.dark) { PalettePicker(selection: $palette) }
}

#Preview("Açık") {
    @Previewable @State var palette = FokusPalette.strawberry
    FokusPreviewCanvas(.light) { PalettePicker(selection: $palette) }
}
