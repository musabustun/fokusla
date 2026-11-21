import FokusData
import FokusDomain
import Foundation
import SwiftData

/// UI testleri/ekran görüntüleri için örnek test sonuçları (yalnızca DEBUG + `-FokusUITestMode`).
/// `-FokusUITestAnalysisSeed 1` → TYT Matematik/Türkçe'ye son günlere yayılmış sonuçlar.
enum AnalysisUITestSeed {
    static let argumentKey = "FokusUITestAnalysisSeed"

    @MainActor
    static func applyIfRequested(context: ModelContext, now: Date = .now) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-FokusUITestMode"),
            UserDefaults.standard.string(forKey: argumentKey) != nil
        else { return }
        let store = EntityStore<TestResult>(context: context)
        guard (try? store.all().isEmpty) == true else { return }
        let subjects = (try? EntityStore<Subject>(context: context).all()) ?? []
        let topics = (try? EntityStore<Topic>(context: context).all()) ?? []
        guard let math = subjects.first(where: { $0.catalogKey == "tyt-matematik" }),
            let turkish = subjects.first(where: { $0.catalogKey == "tyt-turkce" })
        else { return }
        let mathTopics = topics.filter { $0.subjectId == math.id }.sorted { $0.order < $1.order }
        let turkishTopics = topics.filter { $0.subjectId == turkish.id }.sorted { $0.order < $1.order }
        let calendar = Calendar.current

        func add(
            _ subject: Subject, _ topic: Topic?, daysAgo: Int, _ correct: Int, _ wrong: Int, _ blank: Int,
            label: String
        ) {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: now),
                let takenAt = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day)
            else { return }
            store.insert(
                TestResult(
                    subjectId: subject.id, topicId: topic?.id, label: label, sourceName: "Okul fasikülü",
                    takenAt: takenAt, correct: correct, wrong: wrong, blank: blank),
                now: takenAt)
        }
        if mathTopics.count >= 3 {
            add(math, mathTopics[0], daysAgo: 6, 8, 5, 2, label: "Test 1")
            add(math, mathTopics[0], daysAgo: 4, 10, 4, 1, label: "Test 2")
            add(math, mathTopics[0], daysAgo: 1, 12, 3, 0, label: "Test 3")
            add(math, mathTopics[1], daysAgo: 3, 14, 2, 4, label: "Test 7")
            add(math, mathTopics[2], daysAgo: 2, 6, 8, 6, label: "Test 5")
            add(math, nil, daysAgo: 5, 20, 10, 10, label: "Deneme 1")
        }
        if turkishTopics.count >= 2 {
            add(turkish, turkishTopics[0], daysAgo: 2, 17, 2, 1, label: "Test 4")
            add(turkish, turkishTopics[1], daysAgo: 1, 15, 3, 2, label: "Test 6")
        }
        try? store.save()
        #endif
    }
}
