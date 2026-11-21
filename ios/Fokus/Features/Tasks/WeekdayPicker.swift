import FokusDesign
import FokusDomain
import SwiftUI

/// Gün seçici: 7 aç/kapa düğmesi (Pzt…Paz). Web `WeekdayPicker`.
struct WeekdayPicker: View {
    @Binding var selection: [Int]
    var isInvalid = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...7, id: \.self) { weekday in
                let isSelected = selection.contains(weekday)
                Button {
                    selection = TaskDraft.normalizeWeekdays(
                        isSelected ? selection.filter { $0 != weekday } : selection + [weekday])
                } label: {
                    Text(TaskFormatting.weekdayShortName(weekday))
                        .font(.subheadline)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? FokusColor(.accentContrast) : FokusColor(.label))
                        .frame(maxWidth: .infinity, minHeight: fokusMinTapTarget)
                        .background {
                            if isSelected { Capsule().fill(.fkAccent) }
                        }
                        .overlay {
                            Capsule().strokeBorder(
                                isInvalid ? FokusColor(.danger) : FokusColor(.separatorStrong),
                                lineWidth: isSelected ? 0 : 1)
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(TaskFormatting.weekdayLongName(weekday))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("task.form.weekday.\(weekday)")
            }
        }
        .padding(.horizontal, 2)
    }
}
