import FokusData
import FokusDomain
import Foundation
import SwiftData

/// Intent'lerin (Siri, Kestirmeler, Live Activity, widget) kullandığı yazma işlemleri. Hepsi mevcut
/// repository'ler üzerinden yapılır (soft delete, senkron kaydı, değişmezler aynen korunur); bu katman
/// yalnızca bağlam kurar, `now` verir ve widget'ları yeniler.
@MainActor
enum FocusActions {
    enum Outcome: Equatable {
        case started, alreadyRunning, paused, resumed, finished(focusMs: Double), noActiveSession
    }

    static func start(subjectId: UUID?, now: Date = .now) throws -> Outcome {
        let context = try FokusSystem.context()
        let repository = FocusRepository(context: context)
        if try repository.findActive() != nil { return .alreadyRunning }
        try repository.start(subjectId: subjectId, now: now)
        FokusSystem.reloadWidgets()
        return .started
    }

    /// Canlı etkinlikteki Duraklat/Devam düğmesi: odaktaysa mola, moladaysa devam.
    static func togglePause(now: Date = .now) throws -> Outcome {
        let context = try FokusSystem.context()
        let repository = FocusRepository(context: context)
        guard let session = try repository.findActive() else { return .noActiveSession }
        let segments = try repository.segments(forSession: session.id).map(\.snapshot)
        let outcome: Outcome
        if FocusCalc.findOpenSegment(segments)?.kind == .focus {
            try repository.pause(sessionId: session.id, now: now)
            outcome = .paused
        } else {
            try repository.resume(sessionId: session.id, now: now)
            outcome = .resumed
        }
        FokusSystem.reloadWidgets()
        return outcome
    }

    static func finish(now: Date = .now) throws -> Outcome {
        let context = try FokusSystem.context()
        let repository = FocusRepository(context: context)
        guard let session = try repository.findActive() else { return .noActiveSession }
        let stats = try repository.finish(sessionId: session.id, now: now)
        FokusSystem.reloadWidgets()
        return .finished(focusMs: stats?.focusMs ?? 0)
    }

    /// Siri "Görev ekle": bugün teslim bir ödev. Ad 120 karaktere kırpılır.
    static func addTask(title: String, now: Date = .now, calendar: Calendar = .current) throws {
        let context = try FokusSystem.context()
        let today = Identifiers.isoDate(now, calendar: calendar)
        let clipped = String(title.prefix(TaskDraft.titleMaxLength))
        try TasksRepository(context: context).create(
            TaskValues(kind: .assignment, title: clipped, dueDate: today), today: today, now: now)
        FokusSystem.reloadWidgets()
    }

    /// Widget'taki işaret düğmesi: görevi bugün için tamamla/geri al.
    static func toggleTask(id: UUID, now: Date = .now, calendar: Calendar = .current) throws {
        let context = try FokusSystem.context()
        let repository = TasksRepository(context: context)
        guard let task = try repository.tasks().first(where: { $0.id == id }) else { return }
        try repository.toggleCompletion(task, on: Identifiers.isoDate(now, calendar: calendar), now: now)
        FokusSystem.reloadWidgets()
    }
}
