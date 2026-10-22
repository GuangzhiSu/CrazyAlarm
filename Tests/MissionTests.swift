import Foundation
import XCTest
@testable import CrazyAlarmCore

final class MissionTests: XCTestCase {
    let questions = AlarmRecord().questions

    func testMixedTasksRequireEveryTaskInOrder() throws {
        let quiz = WakeMission(kind: .quiz)
        let typing = WakeMission(kind: .typing)
        var shake = WakeMission(kind: .shake); shake.target = 5
        var session = try MissionSession(missions: [quiz, typing, shake], questions: questions)
        XCTAssertEqual(session.submit("bad", questions: questions), .incorrect)
        XCTAssertEqual(session.submit("21", questions: questions), .progress)
        XCTAssertEqual(session.submit("56", questions: questions), .missionComplete)
        XCTAssertFalse(session.isComplete)
        XCTAssertEqual(session.recordEvidence(missionID: shake.id, kind: .shake, count: 5), .incorrect)
        XCTAssertEqual(session.submit(typing.text, questions: questions), .missionComplete)
        XCTAssertEqual(session.recordEvidence(missionID: shake.id, kind: .steps, count: 5), .incorrect)
        XCTAssertEqual(session.recordEvidence(missionID: UUID(), kind: .shake, count: 5), .incorrect)
        XCTAssertEqual(session.recordEvidence(missionID: shake.id, kind: .shake, count: -1), .incorrect)
        XCTAssertEqual(session.recordEvidence(missionID: shake.id, kind: .shake, count: 4), .progress)
        XCTAssertFalse(session.isComplete)
        XCTAssertEqual(session.recordEvidence(missionID: shake.id, kind: .shake), .allComplete)
        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.submit("21", questions: questions), .incorrect)
    }

    func testQuizIsOptionalButEmptyAndDuplicateSelectionsAreRejected() throws {
        let typing = WakeMission(kind: .typing)
        var session = try MissionSession(missions: [typing], questions: [])
        XCTAssertEqual(session.submit(typing.text, questions: []), .allComplete)
        XCTAssertThrowsError(try MissionSession(missions: [], questions: questions))
        XCTAssertThrowsError(try MissionSession(missions: [typing, typing], questions: questions))
    }

    func testOldAlarmWithoutMissionsMigratesWithoutLosingSettings() throws {
        var original = AlarmRecord(); original.title = "My old alarm"; original.isEnabled = true
        original.questions[0].answer = "custom"
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        object.removeValue(forKey: "missions")
        let restored = try JSONDecoder().decode(AlarmRecord.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.title, original.title)
        XCTAssertEqual(restored.questions, original.questions)
        XCTAssertEqual(restored.isEnabled, original.isEnabled)
        XCTAssertEqual(restored.missions.map(\.kind), [.quiz])
    }

    func testPuzzleAndProgressPersistExactlyAcrossRelaunch() throws {
        var mission = WakeMission(kind: .math); mission.target = 3
        var session = try MissionSession(missions: [mission], questions: [])
        let first = try XCTUnwrap(session.puzzle)
        XCTAssertEqual(session.submit(first.answer, questions: []), .progress)
        _ = session.submit("wrong", questions: [])
        let restored = try JSONDecoder().decode(MissionSession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(restored, session)
        XCTAssertEqual(restored.units, 1)
        XCTAssertEqual(restored.mistakes, 1)
        XCTAssertFalse(restored.isComplete)
    }

    func testBarcodeComparisonIsExactAndCannotBeCompletedAsSensorEvidence() throws {
        var mission = WakeMission(kind: .barcode); mission.barcode = "ABC-123"
        var session = try MissionSession(missions: [mission], questions: [])
        for text in ["", "abc-123", "ABC-123 ", "123"] { XCTAssertEqual(session.submit(text, questions: []), .incorrect) }
        XCTAssertEqual(session.recordEvidence(missionID: mission.id, kind: .barcode), .incorrect)
        XCTAssertEqual(session.submit("ABC-123", questions: []), .allComplete)
    }

    func testColorTilesOnlyAcceptDifferentTileAndGenerateNewRounds() throws {
        var mission = WakeMission(kind: .colorTiles); mission.target = 2; mission.difficulty = 3
        var session = try MissionSession(missions: [mission], questions: [])
        let first = try XCTUnwrap(session.puzzle)
        XCTAssertEqual(first.tileCount, 25)
        XCTAssertEqual(session.selectTile((first.differentTile + 1) % 25), .incorrect)
        XCTAssertEqual(session.units, 0)
        XCTAssertEqual(session.selectTile(first.differentTile), .progress)
        XCTAssertEqual(session.selectTile(try XCTUnwrap(session.puzzle).differentTile), .allComplete)
    }

    func testRandomMathAndSymbolsHaveCorrectAnswers() throws {
        for difficulty in 1...3 {
            for kind in [MissionKind.math, .missingSymbol] {
                var mission = WakeMission(kind: kind); mission.difficulty = difficulty
                for _ in 0..<100 {
                    let puzzle = try XCTUnwrap(MissionPuzzle.make(for: mission))
                    let parts = puzzle.prompt.split(separator: " ").map(String.init)
                    let a = try XCTUnwrap(Int(parts[0])), b = try XCTUnwrap(Int(parts[2]))
                    let operation = kind == .math ? parts[1] : puzzle.answer
                    let value = operation == "+" ? a + b : operation == "−" ? a - b : operation == "×" ? a * b : a / b
                    if kind == .math { XCTAssertEqual(puzzle.answer, String(value)) }
                    else {
                        XCTAssertEqual(parts[4], String(value))
                        XCTAssertEqual(Set([a + b, a - b, a * b, a / b]).count, 4)
                    }
                }
            }
        }
    }

    func testAllMissionConfigurationsCanBeEncodedAndValidated() throws {
        var all = MissionKind.allCases.map { WakeMission(kind: $0) }
        for index in all.indices {
            if all[index].kind == .barcode { all[index].barcode = "target" }
            if all[index].kind == .photo { all[index].referencePhoto = "reference.jpg" }
        }
        let session = try MissionSession(missions: all, questions: questions)
        XCTAssertEqual(try JSONDecoder().decode(MissionSession.self, from: JSONEncoder().encode(session)), session)
        var bad = WakeMission(kind: .photo); bad.referencePhoto = "../photo.jpg"
        XCTAssertThrowsError(try bad.validate())
        bad = WakeMission(kind: .steps); bad.target = Int.max
        XCTAssertThrowsError(try bad.validate())
        XCTAssertThrowsError(try WakeMission(kind: .barcode).validate())
    }

    func testLegacyQuizProgressCanResumeInsideMissionChain() throws {
        let mission = WakeMission(kind: .quiz)
        var legacy = try QuizSession(alarmID: UUID(), questions: questions)
        _ = legacy.submit("21")
        var session = try MissionSession(missions: [mission, WakeMission(kind: .typing)], questions: questions)
        session.restoreLegacyQuiz(legacy)
        XCTAssertEqual(session.units, 1)
        XCTAssertEqual(session.submit("56", questions: questions), .missionComplete)
        XCTAssertFalse(session.isComplete)
    }

    func testShakeRequiresAResetAndDebouncesNoise() {
        var counter = ShakeCounter()
        XCTAssertFalse(counter.sample(magnitude: 0.01, time: 0))
        XCTAssertTrue(counter.sample(magnitude: 1.5, time: 1))
        XCTAssertFalse(counter.sample(magnitude: 1.8, time: 3))
        XCTAssertFalse(counter.sample(magnitude: 0.1, time: 3.1))
        XCTAssertTrue(counter.sample(magnitude: 1.7, time: 3.7))
        XCTAssertFalse(counter.sample(magnitude: 0.2, time: 3.8))
        XCTAssertFalse(counter.sample(magnitude: 1.8, time: 3.9))
    }

    func testSquatRequiresACompleteVisibleCycleAndResetsOnOcclusion() {
        var counter = SquatCounter()
        for time in [0.0, 0.1, 0.2] { XCTAssertFalse(counter.sample(angle: 90, time: time)) }
        for time in [0.3, 0.4, 0.5] { XCTAssertFalse(counter.sample(angle: 170, time: time)) }
        for time in [0.6, 0.7, 0.8] { XCTAssertFalse(counter.sample(angle: 95, time: time)) }
        XCTAssertFalse(counter.sample(angle: 170, time: 1.2))
        XCTAssertFalse(counter.sample(angle: 170, time: 1.3))
        XCTAssertTrue(counter.sample(angle: 170, time: 1.4))
        XCTAssertFalse(counter.sample(angle: nil, time: 3))
        for time in [3.1, 3.2, 3.3] { XCTAssertFalse(counter.sample(angle: 170, time: time)) }
        XCTAssertFalse(counter.sample(angle: 170, time: 3.4))
    }

    func testSpeechMustMatchWordBeatAndCannotDoubleCountPartialResults() {
        var gate = VoiceBeatGate()
        XCTAssertFalse(gate.accept(word: "起床", expected: "起床", timestamp: 2, bpm: 60))
        XCTAssertFalse(gate.accept(word: "你好", expected: "起床", timestamp: 3, bpm: 60))
        XCTAssertTrue(gate.accept(word: "起 床！", expected: "起床", timestamp: 3.05, bpm: 60))
        XCTAssertFalse(gate.accept(word: "起床", expected: "起床", timestamp: 3.1, bpm: 60))
        XCTAssertFalse(gate.accept(word: "起床", expected: "起床", timestamp: 4.5, bpm: 60))
        XCTAssertTrue(gate.accept(word: "起床", expected: "起床", timestamp: 5, bpm: 60))
        XCTAssertFalse(gate.accept(word: "起床", expected: "起床", timestamp: .nan, bpm: 60))
    }
}
