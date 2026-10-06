import Foundation
import XCTest
@testable import CrazyAlarmCore

final class QuizTests: XCTestCase {
    func makeSession() throws -> QuizSession {
        try QuizSession(alarmID: UUID(), questions: [
            QuizQuestion(prompt: "12 + 9?", answer: "21"),
            QuizQuestion(prompt: "Greeting?", answer: "Hello")
        ])
    }

    func testBothCorrectAnswersAreRequired() throws {
        var session = try makeSession()
        XCTAssertEqual(session.submit("21"), .nextQuestion)
        XCTAssertFalse(session.isComplete)
        XCTAssertEqual(session.currentQuestion?.prompt, "Greeting?")
        XCTAssertEqual(session.submit("hello"), .complete)
        XCTAssertTrue(session.isComplete)
        XCTAssertNil(session.currentQuestion)
        XCTAssertEqual(session.submit("hello"), .alreadyComplete)
    }

    func testWrongAnswersNeverAdvanceOrComplete() throws {
        var session = try makeSession()
        for _ in 0..<100 { XCTAssertEqual(session.submit("wrong"), .incorrect) }
        XCTAssertEqual(session.correctCount, 0)
        XCTAssertEqual(session.mistakes, 100)
        XCTAssertFalse(session.isComplete)
        XCTAssertEqual(session.submit("21"), .nextQuestion)
        XCTAssertEqual(session.submit("21"), .incorrect)
        XCTAssertEqual(session.correctCount, 1)
        XCTAssertFalse(session.isComplete)
    }

    func testEmptyWhitespaceAndSubstringAreNotCorrect() throws {
        var session = try makeSession()
        for invalid in ["", " \n ", "2", "211", "answer 21", "2 1"] {
            XCTAssertEqual(session.submit(invalid), .incorrect)
        }
        XCTAssertFalse(session.isComplete)
    }

    func testNormalizationUsesFullwidthCaseAndOuterWhitespace() {
        let question = QuizQuestion(prompt: "Answer?", answer: "Hello 21")
        XCTAssertTrue(question.accepts("  ＨＥＬＬＯ ２１\n"))
        XCTAssertFalse(question.accepts("Hello21"))
        XCTAssertFalse(QuizQuestion(prompt: "x", answer: "  ").accepts(""))
    }

    func testInvalidQuestionSetsAreRejected() {
        for questions in [[], [QuizQuestion(prompt: "x", answer: "1")],
                          [QuizQuestion(prompt: "x", answer: "1"), QuizQuestion(prompt: "", answer: "2")],
                          [QuizQuestion(prompt: "x", answer: "1"), QuizQuestion(prompt: "y", answer: "  ")]] {
            XCTAssertThrowsError(try QuizSession(alarmID: UUID(), questions: questions))
        }
    }

    func testChallengeProgressSurvivesRelaunch() throws {
        var session = try makeSession()
        _ = session.submit("21")
        _ = session.submit("wrong")
        let restored = try JSONDecoder().decode(QuizSession.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(restored, session)
        XCTAssertEqual(restored.correctCount, 1)
        XCTAssertEqual(restored.mistakes, 1)
        XCTAssertFalse(restored.isComplete)
    }
}
