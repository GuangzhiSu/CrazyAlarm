import Foundation

enum TaskPermission: String, CaseIterable, Hashable, Sendable {
    case alarms, camera, microphone, speech, motion
    var title: String {
        switch self {
        case .alarms: "系统闹钟"
        case .camera: "相机"
        case .microphone: "麦克风"
        case .speech: "语音识别"
        case .motion: "运动与健身（计步）"
        }
    }
    static func required(for missions: [WakeMission], includeAlarms: Bool = true) -> [TaskPermission] {
        var needed: Set<TaskPermission> = includeAlarms ? [.alarms] : []
        for mission in missions {
            switch mission.kind {
            case .household, .barcode, .photo, .squat: needed.insert(.camera)
            case .speech: needed.formUnion([.microphone, .speech])
            case .steps: needed.insert(.motion)
            default: break // Raw device acceleration and cognitive missions have no extra consent dialog.
            }
        }
        return allCases.filter { needed.contains($0) }
    }
}

enum PermissionAccess: Equatable, Sendable {
    case authorized, notDetermined, denied, restricted, unavailable
    var title: String {
        switch self {
        case .authorized: "已允许"
        case .notDetermined: "尚未授权"
        case .denied: "未允许"
        case .restricted: "受系统限制"
        case .unavailable: "当前不可用"
        }
    }
}

struct PermissionProblem: LocalizedError {
    let permission: TaskPermission
    let access: PermissionAccess
    var needsSettings: Bool { access == .denied || access == .restricted }
    var errorDescription: String? {
        if needsSettings { return "\(permission.title)权限未开启，请打开系统设置允许 CrazyAlarm。原有闹钟未修改。" }
        if access == .unavailable { return "\(permission.title)在此设备或当前系统中不可用，暂时无法启用所选任务。" }
        return "尚未完成\(permission.title)授权，请在任务权限区域完成后重试。"
    }
}

@MainActor
enum PermissionPreflight {
    static func ensure(_ permissions: [TaskPermission], status: (TaskPermission) -> PermissionAccess,
                       request: (TaskPermission) async -> Void) async throws {
        for permission in TaskPermission.allCases where permissions.contains(permission) {
            if status(permission) == .notDetermined { await request(permission) }
            let access = status(permission)
            guard access == .authorized else { throw PermissionProblem(permission: permission, access: access) }
        }
    }
}
