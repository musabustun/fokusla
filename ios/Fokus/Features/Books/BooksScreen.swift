import FokusData
import FokusDesign
import FokusDomain
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.musabustun.fokus", category: "books")

/// Kitaplar modülü (web `BooksScreen`): derse göre gruplu liste (devam eden / biten).
/// iPhone: liste → detay (yığına itilir). iPad (geniş): liste ve detay yan yana.
/// Yüzde, hız ve tahmini bitiş saklanmaz; her görünümde `BooksCalc` ile hesaplanır.
struct BooksScreen: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case active, finished
        var id: String { rawValue }
        var title: String { self == .active ? "Devam eden" : "Biten" }
        var emptyText: String { self == .active ? "Devam eden kitap yok." : "Biten kitap yok." }
    }

    /// Detay yığını rotası (iPhone).
    private struct BookRoute: Hashable { let id: UUID }

    /// Liste + yan panel için gereken en az genişlik (pt).
    private static let wideLayoutMinWidth: CGFloat = 640
    private static let listPanelWidth: CGFloat = 360
    private static let noSubjectTitle = "Ders seçilmedi"

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(filter: #Predicate<Book> { $0.deletedAt == nil }) private var books: [Book]
    @Query(filter: #Predicate<BookProgress> { $0.deletedAt == nil }) private var progress: [BookProgress]
    @Query(filter: #Predicate<Subject> { $0.deletedAt == nil }) private var subjects: [Subject]

    @State private var tab: Tab = .active
    @State private var selectedId: UUID?
    @State private var isAdding = false
    @State private var isScanning = false
    /// Tarama sayfası kapandıktan sonra işlenecek sonuç (iki sayfa aynı anda değişemez).
    @State private var pendingOutcome: BookScanOutcome?
    @State private var prefill: BookFormPrefill?
    @State private var existingBookId: UUID?
    /// iPhone: "Kitaba git" ile itilen detay.
    @State private var pushedBookId: UUID?

    var body: some View {
        let now = Date.now
        let data = BooksData(books: books, progress: progress, subjects: subjects, now: now)
        GeometryReader { proxy in
            let isWide = horizontalSizeClass == .regular && proxy.size.width >= Self.wideLayoutMinWidth
            Group {
                if isWide {
                    HStack(spacing: 0) {
                        ScrollView { list(data: data, now: now, isWide: true) }
                            .frame(width: Self.listPanelWidth)
                        Divider().overlay(.fkSeparator)
                        detailPane
                    }
                } else {
                    ScrollView { list(data: data, now: now, isWide: false) }
                }
            }
        }
        .background(.fkBackground)
        .navigationDestination(for: BookRoute.self) { route in
            BookDetailView(bookId: route.id, isEmbedded: false, onDeleted: {})
                .toolbarVisibility(.visible, for: .navigationBar)
                .navigationBarTitleDisplayMode(.inline)
        }
        .navigationDestination(item: $pushedBookId) { id in
            BookDetailView(bookId: id, isEmbedded: false, onDeleted: {})
                .toolbarVisibility(.visible, for: .navigationBar)
                .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $isAdding) {
            BookFormView(book: nil, subjectGroups: data.subjectGroups) { selectedId = $0 }
        }
        .sheet(isPresented: $isScanning, onDismiss: handlePendingOutcome) {
            let library = Self.loadLibrary()
            let existing = Self.barcodeIndex(books)
            BookScanSheet(
                resolve: { BookScanResolver.resolve($0, library: library, existingBooks: existing) },
                onOutcome: { outcome in
                    pendingOutcome = outcome
                    isScanning = false
                })
        }
        .sheet(item: $prefill) { prefill in
            BookFormView(book: nil, subjectGroups: data.subjectGroups, prefill: prefill) { selectedId = $0 }
        }
        .alert("Bu kitap zaten kitaplığında", isPresented: isShowingExisting) {
            Button("Kitaba git") { goToExistingBook() }
                .accessibilityIdentifier("book.scan.goToBook")
            Button("Tamam", role: .cancel) { existingBookId = nil }
        }
        .task { BooksUITestSeed.applyIfRequested(context: modelContext) }
        .accessibilityIdentifier("screen.books")
    }

    // MARK: Barkod akışı

    private var isShowingExisting: Binding<Bool> {
        Binding(get: { existingBookId != nil }, set: { if !$0 { existingBookId = nil } })
    }

    private func handlePendingOutcome() {
        guard let outcome = pendingOutcome else { return }
        pendingOutcome = nil
        switch outcome {
        case .invalid: break
        case .existing(let bookId): existingBookId = bookId
        case .found(let resolved): prefill = BookFormPrefill(resolved: resolved)
        case .notFound(let barcode): prefill = BookFormPrefill(notFoundBarcode: barcode)
        }
    }

    private func goToExistingBook() {
        guard let id = existingBookId else { return }
        existingBookId = nil
        if horizontalSizeClass == .regular { selectedId = id } else { pushedBookId = id }
    }

    /// Normalize barkod → kitap kimliği (aynı barkodda en eski kayıt kazanır).
    private static func barcodeIndex(_ books: [Book]) -> [String: UUID] {
        var index: [String: (id: UUID, createdAt: Date)] = [:]
        for book in BooksData.deduplicated(books) {
            guard let barcode = book.barcode else { continue }
            if let current = index[barcode], current.createdAt <= book.createdAt { continue }
            index[barcode] = (book.id, book.createdAt)
        }
        return index.mapValues(\.id)
    }

    /// Gömülü katalog; okunamazsa kayıt düşülür ve boş katalogla devam edilir (elle ekleme çalışır).
    private static func loadLibrary() -> BookLibrary {
        do {
            return try BookLibrary.bundled()
        } catch {
            logger.error("Kitap kütüphanesi okunamadı: \(error.localizedDescription, privacy: .public)")
            return BookLibrary(version: 0, updatedAt: "", books: [])
        }
    }

    // MARK: Liste

    private func list(data: BooksData, now: Date, isWide: Bool) -> some View {
        VStack(alignment: .leading, spacing: FokusSpacing.xl) {
            ScreenHeader("Kitaplar", eyebrow: "Soru bankaları ve kaynaklar") {
                Menu {
                    Button { isAdding = true } label: { Label("Elle ekle", systemImage: "square.and.pencil") }
                        .accessibilityIdentifier("books.add.manual")
                    Button { isScanning = true } label: {
                        Label("Barkod okut", systemImage: "barcode.viewfinder")
                    }
                    .accessibilityIdentifier("books.add.scan")
                } label: {
                    Label("Ekle", systemImage: "plus")
                }
                .buttonStyle(.fokusPrimary)
                .fixedSize()
                .accessibilityIdentifier("books.add")
            }
            if data.summaries.isEmpty {
                EmptyStateView(
                    "Kitaplığın boş", systemImage: "books.vertical",
                    message: "Kullandığın kitapları ekle ve her kitapta nereye kadar geldiğini takip et."
                ) {
                    Button("İlk kitabını ekle") { isAdding = true }
                        .buttonStyle(.fokusPrimary).fixedSize()
                        .accessibilityIdentifier("books.addFirst")
                }
            } else {
                tabPicker
                groups(data: data, now: now, isWide: isWide)
            }
        }
        .padding(.horizontal, FokusSpacing.screenHorizontal)
        .padding(.vertical, FokusSpacing.lg)
    }

    private var tabPicker: some View {
        Picker("Kitap durumu", selection: $tab) {
            ForEach(Tab.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("books.tab")
    }

    @ViewBuilder
    private func groups(data: BooksData, now: Date, isWide: Bool) -> some View {
        let split = BooksCalc.splitByFinished(data.summaries)
        let visible = tab == .active ? split.active : split.finished
        if visible.isEmpty {
            Text(tab.emptyText)
                .fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                .frame(maxWidth: .infinity).padding(.vertical, FokusSpacing.xxl)
                .accessibilityIdentifier("books.tabEmpty")
        } else {
            ForEach(BooksCalc.groupBySubject(visible), id: \.subjectId) { group in
                LineSection(group.subjectId.flatMap { data.subjectNames[$0] } ?? Self.noSubjectTitle) {
                    ForEach(group.books) { summary in
                        row(summary, now: now, isWide: isWide)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ summary: BooksCalc.BookSummary, now: Date, isWide: Bool) -> some View {
        let content = BookRowView(summary: summary, now: now, isSelected: isWide && summary.id == selectedId)
        if isWide {
            Button { selectedId = summary.id } label: { content }
                .buttonStyle(.fokusRow)
                .accessibilityIdentifier("book.row")
        } else {
            NavigationLink(value: BookRoute(id: summary.id)) { content }
                .buttonStyle(.fokusRow)
                .accessibilityIdentifier("book.row")
        }
    }

    // MARK: Detay paneli (iPad)

    @ViewBuilder private var detailPane: some View {
        if let selectedId {
            BookDetailView(bookId: selectedId, isEmbedded: true) { self.selectedId = nil }
                .id(selectedId)
        } else {
            EmptyStateView(
                "Bir kitap seç", systemImage: "book",
                message: "İlerlemesini görmek ve güncellemek için listeden bir kitap seç.")
        }
    }
}

#Preview {
    NavigationStack { BooksScreen() }.fokusTheme()
}
