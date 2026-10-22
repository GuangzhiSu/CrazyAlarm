import Foundation

enum MissionKind: String, Codable, CaseIterable, Sendable {
    case quiz, household, speech, colorTiles, typing, math, missingSymbol, steps, barcode, shake, photo, squat

    var title: String {
        switch self {
        case .quiz: "自定义 Quiz"
        case .household: "寻找家中物品"
        case .speech: "跟着节拍说词语"
        case .colorTiles: "找不同色块"
        case .typing: "打字"
        case .math: "数学计算"
        case .missingSymbol: "填运算符"
        case .steps: "走路"
        case .barcode: "扫码"
        case .shake: "摇一摇"
        case .photo: "拍照匹配"
        case .squat: "深蹲"
        }
    }
    var icon: String {
        switch self {
        case .quiz: "brain.head.profile"
        case .household: "viewfinder"
        case .speech: "waveform"
        case .colorTiles: "square.grid.3x3.fill"
        case .typing: "keyboard"
        case .math: "plus.forwardslash.minus"
        case .missingSymbol: "plusminus"
        case .steps: "figure.walk"
        case .barcode: "qrcode.viewfinder"
        case .shake: "iphone.radiowaves.left.and.right"
        case .photo: "camera.fill"
        case .squat: "figure.strengthtraining.functional"
        }
    }
    var group: Int {
        switch self {
        case .household, .speech: 0
        case .quiz, .colorTiles, .typing, .math, .missingSymbol: 1
        default: 2
        }
    }
    var detail: String {
        switch self {
        case .quiz: "依次答对你设置的两道题"
        case .household: "用相机寻找指定物品，本机识别"
        case .speech: "在节拍亮起时说出指定词语"
        case .colorTiles: "找出颜色不同的一格"
        case .typing: "准确输入指定句子"
        case .math: "完成随机生成的算术题"
        case .missingSymbol: "为等式选择正确的运算符"
        case .steps: "拿着手机走够指定步数"
        case .barcode: "扫描事先绑定的二维码或条形码"
        case .shake: "摇动手机达到指定次数"
        case .photo: "重新拍摄同一物品，与参考照片匹配"
        case .squat: "放稳手机，让全身入镜并完成深蹲"
        }
    }
    var countRange: ClosedRange<Int> {
        switch self {
        case .quiz: 2...2
        case .household, .barcode, .photo: 1...1
        case .steps: 5...100
        case .shake: 5...80
        case .squat: 1...20
        default: 1...10
        }
    }
    var defaultCount: Int {
        switch self {
        case .quiz: 2
        case .steps: 20
        case .shake: 15
        case .squat: 5
        case .math, .missingSymbol, .colorTiles, .speech: 3
        default: 1
        }
    }
}

enum HouseholdItem: String, Codable, CaseIterable, Sendable {
    case cup, bottle, book, keyboard, chair, shoe
    var title: String {
        switch self {
        case .cup: "杯子"
        case .bottle: "瓶子"
        case .book: "书"
        case .keyboard: "键盘"
        case .chair: "椅子"
        case .shoe: "鞋子"
        }
    }
    var keywords: [String] {
        switch self {
        case .cup: ["cup", "mug", "teacup"]
        case .bottle: ["bottle"]
        case .book: ["book", "novel", "comic"]
        case .keyboard: ["keyboard", "computer_keyboard"]
        case .chair: ["chair", "armchair", "rocking_chair"]
        case .shoe: ["shoe", "sneaker", "footwear", "running_shoe"]
        }
    }
    func matches(_ identifier: String) -> Bool {
        let normalized = identifier.lowercased().replacingOccurrences(of: " ", with: "_")
        return keywords.contains { normalized == $0 || normalized.hasSuffix("_" + $0) }
    }
}

