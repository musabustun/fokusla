import FokusDesign
import SwiftUI

/// Dokunulabilir ayar satırı. `isDestructive` ise başlık tehlike renginde (web `text-danger`).
struct SettingsButtonRow: View {
    let title: String
    var subtitle: String?
    var value: String?
    var isDestructive = false
    var showsChevron = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isDestructive {
                VStack(spacing: 0) {
                    HStack {
                        Text(title).fokusTextStyle(.body).foregroundStyle(.fkDanger)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: fokusMinTapTarget)
                    .padding(.vertical, FokusSpacing.md)
                    Divider().overlay(.fkSeparator)
                }
                .contentShape(Rectangle())
            } else {
                LineRow(title, subtitle: subtitle, value: value, showsChevron: showsChevron)
            }
        }
        .buttonStyle(.fokusRow)
    }
}

/// Açma/kapama satırı.
struct SettingsToggleRow: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        LineRow(title, subtitle: subtitle) {
            Toggle(title, isOn: $isOn).labelsHidden()
        }
        .accessibilityElement(children: .contain)
    }
}

/// Bölüm altında gösterilen hata/bilgi metni.
struct SettingsMessage: View {
    let text: String
    var isError = false

    var body: some View {
        Text(text)
            .fokusTextStyle(.footnote)
            .foregroundStyle(isError ? .fkDanger : .fkSecondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
