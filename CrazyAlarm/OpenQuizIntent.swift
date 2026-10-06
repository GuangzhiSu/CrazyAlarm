import AppIntents
import Foundation

struct OpenQuizIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "打开 CrazyAlarm 答题"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "闹钟 ID") var alarmID: String

    init() {}
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(alarmID, forKey: "pendingQuizAlarmID")
        return .result()
    }
}