struct WakeMission: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var kind: MissionKind
    var target: Int
    var difficulty = 1
    var text = "今天也要认真生活"
    var speechLocale = "zh-CN"
    var beatsPerMinute = 60
    var barcode = ""
    var referencePhoto: String?
    var householdItem = HouseholdItem.cup

    init(kind: MissionKind) {
        self.kind = kind
        target = kind.defaultCount
        if kind == .speech { text = "起床" }
    }

    func validate() throws {
        guard kind.countRange.contains(target), (1...3).contains(difficulty),
              (40...100).contains(beatsPerMinute), ["zh-CN", "en-US"].contains(speechLocale) else {
            throw MissionError.invalidConfiguration
        }
        if kind == .typing || kind == .speech {
            guard !QuizQuestion.normalize(text).isEmpty, text.count <= (kind == .speech ? 12 : 180) else {
                throw MissionError.missingText
            }
        }
        if kind == .barcode, barcode.isEmpty || barcode.count > 4096 { throw MissionError.missingBarcode }
        if kind == .photo {
            guard let referencePhoto, referencePhoto == (referencePhoto as NSString).lastPathComponent,
                  referencePhoto.hasSuffix(".jpg") else { throw MissionError.missingReference }
        }
    }
}

enum MissionError: LocalizedError {
    case invalidConfiguration, missingText, missingBarcode, missingReference, invalidSelection
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "任务次数或难度不正确，请重新设置。"
        case .missingText: "请输入任务的句子或短词；节拍词语最多 12 个字符，打字句子最多 180 个字符。"
        case .missingBarcode: "请先扫描或填写需要绑定的二维码 / 条形码。"
        case .missingReference: "请先拍摄一张参考照片。"
        case .invalidSelection: "至少选择一种任务，同一种任务只能添加一次。"
        }
    }
}

struct MissionPuzzle: Codable, Equatable, Sendable {
    var prompt: String
    var answer: String
    var tileCount = 0
    var differentTile = -1
    var hue = Double.random(in: 0...1)

    static func make(for mission: WakeMission) -> MissionPuzzle? {
        switch mission.kind {
        case .math:
            let limit = mission.difficulty == 1 ? 20 : (mission.difficulty == 2 ? 50 : 100)
            let a = Int.random(in: 2...limit), b = Int.random(in: 2...limit)
            if mission.difficulty == 1 {
                return Bool.random() ? .init(prompt: "\(a) + \(b) = ?", answer: String(a + b))
                    : .init(prompt: "\(max(a,b)) − \(min(a,b)) = ?", answer: String(abs(a - b)))
            }
            let x = Int.random(in: 2...(mission.difficulty == 2 ? 12 : 25))
            let y = Int.random(in: 2...12)
            return Bool.random() ? .init(prompt: "\(x) × \(y) = ?", answer: String(x * y))
                : .init(prompt: "\(x * y) ÷ \(y) = ?", answer: String(x))
        case .missingSymbol:
            // a > b > 1 and a is a multiple of b; all four operations have distinct results.
            let b = Int.random(in: 3...(mission.difficulty == 1 ? 6 : 12))
            let a = b * Int.random(in: 3...(mission.difficulty == 3 ? 15 : 6))
            let symbol = ["+", "−", "×", "÷"].randomElement()!
            let value = symbol == "+" ? a + b : symbol == "−" ? a - b : symbol == "×" ? a * b : a / b
            return .init(prompt: "\(a)  □  \(b) = \(value)", answer: symbol)
        case .colorTiles:
            let edge = mission.difficulty + 2
            return .init(prompt: "找到颜色不同的一格", answer: "", tileCount: edge * edge,
                         differentTile: Int.random(in: 0..<(edge * edge)))
        default: return nil
        }
    }
}

struct MissionSession: Codable, Equatable, Sendable {
    enum Result: Equatable { case incorrect, progress, missionComplete, allComplete }
    private(set) var missions: [WakeMission]
    private(set) var index = 0
    private(set) var units = 0
    private(set) var mistakes = 0
    private(set) var puzzle: MissionPuzzle?
    var current: WakeMission? { missions.indices.contains(index) ? missions[index] : nil }
    var isComplete: Bool { index == missions.count && !missions.isEmpty }

    init(missions: [WakeMission], questions: [QuizQuestion]) throws {
        guard !missions.isEmpty, missions.count <= MissionKind.allCases.count,
              Set(missions.map(\.kind)).count == missions.count else { throw MissionError.invalidSelection }
        for mission in missions { try mission.validate() }
        if missions.contains(where: { $0.kind == .quiz }) {
            _ = try QuizSession(alarmID: UUID(), questions: questions)
        }
        self.missions = missions
        puzzle = MissionPuzzle.make(for: missions[0])
    }

