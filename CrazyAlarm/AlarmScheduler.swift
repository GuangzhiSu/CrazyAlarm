import ActivityKit
import AlarmKit
import SwiftUI

struct CrazyAlarmMetadata: AlarmMetadata { var alarmID: String }

@MainActor
final class AlarmScheduler: AlarmSchedulingBackend {
    let manager = AlarmManager.shared

    func authorize() async throws {
        let state = manager.authorizationState == .notDetermined
            ? try await manager.requestAuthorization() : manager.authorizationState
        guard state == .authorized else { throw SchedulingError.permissionDenied }
    }

    func state(of id: UUID) throws -> RegisteredAlarmState? {
        guard let alarm = try manager.alarms.first(where: { $0.id == id }) else { return nil }
        return alarm.state == .alerting ? .alerting : .scheduled
    }

    func register(_ alarm: AlarmRecord) async throws {
        try alarm.validate()
        try await authorize()
        let weekdays: [Locale.Weekday] = alarm.weekdays.sorted(by: { $0.rawValue < $1.rawValue }).map {
            switch $0 {
            case .sunday: .sunday
            case .monday: .monday
            case .tuesday: .tuesday
            case .wednesday: .wednesday
            case .thursday: .thursday
            case .friday: .friday
            case .saturday: .saturday
            }
        }
        let recurrence: Alarm.Schedule.Relative.Recurrence = weekdays.isEmpty ? .never : .weekly(weekdays)
        let schedule = Alarm.Schedule.relative(.init(time: .init(hour: alarm.hour, minute: alarm.minute), repeats: recurrence))
        let button = AlarmButton(text: "完成任务", textColor: .white, systemImageName: "brain.head.profile")
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: alarm.title),
                                            secondaryButton: button, secondaryButtonBehavior: .custom)
        } else {
            alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: alarm.title),
                                            stopButton: AlarmButton(text: "停止", textColor: .white, systemImageName: "stop.circle"),
                                            secondaryButton: button, secondaryButtonBehavior: .custom)
        }
        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert),
                                         metadata: CrazyAlarmMetadata(alarmID: alarm.id.uuidString),
                                         tintColor: Color(red: 0.18, green: 0.8, blue: 0.88))
        let configuration = AlarmManager.AlarmConfiguration<CrazyAlarmMetadata>.alarm(
            schedule: schedule, attributes: attributes,
            secondaryIntent: OpenQuizIntent(alarmID: alarm.id.uuidString),
            sound: .named(alarm.sound.alertFileName ?? "MorningSpark.wav"))
        _ = try await manager.schedule(id: alarm.id, configuration: configuration)
    }

    func cancel(_ id: UUID) throws {
        if try manager.alarms.contains(where: { $0.id == id }) { try manager.cancel(id: id) }
    }

    func stopIfAlerting(_ id: UUID) throws {
        if try manager.alarms.contains(where: { $0.id == id && $0.state == .alerting }) { try manager.stop(id: id) }
    }

    static func describe(_ error: Error) -> String {
        if error is PermissionProblem || error is AlarmUpdateFailure { return error.localizedDescription }
        let detail = error as NSError
        if let alarmError = error as? AlarmManager.AlarmError, alarmError == .maximumLimitReached {
            return "系统报告已达到闹钟登记上限，请关闭不需要的闹钟后重试。本次修改未保存。\n\(detail.domain) · \(detail.code)"
        }
        if detail.domain.contains("AlarmKit") {
            return "系统暂时无法保存闹钟，请稍后重试。本次修改未保存。\n\(detail.domain) · \(detail.code)"
        }
        return error.localizedDescription
    }
}

enum SchedulingError: LocalizedError {
    case permissionDenied
    var errorDescription: String? { "闹钟权限未开启。请到「设置 → App → CrazyAlarm → 闹钟」允许访问，再启用闹钟。" }
}
