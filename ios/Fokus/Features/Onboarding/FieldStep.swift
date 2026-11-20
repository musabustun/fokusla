import FokusDesign
import FokusDomain
import SwiftUI

/// YKS alanı seçimi (tek seçim; seçilmeden Devam kapalı).
struct FieldStep: View {
    @Binding var selection: YksField?
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        OnboardingStepLayout(
            title: "Alanın hangisi?",
            subtitle: "Derslerin ve konuların buna göre hazırlanır.",
            brand: false
        ) {
            LineSection {
                ForEach(YksField.allCases, id: \.self) { field in
                    FieldRow(field: field, isSelected: selection == field) { selection = field }
                }
            }
        } actions: {
            Button("Devam", action: onNext)
                .buttonStyle(.fokusPrimary)
                .disabled(selection == nil)
                .accessibilityIdentifier("onboarding.continue")
            Button("Geri", action: onBack)
                .buttonStyle(.plain)
                .font(.headline)
                .foregroundStyle(.fkSecondaryLabel)
                .frame(minHeight: fokusMinTapTarget)
                .accessibilityIdentifier("onboarding.back")
        }
    }
}

private struct FieldRow: View {
    let field: YksField
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: FokusSpacing.md) {
                    Text(field.shortLabel)
                        .fokusTextStyle(.numeralSM)
                        .foregroundStyle(isSelected ? .fkAccentInk : .fkSecondaryLabel)
                        .frame(minWidth: 44, alignment: .leading)
                    VStack(alignment: .leading, spacing: FokusSpacing.xs) {
                        Text(field.label).font(.headline).foregroundStyle(.fkLabel)
                        Text(field.summary).font(.subheadline).foregroundStyle(.fkSecondaryLabel)
                    }
                    Spacer(minLength: FokusSpacing.sm)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? .fkAccentInk : .fkSeparatorStrong)
                }
                .padding(.vertical, FokusSpacing.lg)
                .frame(minHeight: fokusMinTapTarget)
                Divider().overlay(.fkSeparator)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("onboarding.field.\(field.rawValue)")
    }
}

#Preview {
    @Previewable @State var selection: YksField? = .say
    FieldStep(selection: $selection, onNext: {}, onBack: {}).fokusTheme()
}
