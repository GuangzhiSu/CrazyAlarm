// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CrazyAlarmCore",
    platforms: [.macOS(.v13), .iOS(.v18)],
    products: [.library(name: "CrazyAlarmCore", targets: ["CrazyAlarmCore"])],
    targets: [
        .target(name: "CrazyAlarmCore", path: "CrazyAlarm", exclude: [
            "CrazyAlarmApp.swift", "AppStore.swift", "AlarmScheduler.swift", "MusicPlayer.swift",
            "Views.swift", "OpenQuizIntent.swift", "Info.plist", "Assets.xcassets", "Resources"
        ], sources: ["Models.swift"]),
        .testTarget(name: "CrazyAlarmCoreTests", dependencies: ["CrazyAlarmCore"], path: "Tests")
    ]
)
