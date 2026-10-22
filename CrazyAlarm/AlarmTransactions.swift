import Foundation

enum RegisteredAlarmState { case scheduled, alerting }

@MainActor
protocol AlarmSchedulingBackend {
    func state(of id: UUID) throws -> RegisteredAlarmState?
    func cancel(_ id: UUID) throws
    func register(_ alarm: AlarmRecord) async throws
}

extension AlarmRecord {
    func hasSameSystemConfiguration(as other: AlarmRecord) -> Bool {
        id == other.id && hour == other.hour && minute == other.minute && title == other.title
            && weekdays == other.weekdays && sound == other.sound
    }
}

enum AlarmUpdateFailure: LocalizedError {
    case currentlyRinging, inconsistentState
    case recoveryFailed(original: String, recovery: String)
    var errorDescription: String? {
        switch self {
        case .currentlyRinging: "这个闹钟正在响铃，请先完成当前任务再编辑。"
        case .inconsistentState: "本地记录与系统闹钟状态不同步。本次没有修改系统闹钟，请重新打开 App 后再试。"
        case .recoveryFailed(let original, let recovery):
            "保存失败，且无法确认原闹钟已恢复。请立即检查开关并重新保存。\n保存错误：\(original)\n恢复错误：\(recovery)"
        }
    }
}

/// Owns the replace/commit/rollback sequence; never cancels an unrelated alarm.
@MainActor
enum AlarmUpdateTransaction {
    static func perform(_ alarm: AlarmRecord, previous: AlarmRecord?, backend: any AlarmSchedulingBackend,
                        commit: () throws -> Void) async throws {
        let existing = try backend.state(of: alarm.id)
        guard existing != .alerting else { throw AlarmUpdateFailure.currentlyRinging }
        if existing != nil && previous == nil { throw AlarmUpdateFailure.inconsistentState }
        let unchanged = alarm.isEnabled && previous?.isEnabled == true && existing != nil
            && previous.map { alarm.hasSameSystemConfiguration(as: $0) } == true
        var mutated = false
        do {
            if !unchanged {
                if existing != nil { try backend.cancel(alarm.id); mutated = true }
                if alarm.isEnabled {
                    // Mark before the await because a remote registration can fail with an uncertain outcome.
                    mutated = true
                    try await backend.register(alarm)
                }
            }
            try commit()
        } catch {
            let original = error
            if mutated {
                do {
                    if try backend.state(of: alarm.id) != nil { try backend.cancel(alarm.id) }
                    if existing != nil, let previous, previous.isEnabled { try await backend.register(previous) }
                } catch {
                    throw AlarmUpdateFailure.recoveryFailed(original: original.localizedDescription, recovery: error.localizedDescription)
                }
            }
            throw original
        }
    }
}