    mutating func restoreLegacyQuiz(_ quiz: QuizSession) {
        guard current?.kind == .quiz else { return }
        for _ in 0..<min(quiz.correctCount, 2) { _ = advance() }
    }

    mutating func submit(_ text: String, questions: [QuizQuestion]) -> Result {
        guard let mission = current else { return .incorrect }
        let correct: Bool
        switch mission.kind {
        case .quiz: correct = questions.indices.contains(units) && questions[units].accepts(text)
        case .typing: correct = QuizQuestion.normalize(text) == QuizQuestion.normalize(mission.text)
        case .math, .missingSymbol: correct = QuizQuestion.normalize(text) == puzzle?.answer
        case .barcode: correct = text == mission.barcode
        default: correct = false
        }
        guard correct else { mistakes += 1; return .incorrect }
        return advance()
    }

    mutating func selectTile(_ tile: Int) -> Result {
        guard current?.kind == .colorTiles, let puzzle, tile == puzzle.differentTile else {
            mistakes += 1; return .incorrect
        }
        return advance()
    }

    mutating func recordEvidence(missionID: UUID, kind: MissionKind, count: Int = 1) -> Result {
        let allowed: Set<MissionKind> = [.household, .speech, .steps, .shake, .photo, .squat]
        guard let mission = current, mission.id == missionID, mission.kind == kind,
              allowed.contains(kind), count > 0 else { return .incorrect }
        return advance(by: count)
    }

    private mutating func advance(by amount: Int = 1) -> Result {
        guard let mission = current else { return .incorrect }
        units = min(mission.target, units + min(amount, mission.target))
        guard units == mission.target else { puzzle = MissionPuzzle.make(for: mission); return .progress }
        index += 1; units = 0
        puzzle = current.flatMap { MissionPuzzle.make(for: $0) }
        return isComplete ? .allComplete : .missionComplete
    }
}

/// Edge-triggered shake counting: sustained acceleration and sensor jitter do not add repetitions.
struct ShakeCounter {
    private var armed = true
    private var last = -Double.infinity
    mutating func sample(magnitude: Double, time: Double) -> Bool {
        if magnitude < 0.35 { armed = true }
        guard armed, magnitude > 1.25, time - last > 0.4 else { return false }
        armed = false; last = time; return true
    }
}

/// Requires a visible stand → crouch → stand cycle, with several stable frames at each end.
struct SquatCounter {
    private var phase = 0
    private var stableFrames = 0
    private var downAt = 0.0
    private var lastVisible = -Double.infinity
    mutating func sample(angle: Double?, time: Double) -> Bool {
        guard let angle, angle.isFinite else {
            stableFrames = 0
            if time - lastVisible > 0.8 { phase = 0 }
            return false
        }
        if time - lastVisible > 0.8 { phase = 0; stableFrames = 0 }
        lastVisible = time
        let atTarget = phase == 1 ? angle < 110 : angle > 155
        stableFrames = atTarget ? stableFrames + 1 : 0
        guard stableFrames >= 3 else { return false }
        stableFrames = 0
        if phase == 0 { phase = 1; return false }
        if phase == 1 { phase = 2; downAt = time; return false }
        guard time - downAt >= 0.4 else { return false }
        phase = 1; return true
    }
}

struct VoiceBeatGate {
    private var acceptedStarts = Set<Int>()
    static func normalize(_ text: String) -> String {
        QuizQuestion.normalize(text).filter { $0.isLetter || $0.isNumber }
    }
    mutating func accept(word: String, expected: String, timestamp: Double, bpm: Int) -> Bool {
        guard !Self.normalize(expected).isEmpty, Self.normalize(word) == Self.normalize(expected),
              (40...100).contains(bpm), timestamp.isFinite else { return false }
        let period = 60.0 / Double(bpm)
        guard timestamp >= period * 2.65 else { return false }
        let beat = (timestamp / period).rounded()
        let key = Int(beat)
        guard abs(timestamp - beat * period) <= period * 0.3, !acceptedStarts.contains(key) else { return false }
        acceptedStarts.insert(key); return true
    }
}
