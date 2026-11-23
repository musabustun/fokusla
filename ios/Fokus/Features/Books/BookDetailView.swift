import FokusData
import FokusDesign
import FokusDomain
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "books")

/// Kitap detayı (web `BookDetailScreen`): ilerleme, hız/tahmin, geçmiş ve eylemler.
/// iPhone'da yığına itilen tam ekran; iPad'de listenin yanındaki panel (`isEmbedded`).
struct BookDetailView: View {
    let bookId: UUID
    let isEmbedded: Bool
    /// Gömülü (iPad) panelde kitap silindikten sonra çağrılır (seçimi temizler). İtilmiş (iPhone)
    /// ekran kendini `dismiss` ile kapatır.
    let onDeleted: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Book> { $0.deletedAt == nil }) private var books: [Book]
    @Query(filter: #Predicate<BookProgress> { $0.deletedAt == nil }) private var progress: [BookProgress]
    @Query(filter: #Predicate<Subject> { $0.deletedAt == nil }) private var subjects: [Subject]
    @Query(filter: #Predicate<BookSection> { $0.deletedAt == nil }) private var sections: [BookSection]
    @Query(filter: #Predicate<Topic> { $0.deletedAt == nil }) private var topics: [Topic]

    @State private var isProgressOpen = false
    @State private var isEditOpen = false
    @State private var isConfirmingDelete = false
    @State private var errorMessage: String?

    var body: some View {
        let now = Date.now
        let data = BooksData(books: books, progress: progress, subjects: subjects, now: now)
        let book = BooksData.deduplicated(books).first { $0.id == bookId }
        Group {
            if let summary = data.summary(for: bookId), let book {
                content(summary: summary, book: book, data: data, now: now)
            } else {
                EmptyStateView(
                    "Kitap bulunamadı", systemImage: "book.closed",
                    message: "Bu kitap silinmiş ya da hiç eklenmemiş olabilir.")
            }
        }
        .background(.fkBackground)
        .accessibilityIdentifier("book.detail")
    }

    // MARK: İçerik

    private func content(summary: BooksCalc.BookSummary, book: Book, data: BooksData, now: Date) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                header(summary: summary, data: data)
                progressCard(summary: summary)
                Button { isProgressOpen = true } label: { Label("İlerleme gir", systemImage: "plus") }
                    .buttonStyle(.fokusPrimary)
                    .accessibilityIdentifier("book.detail.addProgress")
                if let errorMessage {
                    Text(errorMessage).fokusTextStyle(.subheadline).foregroundStyle(.fkDanger)
                        .accessibilityIdentifier("book.detail.error")
                }
                sectionsSection(book: book)
                statsSection(summary: summary, now: now)
                historySection(summary: summary, now: now)
                actionsSection(book: book, isArchived: summary.book.archivedAt != nil)
            }
            .padding(.horizontal, FokusSpacing.screenHorizontal)
            .padding(.vertical, FokusSpacing.lg)
        }
        .sheet(isPresented: $isProgressOpen) {
            BookProgressSheet(summary: summary).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isEditOpen) {
            BookFormView(book: book, subjectGroups: data.subjectGroups)
        }
        .confirmationDialog(
            "Kitabı sil?", isPresented: $isConfirmingDelete, titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) { delete(book) }
                .accessibilityIdentifier("book.detail.confirmDelete")
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Kitap ve tüm ilerleme geçmişi silinecek.")
        }
    }

    private func header(summary: BooksCalc.BookSummary, data: BooksData) -> some View {
        let book = summary.book
        let meta = [BooksFormat.kindLabel(book.kind), book.publisher, data.subjectName(of: summary)]
            .compactMap { $0 }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: FokusSpacing.xs) {
            Text(book.title)
                .fokusTextStyle(isEmbedded ? .title2 : .largeTitle)
                .foregroundStyle(.fkLabel)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("book.detail.title")
            Text(meta).fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
        }
    }

    /// Büyük yüzde (ana öğe), ilerleme çubuğu, "34 / 120 test" ve güncel konum.
    private func progressCard(summary: BooksCalc.BookSummary) -> some View {
        let book = summary.book
        let count = BooksFormat.progressCount(book.unit, reached: summary.reachedUnit, total: book.totalUnits)
        let position = summary.reachedUnit > 0
            ? BooksFormat.position(book.unit, reached: summary.reachedUnit) : "Henüz başlanmadı"
        return VStack(alignment: .leading, spacing: FokusSpacing.lg) {
            Divider().overlay(.fkSeparator)
            HStack(alignment: .firstTextBaseline) {
                Text(summary.ratio.map(BooksFormat.percent) ?? count)
                    .fokusTextStyle(summary.ratio == nil ? .numeralLG : .numeralXL)
                    .foregroundStyle(summary.status == .completed ? FokusColor(.success) : FokusColor(.label))
                    .minimumScaleFactor(0.5).lineLimit(1)
                    .accessibilityIdentifier("book.detail.percent")
                Spacer(minLength: FokusSpacing.sm)
                statusBadge(summary.status)
            }
            if let ratio = summary.ratio {
                ProgressBar(
                    value: ratio, label: "Kitap ilerlemesi",
                    tone: summary.status == .completed ? .success : .accent)
            }
            HStack {
                Text(summary.ratio == nil ? "Toplam bilinmiyor" : count)
                    .fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                Spacer(minLength: FokusSpacing.sm)
                Text(position)
                    .fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                    .accessibilityIdentifier("book.detail.position")
            }
        }
    }

    @ViewBuilder private func statusBadge(_ status: BooksCalc.BookStatus) -> some View {
        switch status {
        case .completed:
            Label(BooksFormat.statusLabel(status), systemImage: "checkmark.circle")
                .fokusTextStyle(.subheadline).fontWeight(.semibold).foregroundStyle(.fkSuccess)
        case .archived:
            Label(BooksFormat.statusLabel(status), systemImage: "archivebox")
                .fokusTextStyle(.subheadline).fontWeight(.semibold).foregroundStyle(.fkSecondaryLabel)
        case .notStarted, .inProgress:
            EmptyView()
        }
    }

    // MARK: Bölümler

    /// Kitabın bölümleri (varsa): başlık, aralık ve bağlı konu adı. Yoksa hiçbir şey göstermez.
    @ViewBuilder private func sectionsSection(book: Book) -> some View {
        let topicNames = Dictionary(
            BooksData.deduplicated(topics).map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let items = BooksData.deduplicated(sections)
            .filter { $0.bookId == book.id }.sorted { $0.order < $1.order }
        if !items.isEmpty {
            LineSection("Bölümler") {
                ForEach(items) { section in
                    let range = BooksFormat.sectionRange(book.unit, start: section.startUnit, end: section.endUnit)
                    let topic = section.topicId.flatMap { topicNames[$0] }
                    let detail = [range, topic].compactMap { $0 }.joined(separator: " · ")
                    LineRow(section.title, subtitle: detail.isEmpty ? nil : detail)
                    .accessibilityIdentifier("book.detail.section")
                }
            }
            .accessibilityIdentifier("book.detail.sections")
        }
    }

    // MARK: Özet

    private func statsSection(summary: BooksCalc.BookSummary, now: Date) -> some View {
        let pace = BooksFormat.pace(summary.book.unit, pacePerWeek: summary.weeklyPace)
        let estimate = estimateText(summary, now: now)
        return LineSection("Özet") {
            statRow(
                Metric(
                    label: "Son ilerleme",
                    value: summary.lastProgressAt.map { BooksFormat.day($0, now: now) } ?? "Henüz yok",
                    size: .md, isNumeric: false))
            statRow(
                Metric(
                    label: "Hız (son 7 gün)", value: pace ?? "Yeterli veri yok", size: .md,
                    isNumeric: pace != nil))
            statRow(
                Metric(
                    label: "Tahmini bitiş", value: estimate.value, caption: estimate.caption, size: .md,
                    isNumeric: false))
        }
    }

    private func statRow(_ metric: Metric) -> some View {
        VStack(spacing: 0) {
            metric
                .padding(.vertical, FokusSpacing.lg).padding(.horizontal, FokusSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider().overlay(.fkSeparator)
        }
    }

    private func estimateText(_ summary: BooksCalc.BookSummary, now: Date) -> (value: String, caption: String?) {
        if summary.status == .completed { return ("Tamamlandı", nil) }
        if summary.ratio == nil { return ("—", "Toplam girilirse hesaplanır") }
        guard let days = summary.daysToFinish else { return ("—", "Hız belli olunca hesaplanır") }
        let day = BooksFormat.day(BooksFormat.addDays(now, days), now: now)
        return ("\(day) (~\(BooksFormat.number(days)) gün)", nil)
    }

    // MARK: Geçmiş

    private func historySection(summary: BooksCalc.BookSummary, now: Date) -> some View {
        let entries = BooksData.history(of: bookId, in: progress)
        let unit = summary.book.unit
        return LineSection("Geçmiş") {
            if entries.isEmpty {
                LineRow("Henüz ilerleme girmedin.")
            }
            ForEach(entries) { entry in
                let position = BooksFormat.position(unit, reached: entry.reachedUnit)
                let day = BooksFormat.day(entry.recordedAt, now: now)
                LineRow(position, subtitle: entry.note.map { "\(day) · \($0)" } ?? day) {
                    Button { deleteEntry(entry) } label: {
                        Image(systemName: "trash").foregroundStyle(.fkDanger)
                            .frame(width: fokusMinTapTarget, height: fokusMinTapTarget)
                    }
                    .padding(.trailing, -FokusSpacing.md)
                    .accessibilityLabel("\(position) kaydını sil")
                    .accessibilityIdentifier("book.history.delete")
                }
            }
        }
    }

    // MARK: Eylemler

    private func actionsSection(book: Book, isArchived: Bool) -> some View {
        LineSection {
            actionRow("Düzenle", systemImage: "pencil", id: "book.detail.edit") { isEditOpen = true }
            actionRow(
                isArchived ? "Raftan geri al" : "Rafa kaldır",
                systemImage: isArchived ? "arrow.uturn.backward" : "archivebox", id: "book.detail.archive"
            ) { toggleArchive(book, to: !isArchived) }
            actionRow("Kitabı sil", systemImage: "trash", tint: .fkDanger, id: "book.detail.delete") {
                isConfirmingDelete = true
            }
        }
    }

    private func actionRow(
        _ title: String, systemImage: String, tint: FokusColor = .fkLabel, id: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            LineRow(title) {
                Image(systemName: systemImage).foregroundStyle(tint).accessibilityHidden(true)
            }
            .foregroundStyle(tint)
        }
        .buttonStyle(.fokusRow)
        .accessibilityIdentifier(id)
    }

    private func run(_ action: () throws -> Void) -> Bool {
        errorMessage = nil
        do {
            try action()
            return true
        } catch {
            logger.error("Kitap işlemi başarısız: \(error.localizedDescription, privacy: .public)")
            errorMessage = "İşlem tamamlanamadı. Lütfen tekrar dene."
            return false
        }
    }

    private func deleteEntry(_ entry: BookProgress) {
        _ = run { try BooksRepository(context: modelContext).deleteProgress(entry) }
    }

    private func toggleArchive(_ book: Book, to archived: Bool) {
        _ = run { try BooksRepository(context: modelContext).setArchived(book, archived) }
    }

    private func delete(_ book: Book) {
        guard run({ try BooksRepository(context: modelContext).delete(book) }) else { return }
        // iPhone: itilmiş ekranı kapat; iPad: yan paneldeki seçimi temizle.
        if isEmbedded { onDeleted() } else { dismiss() }
    }
}
