import FokusData
import FokusDesign
import FokusDomain
import SwiftData
import SwiftUI

/// Konu/Test analizi modülü (web `features/analysis`).
/// - iPhone (compact): genel bakış → ders → konu, `NavigationStack` ile (kabuk sağlar).
/// - iPad (regular): solda ders listesi, sağda ayrıntı bölmesi (yan yana).
struct AnalysisScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(filter: #Predicate<Subject> { $0.deletedAt == nil }) private var subjects: [Subject]
    @Query(filter: #Predicate<Topic> { $0.deletedAt == nil }) private var topics: [Topic]
    @Query(filter: #Predicate<TestResult> { $0.deletedAt == nil }) private var results: [TestResult]
    @Query(filter: #Predicate<Book> { $0.deletedAt == nil }) private var books: [Book]
    @Query(filter: #Predicate<UserProfile> { $0.deletedAt == nil }, sort: \UserProfile.createdAt)
    private var profiles: [UserProfile]

    /// Ders listesi + ayrıntı yan yana göstermek için gereken en az genişlik (pt).
    private static let splitMinWidth: CGFloat = 760

    @State private var sheet: AnalysisSheet?
    @State private var selectedSubjectId: UUID?

    private var data: AnalysisData {
        AnalysisData.build(
            subjects: subjects, topics: topics, results: results, books: books,
            field: profiles.first?.field ?? .say)
    }

    var body: some View {
        let data = data
        GeometryReader { proxy in
            // Yan yana yalnızca yeterli genişlikte (iPad yatay); dar iPad (dikey/bölünmüş) iPhone akışını kullanır.
            if horizontalSizeClass == .regular && proxy.size.width >= Self.splitMinWidth {
                regularLayout(data)
            } else {
                compactLayout(data)
            }
        }
        .background(.fkBackground)
        .environment(\.analysisActions, actions)
        .sheet(item: $sheet) { sheet in
            AnalysisSheetContent(sheet: sheet, data: data, onSubjectSaved: { selectedSubjectId = $0.id }) {
                self.sheet = nil
            }
        }
        .onChange(of: data.subjects.map(\.id)) {
            if let selected = selectedSubjectId, data.subjectsById[selected] == nil {
                selectedSubjectId = nil
            }
        }
        .task { AnalysisUITestSeed.applyIfRequested(context: modelContext) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.analysis")
    }

    private var actions: AnalysisActions {
        AnalysisActions(
            addTest: { subjectId, topicId in
                sheet = .test(editing: nil, subjectId: subjectId, topicId: topicId)
            },
            editResult: { result in sheet = .test(editing: result, subjectId: nil, topicId: nil) },
            addSubject: { sheet = .subject(editing: nil) },
            editSubject: { subject in sheet = .subject(editing: subject) },
            addTopic: { subject in sheet = .topic(subjectId: subject.id, editing: nil) },
            editTopic: { topic in
                if let subjectId = topic.subjectId { sheet = .topic(subjectId: subjectId, editing: topic) }
            })
    }

    // MARK: - iPhone

    private func compactLayout(_ data: AnalysisData) -> some View {
        AnalysisOverviewView(data: data, showsSubjectList: true)
            .navigationTitle("Analiz")
            .navigationDestination(for: AnalysisRoute.self) { route in
                AnalysisRouteView(route: route, data: data, actions: actions)
            }
    }

    // MARK: - iPad

    private func regularLayout(_ data: AnalysisData) -> some View {
        HStack(spacing: 0) {
            sidebar(data)
                .frame(width: 300)
            Divider().overlay(.fkSeparator)
            NavigationStack {
                detailPane(data)
                    .toolbarVisibility(.hidden, for: .navigationBar)
                    .navigationDestination(for: AnalysisRoute.self) { route in
                        AnalysisRouteView(route: route, data: data, actions: actions)
                    }
            }
            .id(selectedSubjectId)
        }
    }

    @ViewBuilder
    private func detailPane(_ data: AnalysisData) -> some View {
        if let selectedSubjectId, let subject = data.subjectsById[selectedSubjectId] {
            SubjectDetailView(data: data, subject: subject)
        } else {
            AnalysisOverviewView(data: data, showsSubjectList: false)
        }
    }

    private func sidebar(_ data: AnalysisData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FokusSpacing.xl) {
                LineSection {
                    Button {
                        selectedSubjectId = nil
                    } label: {
                        LineRow("Genel bakış")
                            .background {
                                if selectedSubjectId == nil { Rectangle().fill(.fkFill) }
                            }
                    }
                    .buttonStyle(.fokusRow)
                    .accessibilityAddTraits(selectedSubjectId == nil ? .isSelected : [])
                    .accessibilityIdentifier("analysis.overview")
                }
                SubjectListSection(data: data, selection: $selectedSubjectId, isCompact: true)
                Button("Ders ekle") { sheet = .subject(editing: nil) }
                    .buttonStyle(.fokusSecondary)
                    .accessibilityIdentifier("analysis.addSubject")
            }
            .padding(.horizontal, FokusSpacing.lg)
            .padding(.vertical, FokusSpacing.lg)
        }
        .accessibilityIdentifier("analysis.sidebar")
    }
}

/// Bir `AnalysisRoute`'u ekrana çözer; hedef (ders/konu) silindiyse sayfayı kapatır.
struct AnalysisRouteView: View {
    let route: AnalysisRoute
    let data: AnalysisData
    /// Pushed hedefler kök içeriğin ortamını almaz; eylemler burada yeniden verilir.
    let actions: AnalysisActions

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content
            .environment(\.analysisActions, actions)
            .toolbarVisibility(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .subject(let subjectId):
            if let subject = data.subjectsById[subjectId] {
                SubjectDetailView(data: data, subject: subject)
            } else {
                missing
            }
        case .topic(let subjectId, let topicId):
            if let subject = data.subjectsById[subjectId], let topic = data.topicsById[topicId] {
                TopicDetailView(data: data, subject: subject, topic: topic)
            } else {
                missing
            }
        }
    }

    private var missing: some View {
        EmptyStateView("Bulunamadı", systemImage: "questionmark.folder", message: "Bu kayıt silinmiş olabilir.")
            .background(.fkBackground)
            .onAppear { dismiss() }
    }
}

#Preview("Analiz — koyu") {
    NavigationStack { AnalysisScreen() }
        .fokusTheme()
        .preferredColorScheme(.dark)
        .modelContainer(PreviewSupport.onboardedContainer())
}

#Preview("Analiz — açık") {
    NavigationStack { AnalysisScreen() }
        .fokusTheme()
        .preferredColorScheme(.light)
        .modelContainer(PreviewSupport.onboardedContainer())
}
