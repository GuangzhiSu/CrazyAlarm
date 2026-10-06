import Foundation

struct QuizQuestion: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var prompt: String
    var answer: String

    static func normalize(_ value: String) -> String {
        value.precomposedStringWithCompatibilityMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    func accepts(_ value: String) -> Bool {
        !Self.normalize(answer).isEmpty && Self.normalize(value) == Self.normalize(answer)
    }
}

struct QuizSession: Codable, Equatable, Sendable {
    enum Result: Equatable { case incorrect, nextQuestion, complete, alreadyComplete }
    let alarmID: UUID
    private(set) var questions: [QuizQuestion]
    private(set) var correctCount = 0
    private(set) var mistakes = 0

    init(alarmID: UUID, questions: [QuizQuestion]) throws {
        guard questions.count == 2,
              questions.allSatisfy({ !$0.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && !QuizQuestion.normalize($0.answer).isEmpty }) else {
            throw AlarmValidationError.invalidQuestions
        }
        self.alarmID = alarmID
        self.questions = questions
    }

    var isComplete: Bool { correctCount == 2 }
    var currentQuestion: QuizQuestion? {
        questions.indices.contains(correctCount) ? questions[correctCount] : nil
    }

    mutating func submit(_ answer: String) -> Result {
        guard !isComplete, let question = currentQuestion else { return .alreadyComplete }
        guard question.accepts(answer) else { mistakes += 1; return .incorrect }
        correctCount += 1
        return isComplete ? .complete : .nextQuestion
    }
}

enum Weekday: Int, Codable, CaseIterable, Sendable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    var shortName: String { ["", "日", "一", "二", "三", "四", "五", "六"][rawValue] }
}

struct AlarmSound: Codable, Equatable, Sendable {
    var title: String
    /// Relative names only; full audio and the <=28-second system alert live in Library/Sounds.
    var fileName: String?
    var alertFileName: String?
    static let builtIn = AlarmSound(title: "Morning Spark · 内置铃声")
}

enum AlarmValidationError: LocalizedError {
    case invalidTime, invalidQuestions, missingSound
    var errorDescription: String? {
        switch self {
        case .invalidTime: "请选择有效的闹钟时间。"
        case .invalidQuestions: "请填写两道题的题目和正确答案。"
        case .missingSound: "所选音乐文件已不可用，请重新导入。"
        }
    }
}

struct AlarmRecord: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var title = "Wake up early"
    var hour = 7
    var minute = 20
    var weekdays: Set<Weekday> = Set(Weekday.allCases)
    var isEnabled = false
    var sound = AlarmSound.builtIn
    var questions = [QuizQuestion(prompt: "12 + 9 = ?", answer: "21"),
                     QuizQuestion(prompt: "8 × 7 = ?", answer: "56")]

    var timeText: String { String(format: "%02d:%02d", hour, minute) }
    var repeatText: String {
        if weekdays.isEmpty { return "仅一次" }
        if weekdays.count == 7 { return "每天" }
        return "周" + weekdays.sorted(by: { $0.rawValue < $1.rawValue }).map(\.shortName).joined(separator: "、")
    }

    func validate() throws {
        guard (0...23).contains(hour), (0...59).contains(minute) else { throw AlarmValidationError.invalidTime }
        _ = try QuizSession(alarmID: id, questions: questions)
    }

    func nextFireDate(after now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        if weekdays.isEmpty {
            return calendar.nextDate(after: now, matching: DateComponents(hour: hour, minute: minute),
                                     matchingPolicy: .nextTime, repeatedTimePolicy: .first)
        }
        return weekdays.compactMap { day in
            calendar.nextDate(after: now, matching: DateComponents(hour: hour, minute: minute, weekday: day.rawValue),
                              matchingPolicy: .nextTime, repeatedTimePolicy: .first)
        }.min()
    }
}
