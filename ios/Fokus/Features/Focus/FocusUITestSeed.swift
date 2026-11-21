import FokusData
import FokusDomain
import Foundation
import SwiftData

/// UI testleri için örnek odak verisi (yalnızca DEBUG + `-FokusUITestMode`).
/// `-FokusUITestFocusSeed history` → son günlere yayılmış bitmiş oturumlar;
/// `-FokusUITestFocusSeed longbreak` → geçmiş + 45 dakikadır süren açık mola;
/// `-FokusUITestFocusSeed running` → geçmiş + 20 dakika önce başlamış açık odak oturumu.
enum FocusUITestSeed {
    static let argumentKey = "FokusUITestFocusSeed"

    @MainActor
    static func applyIfRequested(context: ModelContext, now: Date = .now) {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-FokusUITestMode"),
            let mode = UserDefaults.standard.string(forKey: argumentKey)
        else { return }
        let sessions = EntityStore<FocusSession>(context: context)
        guard (try? sessions.all().isEmpty) == true else { return }
        let segments = EntityStore<FocusSegment>(context: context)
        let subject = (try? EntityStore<Subject>(context: context).all())?
            .first { $0.catalogKey != nil && $0.exam == .tyt }

        func add(start: Date, parts: [(FocusSegmentKind, TimeInterval)], ended: Bool) {
            let session = sessions.insert(
                FocusSession(subjectId: subject?.id, startedAt: start, endedAt: nil), now: start)
            var cursor = start
            for (index, part) in parts.enumerated() {
                let isLast = index == parts.count - 1
                let end = cursor.addingTimeInterval(part.1)
                segments.insert(
                    FocusSegment(
                        sessionId: session.id, kind: part.0, startedAt: cursor,
                        endedAt: isLast && !ended ? nil : end),
                    now: cursor)
                cursor = end
            }
            if ended { session.endedAt = cursor }
        }

        let calendar = Calendar.current
        let minute: TimeInterval = 60
        for daysAgo in [1, 2, 3, 5] {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: now),
                let start = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: day)
            else { continue }
            let focus = Double(25 + daysAgo * 10) * minute
            add(
                start: start,
                parts: [(.focus, focus), (.break, 8 * minute), (.focus, 25 * minute)], ended: true)
        }
        if mode == "longbreak" {
            add(
                start: now.addingTimeInterval(-80 * minute),
                parts: [(.focus, 35 * minute), (.break, 45 * minute)], ended: false)
        }
        if mode == "running" {
            add(start: now.addingTimeInterval(-20 * minute), parts: [(.focus, 20 * minute)], ended: false)
        }
        try? sessions.save()
        #endif
    }
}
