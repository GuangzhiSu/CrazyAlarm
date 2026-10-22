import Foundation
import XCTest
@testable import CrazyAlarmCore

final class PermissionTests: XCTestCase {
    func testEachMissionRequestsOnlyItsActualPermissions() {
        for kind in MissionKind.allCases {
            let permissions = TaskPermission.required(for: [WakeMission(kind: kind)], includeAlarms: false)
            switch kind {
            case .squat, .photo, .barcode, .household: XCTAssertEqual(permissions, [.camera])
            case .speech: XCTAssertEqual(permissions, [.microphone, .speech])
            case .steps: XCTAssertEqual(permissions, [.motion])
            default: XCTAssertTrue(permissions.isEmpty)
            }
        }
    }
    func testCombinedPermissionsAreDeduplicatedAndOrdered() {
        let missions = MissionKind.allCases.map { WakeMission(kind: $0) }
        XCTAssertEqual(TaskPermission.required(for: missions), TaskPermission.allCases)
        XCTAssertEqual(TaskPermission.required(for: [WakeMission(kind: .quiz)]), [.alarms])
    }
    @MainActor func testFirstUseRequestsAndThenChecksSystemStatus() async throws {
        var access: [TaskPermission: PermissionAccess] = [.camera: .notDetermined, .microphone: .authorized]
        var requested: [TaskPermission] = []
        try await PermissionPreflight.ensure([.camera, .microphone], status: { access[$0] ?? .unavailable }, request: {
            requested.append($0); access[$0] = .authorized
        })
        XCTAssertEqual(requested, [.camera])
    }
    @MainActor func testDeniedPermissionDoesNotPromptAgainOrReachLaterRequests() async throws {
        var requested: [TaskPermission] = []
        do {
            try await PermissionPreflight.ensure([.camera, .microphone], status: { $0 == .camera ? .denied : .notDetermined }, request: { requested.append($0) })
            XCTFail()
        } catch {
            let problem = try XCTUnwrap(error as? PermissionProblem)
            XCTAssertEqual(problem.permission, .camera); XCTAssertTrue(problem.needsSettings)
        }
        XCTAssertTrue(requested.isEmpty)
    }
    @MainActor func testReturningFromPromptWithoutPermissionNeverCountsAsGranted() async throws {
        for denied in [PermissionAccess.denied, .restricted, .notDetermined, .unavailable] {
            var access = PermissionAccess.notDetermined
            do {
                try await PermissionPreflight.ensure([.motion], status: { _ in access }, request: { _ in access = denied })
                XCTFail("Unapproved permission passed preflight")
            } catch { XCTAssertTrue(error is PermissionProblem) }
        }
    }
    @MainActor func testAuthorizedPermissionsDoNotRequestNewPrompts() async throws {
        var prompted = false
        try await PermissionPreflight.ensure(TaskPermission.allCases, status: { _ in .authorized }, request: { _ in prompted = true })
        XCTAssertFalse(prompted)
    }
}
