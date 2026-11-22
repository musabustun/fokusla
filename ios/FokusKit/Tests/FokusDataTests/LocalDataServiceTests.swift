import FokusDomain
import Foundation
import SwiftData
import Testing

@testable import FokusData

@MainActor
struct LocalDataServiceTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)  // 2027-01-15T08:00:00.000Z

    private func make() throws -> (LocalDataService, ModelContext) {
        let context = ModelContext(try FokusStore.makeInMemoryContainer())
        return (LocalDataService(context: context), context)
    }

    private func export(_ service: LocalDataService, now: Date? = nil) throws -> [String: Any] {
        let data = try service.exportJSON(now: now ?? t0)
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }

    private func entities(_ root: [String: Any]) throws -> [String: [[String: Any]]] {
        try #require(root["entities"] as? [String: [[String: Any]]])
    }

    private static let entityKeys: Set<String> = [
        "profiles", "subjects", "topics", "books", "bookProgress", "testResults",
        "focusSessions", "focusSegments", "tasks", "taskCompletions", "friends", "rooms",
    ]

    @Test func emptyStoreExportsTopLevelShapeAndAllEntityKeys() throws {
        let (service, _) = try make()
        let root = try export(service)
        #expect(root["app"] as? String == "fokus")
        #expect(root["formatVersion"] as? Int == 1)
        #expect(root["exportedAt"] as? String == "2027-01-15T08:00:00.000Z")
        let entities = try entities(root)
        #expect(Set(entities.keys) == Self.entityKeys)
        let allEmpty = entities.values.allSatisfy { $0.isEmpty }
        #expect(allEmpty)
    }

    @Test func profileExportsGoalAndDisplayName() throws {
        let (service, context) = try make()
        let store = EntityStore<UserProfile>(context: context)
        store.insert(
            UserProfile(
                id: UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")!, displayName: "Ada",
                field: .ea, targetExamYear: 2027, dailyFocusGoalMinutes: 150), now: t0)
        try store.save()

        let profile = try #require(try entities(try export(service))["profiles"]?.first)
        #expect(profile["dailyFocusGoalMinutes"] as? Int == 150)
        #expect(profile["displayName"] as? String == "Ada")
        #expect(profile["field"] as? String == "EA")
        #expect(profile["targetExamYear"] as? Int == 2027)
        #expect(profile["id"] as? String == "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee")
        #expect(profile["createdAt"] as? String == "2027-01-15T08:00:00.000Z")
        #expect(profile["updatedAt"] as? String == "2027-01-15T08:00:00.000Z")
        #expect(profile["deletedAt"] is NSNull)
    }

    @Test func nilFieldsAreExplicitJSONNull() throws {
        let (service, context) = try make()
        let store = EntityStore<UserProfile>(context: context)
        store.insert(UserProfile(), now: t0)
        try store.save()

        let data = try service.exportJSON(now: t0)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"dailyFocusGoalMinutes\" : null"))
        #expect(text.contains("\"displayName\" : null"))

        let profile = try #require(try entities(try export(service))["profiles"]?.first)
        for key in ["displayName", "appleUserId", "targetExamYear", "onboardingCompletedAt",
                    "dailyFocusGoalMinutes", "deletedAt"]
        {
            #expect(profile[key] is NSNull, "\(key) null olmalı")
        }
    }

    @Test func softDeletedRecordsAreExcluded() throws {
        let (service, context) = try make()
        let store = EntityStore<Book>(context: context)
        let kept = store.insert(Book(title: "Kalan"), now: t0)
        let gone = store.insert(Book(title: "Silinen"), now: t0)
        store.softDelete(gone, now: t0.addingTimeInterval(5))
        try store.save()

        let books = try #require(try entities(try export(service))["books"])
        #expect(books.count == 1)
        #expect(books.first?["title"] as? String == "Kalan")
        #expect(books.first?["id"] as? String == Identifiers.lowercasedString(kept.id))
    }

    @Test func dateFieldsUseUTCWithMilliseconds() throws {
        let (service, context) = try make()
        let moment = Date(timeIntervalSince1970: 1_800_000_000.123)
        let store = EntityStore<FocusSession>(context: context)
        store.insert(FocusSession(startedAt: moment, endedAt: moment.addingTimeInterval(60)), now: moment)
        try store.save()

        let session = try #require(try entities(try export(service))["focusSessions"]?.first)
        #expect(session["startedAt"] as? String == "2027-01-15T08:00:00.123Z")
        #expect(session["endedAt"] as? String == "2027-01-15T08:01:00.123Z")
        let pattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/
        #expect((session["createdAt"] as? String)?.wholeMatch(of: pattern) != nil)
    }

    @Test func sessionSegmentAndRoutineTaskRoundTrip() throws {
        let (service, context) = try make()
        let subjectId = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!
        let sessionId = UUID(uuidString: "AAAAAAAA-0000-4000-8000-000000000001")!
        let taskId = UUID(uuidString: "BBBBBBBB-0000-4000-8000-000000000002")!

        let sessions = EntityStore<FocusSession>(context: context)
        sessions.insert(
            FocusSession(id: sessionId, subjectId: subjectId, startedAt: t0, endedAt: nil, note: "not"), now: t0)
        let segments = EntityStore<FocusSegment>(context: context)
        segments.insert(FocusSegment(sessionId: sessionId, kind: .break, startedAt: t0), now: t0)
        let tasks = EntityStore<StudyTask>(context: context)
        tasks.insert(
            StudyTask(
                id: taskId, title: "Paragraf", kind: .routine,
                recurrence: RecurrenceRule(frequency: .weekly, weekdays: [1, 3]), order: 2,
                startDate: "2027-01-15", targetQuantity: 20, quantityUnit: "soru"), now: t0)
        let completions = EntityStore<TaskCompletion>(context: context)
        completions.insert(TaskCompletion(taskId: taskId, date: "2027-01-15", completedAt: t0, quantity: 18), now: t0)
        try context.save()

        let entities = try entities(try export(service))
        let session = try #require(entities["focusSessions"]?.first)
        #expect(session["id"] as? String == "aaaaaaaa-0000-4000-8000-000000000001")
        #expect(session["subjectId"] as? String == "11111111-2222-4333-8444-555555555555")
        #expect(session["topicId"] is NSNull)
        #expect(session["endedAt"] is NSNull)
        #expect(session["note"] as? String == "not")

        let segment = try #require(entities["focusSegments"]?.first)
        #expect(segment["sessionId"] as? String == "aaaaaaaa-0000-4000-8000-000000000001")
        #expect(segment["kind"] as? String == "break")
        #expect(segment["endedAt"] is NSNull)

        let task = try #require(entities["tasks"]?.first)
        #expect(task["kind"] as? String == "routine")
        #expect(task["title"] as? String == "Paragraf")
        #expect(task["order"] as? Int == 2)
        #expect(task["dueDate"] is NSNull)
        #expect(task["completedAt"] is NSNull)
        #expect(task["startDate"] as? String == "2027-01-15")
        #expect(task["targetQuantity"] as? Int == 20)
        #expect(task["quantityUnit"] as? String == "soru")
        let recurrence = try #require(task["recurrence"] as? [String: Any])
        #expect(recurrence["frequency"] as? String == "weekly")
        #expect(recurrence["weekdays"] as? [Int] == [1, 3])

        let completion = try #require(entities["taskCompletions"]?.first)
        #expect(completion["taskId"] as? String == "bbbbbbbb-0000-4000-8000-000000000002")
        #expect(completion["date"] as? String == "2027-01-15")
        #expect(completion["quantity"] as? Int == 18)
    }

    @Test func nonRoutineTaskHasNullRecurrence() throws {
        let (service, context) = try make()
        let store = EntityStore<StudyTask>(context: context)
        store.insert(StudyTask(title: "Ödev", kind: .assignment, dueDate: "2027-02-01"), now: t0)
        try store.save()
        let task = try #require(try entities(try export(service))["tasks"]?.first)
        #expect(task["recurrence"] is NSNull)
        #expect(task["dueDate"] as? String == "2027-02-01")
    }

    @Test func subjectFieldsAndRoomMembersExportAsArrays() throws {
        let (service, context) = try make()
        EntityStore<Subject>(context: context).insert(
            Subject(name: "Matematik", exam: .tyt, fields: [.say, .ea], catalogKey: "tyt-matematik"), now: t0)
        EntityStore<Room>(context: context).insert(
            Room(name: "Oda", hostUserId: "h", memberUserIds: ["a", "b"], inviteCode: "XYZ"), now: t0)
        try context.save()
        let entities = try entities(try export(service))
        let subject = try #require(entities["subjects"]?.first)
        #expect(subject["fields"] as? [String] == ["SAY", "EA"])
        #expect(subject["exam"] as? String == "TYT")
        #expect(subject["catalogKey"] as? String == "tyt-matematik")
        let room = try #require(entities["rooms"]?.first)
        #expect(room["memberUserIds"] as? [String] == ["a", "b"])
        #expect(room["startedAt"] is NSNull)
    }

    @Test func exportFileNameUsesLocalDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        // 2027-01-14T22:30:00Z = 2027-01-15 01:30 İstanbul (UTC+3)
        let moment = Date(timeIntervalSince1970: 1_799_965_800)
        #expect(
            LocalDataService.exportFileName(now: moment, calendar: calendar)
                == "fokus-yedek-2027-01-15.json")
    }

    private func count<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    @Test func deleteAllRemovesEverythingIncludingTombstonesAndReseedWorks() throws {
        let (service, context) = try make()
        try CurriculumSeeder.ensureSeeded(context: context)
        EntityStore<UserProfile>(context: context).insert(UserProfile(displayName: "Ada"), now: t0)
        EntityStore<Book>(context: context).insert(Book(title: "K"), now: t0)
        EntityStore<BookProgress>(context: context).insert(BookProgress(bookId: nil, reachedUnit: 3), now: t0)
        EntityStore<TestResult>(context: context).insert(
            TestResult(subjectId: nil, correct: 1, wrong: 0, blank: 0), now: t0)
        EntityStore<FocusSession>(context: context).insert(FocusSession(startedAt: t0), now: t0)
        EntityStore<FocusSegment>(context: context).insert(
            FocusSegment(sessionId: nil, kind: .focus, startedAt: t0), now: t0)
        let task = EntityStore<StudyTask>(context: context).insert(StudyTask(title: "T", kind: .assignment), now: t0)
        EntityStore<StudyTask>(context: context).softDelete(task, now: t0)  // tombstone
        EntityStore<TaskCompletion>(context: context).insert(TaskCompletion(taskId: nil, date: "2027-01-15"), now: t0)
        EntityStore<Friend>(context: context).insert(
            Friend(remoteUserId: "u", displayName: "F", status: .accepted), now: t0)
        EntityStore<Room>(context: context).insert(Room(name: "R", hostUserId: "h", inviteCode: "C"), now: t0)
        try context.save()
        #expect(try count(Subject.self, context) > 0)
        #expect(try count(Topic.self, context) > 0)

        try service.deleteAll()

        #expect(try count(UserProfile.self, context) == 0)
        #expect(try count(Subject.self, context) == 0)
        #expect(try count(Topic.self, context) == 0)
        #expect(try count(Book.self, context) == 0)
        #expect(try count(BookProgress.self, context) == 0)
        #expect(try count(TestResult.self, context) == 0)
        #expect(try count(FocusSession.self, context) == 0)
        #expect(try count(FocusSegment.self, context) == 0)
        #expect(try count(StudyTask.self, context) == 0)
        #expect(try count(TaskCompletion.self, context) == 0)
        #expect(try count(Friend.self, context) == 0)
        #expect(try count(Room.self, context) == 0)

        let reseeded = try CurriculumSeeder.ensureSeeded(context: context)
        #expect(reseeded.subjectsCreated > 0 && reseeded.topicsCreated > 0)
        #expect(try count(Subject.self, context) == reseeded.subjectsCreated)
    }
}
