import FokusDesign
import FokusDomain
import SwiftUI

/// Geçmiş listesindeki bir satır (görünüme hazır).
struct FocusHistoryRow: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let focusMs: Double
}

/// Son bitmiş oturumlar (en yeni önce).
struct FocusHistorySection: View {
    let rows: [FocusHistoryRow]

    var body: some View {
        LineSection("Geçmiş oturumlar") {
            if rows.isEmpty {
                LineRow("Henüz tamamlanmış oturum yok")
            } else {
                ForEach(rows) { row in
                    LineRow(row.title, subtitle: row.subtitle, value: FocusFormat.durationText(row.focusMs))
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("focus.history.row")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focus.history")
    }
}
