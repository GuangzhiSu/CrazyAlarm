import AlarmKit
import Foundation
import Observation

struct ActiveChallenge: Codable, Equatable {
    var alarm: AlarmRecord
    var session: QuizSession
    var isPreview: Bool
}

private struct SavedState: Codable {
    var alarms: [AlarmRecord]
    var challenge: ActiveChallenge?
    var queue: [AlarmRecord] = []
}

@MainActor @Observable
final class AppStore {
    private(set) var alarms: [AlarmRecord] = []
    private(set) var challenge: ActiveChallenge?
    private(set) var isBusy = false
    private(set) var isAuthorized = false
    var errorMessage: String?
    var notice: String?
    private var queue: [AlarmRecord] = []
    private let scheduler = AlarmScheduler()
    private let music = MusicPlayer()
    private var observationTask: Task<Void, Never>?
    private var authorizationTask: Task<Void, Never>?
    private var persistenceLocked = false

    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CrazyAlarm", isDirectory: true).appendingPathComponent("alarms.json")
    }

    init() {
        do {
            if FileManager.default.fileExists(atPath: Self.fileURL.path) {
                let saved = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: Self.fileURL))
                alarms = saved.alarms; challenge = saved.challenge; queue = saved.queue
            } else { alarms = [AlarmRecord()] }
        } catch {
            persistenceLocked = true
            errorMessage = "无法读取保存的闹钟，原文件已保留。请重新启动 App 后再试：\(error.localizedDescription)"
        }
        isAuthorized = scheduler.manager.authorizationState == .authorized
    }

    func observe() {
        guard observationTask == nil else { return }
        observationTask = Task { [weak self] in
            guard let self else { return }
            for await systemAlarms in self.scheduler.manager.alarmUpdates {
                guard !Task.isCancelled else { return }
                self.handleSystemAlarms(systemAlarms)
            }
        }
        authorizationTask = Task { [weak self] in
            guard let self else { return }
            for await state in self.scheduler.manager.authorizationUpdates {
                guard !Task.isCancelled else { return }
                self.isAuthorized = state == .authorized
            }
        }
    }

    func becameActive() {
        isAuthorized = scheduler.manager.authorizationState == .authorized
        if let pending = UserDefaults.standard.string(forKey: "pendingQuizAlarmID"),
           let id = UUID(uuidString: pending) {
            UserDefaults.standard.removeObject(forKey: "pendingQuizAlarmID")
            if let alarm = alarms.first(where: { $0.id == id }) { begin(alarm, preview: false) }
        }
        do {
            let systemAlarms = try scheduler.manager.alarms
            handleSystemAlarms(systemAlarms)
            if isAuthorized, !isBusy, !persistenceLocked {
                // A one-shot alarm disappears after it is stopped. Reconcile the enabled UI
                // with the daemon rather than showing an alarm that is no longer scheduled.
                let ids = Set(systemAlarms.map(\.id))
                var updated = alarms
                for index in updated.indices where updated[index].isEnabled && !ids.contains(updated[index].id) {
                    updated[index].isEnabled = false
                }
                if updated != alarms { try persist(alarms: updated, challenge: challenge, queue: queue); alarms = updated }
            }
            if let challenge, !music.isRinging { startMusic(for: challenge) }
        } catch { errorMessage = error.localizedDescription }
    }

    private func handleSystemAlarms(_ systemAlarms: [Alarm]) {
        for system in systemAlarms where system.state == .alerting {
            if let alarm = alarms.first(where: { $0.id == system.id }) { begin(alarm, preview: false) }
        }
    }

    private func persist(alarms: [AlarmRecord], challenge: ActiveChallenge?, queue: [AlarmRecord]) throws {
        guard !persistenceLocked else { throw StoreError.unreadable }
        let url = Self.fileURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(SavedState(alarms: alarms, challenge: challenge, queue: queue))
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func save(_ alarm: AlarmRecord) async -> Bool {
        guard !isBusy, challenge == nil else { return false }
        isBusy = true; defer { isBusy = false }
        let previous = alarms.first(where: { $0.id == alarm.id })
        do {
            try alarm.validate()
            for file in [alarm.sound.fileName, alarm.sound.alertFileName].compactMap({ $0 }) {
                guard FileManager.default.fileExists(atPath: MusicPlayer.soundsDirectory.appendingPathComponent(file).path) else {
                    throw AlarmValidationError.missingSound
                }
            }
            guard !persistenceLocked else { throw StoreError.unreadable }
            if alarm.isEnabled { try await scheduler.schedule(alarm) }
            else { try scheduler.cancel(alarm.id) }
            var updated = alarms
            if let index = updated.firstIndex(where: { $0.id == alarm.id }) { updated[index] = alarm }
            else { updated.append(alarm) }
            do { try persist(alarms: updated, challenge: nil, queue: queue) }
            catch { await restoreSchedule(previous, id: alarm.id); throw error }
            alarms = updated; isAuthorized = scheduler.manager.authorizationState == .authorized
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    private func restoreSchedule(_ previous: AlarmRecord?, id: UUID) async {
        do {
            if let previous, previous.isEnabled { try await scheduler.schedule(previous) }
            else { try scheduler.cancel(id) }
        } catch { notice = "保存失败后无法恢复原闹钟，请检查闹钟开关并重新保存。" }
    }

    func toggle(_ alarm: AlarmRecord) async {
        var changed = alarm; changed.isEnabled.toggle()
        _ = await save(changed)
    }

    func delete(_ alarm: AlarmRecord) async {
        guard !isBusy, challenge == nil else { return }
        isBusy = true; defer { isBusy = false }
        do {
            guard !persistenceLocked else { throw StoreError.unreadable }
            try scheduler.cancel(alarm.id)
            let updated = alarms.filter { $0.id != alarm.id }
            do { try persist(alarms: updated, challenge: nil, queue: queue) }
            catch { await restoreSchedule(alarm, id: alarm.id); throw error }
            alarms = updated
        } catch { errorMessage = error.localizedDescription }
    }

    func begin(_ alarm: AlarmRecord, preview: Bool) {
        guard !persistenceLocked else { errorMessage = StoreError.unreadable.localizedDescription; return }
        if let challenge {
            if challenge.alarm.id == alarm.id { return }
            if !preview, !queue.contains(where: { $0.id == alarm.id }) {
                var pending = queue; pending.append(alarm)
                do { try persist(alarms: alarms, challenge: challenge, queue: pending); queue = pending }
                catch { errorMessage = error.localizedDescription }
            }
            return
        }
        do {
            let session = try QuizSession(alarmID: alarm.id, questions: alarm.questions)
            let next = ActiveChallenge(alarm: alarm, session: session, isPreview: preview)
            try persist(alarms: alarms, challenge: next, queue: queue)
            challenge = next
            startMusic(for: next)
        } catch { errorMessage = error.localizedDescription }
    }

    private func startMusic(for challenge: ActiveChallenge) {
        do {
            try music.ring(challenge.alarm.sound)
            // Hand off the system alert to an uninterrupted local loop only AFTER playback starts.
            // A preview never stops a real system alarm with the same record ID.
            if !challenge.isPreview { try scheduler.stopIfAlerting(challenge.alarm.id) }
        } catch { errorMessage = "音频启动或切换失败：\(error.localizedDescription)" }
    }

    @discardableResult
    func submit(_ answer: String) -> QuizSession.Result {
        guard var next = challenge else { return .alreadyComplete }
        let result = next.session.submit(answer)
        do {
            try persist(alarms: alarms, challenge: next, queue: queue)
            challenge = next
            if result == .complete { finish() }
        } catch { errorMessage = error.localizedDescription; return .incorrect }
        return result
    }

    func finish() {
        guard let challenge, challenge.session.isComplete else { return }
        do {
            if !challenge.isPreview { try scheduler.stopIfAlerting(challenge.alarm.id) }
            try persist(alarms: alarms, challenge: nil, queue: queue)
            music.stop()
            self.challenge = nil
            notice = "两题答对，早上好 ☀️"
            if let next = queue.first {
                let remainder = Array(queue.dropFirst())
                try persist(alarms: alarms, challenge: nil, queue: remainder)
                queue = remainder
                begin(next, preview: false)
            }
        } catch { errorMessage = error.localizedDescription }
    }
}

private enum StoreError: LocalizedError {
    case unreadable
    var errorDescription: String? { "保存的闹钟文件无法读取。为保护原有数据，本次没有覆盖它。请重新启动后再试。" }
}
