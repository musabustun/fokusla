import FokusData
import FokusDomain
import Foundation
import SwiftData

/// UI testleri ve ekran görüntüleri için örnek kitap verisi (yalnızca DEBUG + `-FokusUITestMode`).
/// `-FokusUITestBooksSeed demo` → devam eden, biten, arşivli, ilerlemesiz ve toplamı bilinmeyen kitaplar.
enum BooksUITestSeed {
    static let argumentKey = "FokusUITestBooksSeed"

    @MainActor
    static func applyIfRequested(context: ModelContext, now: Date = .now) {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-FokusUITestMode"), UserDefaults.standard.string(forKey: argumentKey) == "demo"
        else { return }
        let books = EntityStore<Book>(context: context)
        guard (try? books.all().isEmpty) == true else { return }
        let progress = EntityStore<BookProgress>(context: context)
        let subjects = (try? EntityStore<Subject>(context: context).all()) ?? []
        func subject(_ prefix: String, exam: ExamType) -> UUID? {
            subjects.first { $0.exam == exam && $0.name.hasPrefix(prefix) }?.id
        }
        let calendar = Calendar.current
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: now) ?? now
        }
        func add(
            _ title: String, publisher: String? = nil, kind: BookKind, subjectId: UUID? = nil,
            unit: BookUnit, total: Int?, archived: Bool = false, entries: [(days: Int, reached: Int, note: String?)]
        ) {
            let created = daysAgo((entries.map(\.days).max() ?? 0) + 1)
            let book = books.insert(
                Book(
                    title: title, publisher: publisher, kind: kind, subjectId: subjectId,
                    exam: nil, unit: unit, totalUnits: total, archivedAt: archived ? daysAgo(1) : nil),
                now: created)
            for entry in entries {
                progress.insert(
                    BookProgress(
                        bookId: book.id, reachedUnit: entry.reached, recordedAt: daysAgo(entry.days),
                        note: entry.note),
                    now: daysAgo(entry.days))
            }
        }
        let math = subject("Matematik", exam: .tyt)
        let physics = subject("Fizik", exam: .tyt)
        add(
            "TYT Matematik Soru Bankası", publisher: "Bilgi Sarmal", kind: .questionBank, subjectId: math,
            unit: .test, total: 120,
            entries: [(10, 20, nil), (5, 45, "Problemler zordu"), (1, 74, nil)])
        add(
            "Fizik Konu Anlatımı", publisher: "Palme", kind: .lecture, subjectId: physics, unit: .page,
            total: 320, entries: [(12, 80, nil), (6, 110, nil), (2, 150, nil)])
        add(
            "TYT Matematik Denemeleri", publisher: "3D", kind: .practiceExam, subjectId: math, unit: .test,
            total: 40, entries: [(9, 12, nil), (0, 40, "Hepsi bitti")])
        add(
            "Paragraf Soru Bankası", kind: .questionBank, unit: .section, total: nil,
            entries: [(3, 8, nil)])
        add("Kimya Soru Bankası", kind: .questionBank, unit: .test, total: 90, entries: [])
        add(
            "Eski Geometri Fasikülü", kind: .other, subjectId: math, unit: .page, total: 60, archived: true,
            entries: [(20, 25, nil)])
        try? books.save()
        #endif
    }
}
