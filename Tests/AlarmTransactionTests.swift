import Foundation
import XCTest
@testable import CrazyAlarmCore

private enum SimulatedFailure: Error { case registration, storage, cancellation }

@MainActor
private final class FakeAlarmBackend: AlarmSchedulingBackend {
    var records: [UUID: AlarmRecord] = [:]
    var ringing = Set<UUID>()
    var cancelled: [UUID] = []
    var registered: [AlarmRecord] = []
    var failRegistrations = Set<Int>()
    var failCancellation = false
    var registerBeforeThrow = false
    func state(of id: UUID) throws -> RegisteredAlarmState? {
        if ringing.contains(id) { return .alerting }
        return records[id] == nil ? nil : .scheduled
    }
    func cancel(_ id: UUID) throws {
        if failCancellation { throw SimulatedFailure.cancellation }
        cancelled.append(id); records[id] = nil
    }
    func register(_ alarm: AlarmRecord) async throws {
        registered.append(alarm)
        if failRegistrations.contains(registered.count) {
            if registerBeforeThrow { records[alarm.id] = alarm }
            throw SimulatedFailure.registration
        }
        records[alarm.id] = alarm
    }
}

final class AlarmTransactionTests: XCTestCase {
    @MainActor func testTaskOnlyEditDoesNotRescheduleEnabledAlarm() async throws {
        let backend = FakeAlarmBackend()
        var old = AlarmRecord(); old.isEnabled = true; backend.records[old.id] = old
        var updated = old; updated.missions = [WakeMission(kind: .squat)]
        var saved = false
        try await AlarmUpdateTransaction.perform(updated, previous: old, backend: backend) { saved = true }
        XCTAssertTrue(saved); XCTAssertTrue(backend.cancelled.isEmpty); XCTAssertTrue(backend.registered.isEmpty)
    }
    @MainActor func testTimeEditCancelsBeforeRegisteringSameIDAndPreservesOtherAlarms() async throws {
        let backend = FakeAlarmBackend()
        var old = AlarmRecord(); old.isEnabled = true
        let other = AlarmRecord(); backend.records = [old.id: old, other.id: other]
        var updated = old; updated.minute = 31
        try await AlarmUpdateTransaction.perform(updated, previous: old, backend: backend, commit: {})
        XCTAssertEqual(backend.cancelled, [old.id]); XCTAssertEqual(backend.records[old.id], updated)
        XCTAssertEqual(backend.records[other.id], other); XCTAssertEqual(backend.registered.count, 1)
    }
    @MainActor func testFailedUpdateRestoresPreviousTimeAndDoesNotCommit() async throws {
        let backend = FakeAlarmBackend()
        var old = AlarmRecord(); old.isEnabled = true; backend.records[old.id] = old
        var updated = old; updated.hour = 9
        backend.failRegistrations = [1]
        var saved = false
        do { try await AlarmUpdateTransaction.perform(updated, previous: old, backend: backend) { saved = true }; XCTFail() }
        catch { XCTAssertTrue(error is SimulatedFailure) }
        XCTAssertFalse(saved); XCTAssertEqual(backend.records[old.id], old)
        XCTAssertEqual(backend.registered.map(\.hour), [9, old.hour])
    }
    @MainActor func testPersistenceFailureRestoresOriginalSystemAlarm() async throws {
        let backend = FakeAlarmBackend()
        var old = AlarmRecord(); old.isEnabled = true; backend.records[old.id] = old
        var updated = old; updated.minute = 42
        do { try await AlarmUpdateTransaction.perform(updated, previous: old, backend: backend) { throw SimulatedFailure.storage }; XCTFail() }
        catch { XCTAssertTrue(error is SimulatedFailure) }
        XCTAssertEqual(backend.records[old.id], old); XCTAssertEqual(backend.registered.count, 2)
    }
    @MainActor func testUncertainRegistrationIsRemovedBeforeRestoringOriginal() async throws {
        let backend = FakeAlarmBackend()
        var old = AlarmRecord(); old.isEnabled = true; backend.records[old.id] = old
        var updated = old; updated.hour = 10
        backend.failRegistrations = [1]; backend.registerBeforeThrow = true
        do { try await AlarmUpdateTransaction.perform(updated, previous: old, backend: backend, commit: {}); XCTFail() }
        catch {}
        XCTAssertEqual(backend.cancelled, [old.id, old.id]); XCTAssertEqual(backend.records[old.id], old)
    }
    @MainActor func testFailedRecoveryIsReportedExplicitly() async throws {
        let backend = FakeAlarmBackend()
        var old = AlarmRecord(); old.isEnabled = true; backend.records[old.id] = old
        var updated = old; updated.hour = 10; backend.failRegistrations = [1, 2]
        do { try await AlarmUpdateTransaction.perform(updated, previous: old, backend: backend, commit: {}); XCTFail() }
        catch { guard case AlarmUpdateFailure.recoveryFailed = error else { return XCTFail("Recovery failure was hidden") } }
    }
    @MainActor func testFreshAlarmPersistenceFailureRemovesOnlyNewRegistration() async throws {
        let backend = FakeAlarmBackend()
        let other = AlarmRecord(); backend.records[other.id] = other
        var alarm = AlarmRecord(); alarm.isEnabled = true
        do { try await AlarmUpdateTransaction.perform(alarm, previous: nil, backend: backend) { throw SimulatedFailure.storage }; XCTFail() }
        catch {}
        XCTAssertNil(backend.records[alarm.id]); XCTAssertEqual(backend.records[other.id], other)
    }
    @MainActor func testRingingAlarmAndFailedCancellationCannotBeOverwritten() async throws {
        let backend = FakeAlarmBackend()
        var old = AlarmRecord(); old.isEnabled = true; backend.records[old.id] = old; backend.ringing.insert(old.id)
        var updated = old; updated.hour = 15
        do { try await AlarmUpdateTransaction.perform(updated, previous: old, backend: backend, commit: {}); XCTFail() }
        catch { XCTAssertTrue(error is AlarmUpdateFailure) }
        backend.ringing = []; backend.failCancellation = true
        do { try await AlarmUpdateTransaction.perform(updated, previous: old, backend: backend, commit: {}); XCTFail() }
        catch {}
        XCTAssertEqual(backend.records[old.id], old); XCTAssertTrue(backend.registered.isEmpty)
    }
    @MainActor func testDisableRollbackAndMissingRegistrationRepair() async throws {
        let backend = FakeAlarmBackend()
        var old = AlarmRecord(); old.isEnabled = true; backend.records[old.id] = old
        var disabled = old; disabled.isEnabled = false
        do { try await AlarmUpdateTransaction.perform(disabled, previous: old, backend: backend) { throw SimulatedFailure.storage }; XCTFail() }
        catch {}
        XCTAssertEqual(backend.records[old.id], old)
        backend.records[old.id] = nil
        try await AlarmUpdateTransaction.perform(old, previous: old, backend: backend, commit: {})
        XCTAssertEqual(backend.records[old.id], old)
    }
}
