import AlarmKit
import AVFoundation
import CoreMotion
import Speech
import SwiftUI
import UIKit

@MainActor
final class DevicePermissionCenter {
    static let shared = DevicePermissionCenter()
    private let pedometer = CMPedometer()
    private let motion = CMMotionManager()
    private var requests: [TaskPermission: Task<Void, Never>] = [:]
    private init() {}

    func status(_ permission: TaskPermission) -> PermissionAccess {
        switch permission {
        case .alarms:
            switch AlarmManager.shared.authorizationState {
            case .authorized: return .authorized
            case .notDetermined: return .notDetermined
            case .denied: return .denied
            @unknown default: return .unavailable
            }
        case .camera:
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return .unavailable }
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: return .authorized
            case .notDetermined: return .notDetermined
            case .denied: return .denied
            case .restricted: return .restricted
            @unknown default: return .unavailable
            }
        case .microphone:
            switch AVAudioApplication.shared.recordPermission {
            case .granted: return .authorized
            case .undetermined: return .notDetermined
            case .denied: return .denied
            @unknown default: return .unavailable
            }
        case .speech:
            switch SFSpeechRecognizer.authorizationStatus() {
            case .authorized: return .authorized
            case .notDetermined: return .notDetermined
            case .denied: return .denied
            case .restricted: return .restricted
            @unknown default: return .unavailable
            }
        case .motion:
            guard CMPedometer.isStepCountingAvailable() else { return .unavailable }
            switch CMPedometer.authorizationStatus() {
            case .authorized: return .authorized
            case .notDetermined: return .notDetermined
            case .denied: return .denied
            case .restricted: return .restricted
            @unknown default: return .unavailable
            }
        }
    }

    func request(_ permission: TaskPermission) async {
        if let existing = requests[permission] { await existing.value; return }
        guard status(permission) == .notDetermined else { return }
        let task = Task { @MainActor in
            switch permission {
            case .alarms: _ = try? await AlarmManager.shared.requestAuthorization()
            case .camera: _ = await AVCaptureDevice.requestAccess(for: .video)
            case .microphone:
                _ = await withCheckedContinuation { continuation in
                    AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
                }
            case .speech:
                _ = await withCheckedContinuation { continuation in
                    SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
                }
            case .motion:
                // This query triggers the system consent prompt; its values never count toward a mission.
                let end = Date()
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    self.pedometer.queryPedometerData(from: end.addingTimeInterval(-1), to: end) { _, _ in
                        continuation.resume()
                    }
                }
            }
        }
        requests[permission] = task
        await task.value
        requests[permission] = nil
    }

    func ensurePermissions(_ permissions: [TaskPermission]) async throws {
        try await PermissionPreflight.ensure(permissions, status: status, request: request)
    }

    func ensure(missions: [WakeMission], includeAlarms: Bool = true) async throws {
        try await ensurePermissions(TaskPermission.required(for: missions, includeAlarms: includeAlarms))
        if missions.contains(where: { $0.kind == .shake }), !motion.isDeviceMotionAvailable {
            throw PermissionProblem(permission: .motion, access: .unavailable)
        }
        for mission in missions where mission.kind == .speech {
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: mission.speechLocale)),
                  recognizer.supportsOnDeviceRecognition else {
                throw PermissionProblem(permission: .speech, access: .unavailable)
            }
        }
    }

    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    var canShake: Bool { motion.isDeviceMotionAvailable }
}

struct MissionPermissionPanel: View {
    var missions: [WakeMission]
    var includeAlarms = true
    var showAll = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var statuses: [TaskPermission: PermissionAccess] = [:]
    @State private var requesting = false
    @State private var feedback: String?
    private var required: [TaskPermission] { TaskPermission.required(for: missions, includeAlarms: includeAlarms) }
    private var rows: [TaskPermission] { showAll ? TaskPermission.allCases : required }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("任务权限与传感器", systemImage: "checkmark.shield").font(.headline)
            ForEach(rows, id: \.self) { permission in
                let access = statuses[permission] ?? DevicePermissionCenter.shared.status(permission)
                HStack {
                    Text(permission.title).font(.callout)
                    Spacer()
                    if access == .notDetermined {
                        Button("允许") { request(permission) }.foregroundStyle(Theme.cyan)
                    } else if access == .denied || access == .restricted {
                        Button("去系统设置") { DevicePermissionCenter.openSettings() }.foregroundStyle(Theme.coral)
                    } else {
                        Label(access.title, systemImage: access == .authorized ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .font(.caption).foregroundStyle(access == .authorized ? Theme.cyan : Theme.coral)
                    }
                }
            }
            if missions.contains(where: { $0.kind == .shake }) {
                Text(DevicePermissionCenter.shared.canShake ? "摇动：传感器可用，无需独立权限弹窗。" : "摇动：此设备的传感器不可用。")
                    .font(.caption).foregroundStyle(Theme.secondary)
            }
            if !required.isEmpty {
                Button(requesting ? "等待系统授权…" : "检查并请求所选任务权限") {
                    requesting = true
                    Task { @MainActor in
                        defer { requesting = false; refresh() }
                        do { try await DevicePermissionCenter.shared.ensure(missions: missions, includeAlarms: includeAlarms); feedback = "所选任务权限与传感器检查通过。" }
                        catch { feedback = error.localizedDescription }
                    }
                }.font(.callout).foregroundStyle(Theme.cyan)
            } else {
                Text("这些任务无需额外的相机、麦克风或计步权限。").font(.caption).foregroundStyle(Theme.secondary)
            }
            if let feedback { Text(feedback).font(.caption).foregroundStyle(Theme.secondary) }
            Text("授权由 iPhone 系统确认；拒绝后可随时到系统设置修改。参考照片不写入相册，无需相册权限。")
                .font(.caption).foregroundStyle(Theme.secondary)
        }
        .disabled(requesting)
        .task { refresh() }
        .onChange(of: missions) { _, _ in refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
    }
    private func refresh() { statuses = Dictionary(uniqueKeysWithValues: rows.map { ($0, DevicePermissionCenter.shared.status($0)) }) }
    private func request(_ permission: TaskPermission) {
        requesting = true
        Task { @MainActor in
            await DevicePermissionCenter.shared.request(permission)
            requesting = false; feedback = nil; refresh()
        }
    }
}
