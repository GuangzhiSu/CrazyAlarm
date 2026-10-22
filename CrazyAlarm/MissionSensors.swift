import AVFoundation
import CoreMotion
import Foundation
import Observation
import Speech

@MainActor @Observable
final class MotionMissionController {
    var message = "准备开始"
    var isRunning = false
    private let pedometer = CMPedometer()
    private let motion = CMMotionManager()
    private var generation = UUID()
    private var previousSteps = 0
    private var shakes = ShakeCounter()

    func start(_ mission: WakeMission, onUnits: @escaping (Int) -> Void) {
        stop()
        let token = UUID(); generation = token
        if mission.kind == .steps {
            guard CMPedometer.isStepCountingAvailable() else { message = "此设备不支持计步。"; return }
            guard ![CMAuthorizationStatus.denied, .restricted].contains(CMPedometer.authorizationStatus()) else {
                message = "请到设置 → 隐私与安全性 → 运动与健身允许 CrazyAlarm。"; return
            }
            previousSteps = 0; isRunning = true; message = "拿着手机走动，步数可能延迟几秒更新。"
            pedometer.startUpdates(from: Date()) { [weak self] data, error in
                let count = data?.numberOfSteps.intValue
                let failed = error?.localizedDescription
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    if let failed { self.message = failed; self.isRunning = false; self.pedometer.stopUpdates(); return }
                    guard let count else { return }
                    let delta = max(0, count - self.previousSteps)
                    self.previousSteps = count
                    if delta > 0 { onUnits(delta) }
                }
            }
        } else if mission.kind == .shake {
            guard motion.isDeviceMotionAvailable else { message = "此设备的运动传感器不可用。"; return }
            shakes = ShakeCounter(); isRunning = true; message = "握稳手机，适度来回摇动。每次摇动后让手机回稳。"
            motion.deviceMotionUpdateInterval = 0.04
            motion.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
                let acceleration = data?.userAcceleration
                let magnitude = acceleration.map { sqrt($0.x * $0.x + $0.y * $0.y + $0.z * $0.z) }
                let failed = error?.localizedDescription
                let time = ProcessInfo.processInfo.systemUptime
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    if let failed { self.message = failed; self.isRunning = false; self.motion.stopDeviceMotionUpdates(); return }
                    if let magnitude, self.shakes.sample(magnitude: magnitude, time: time) { onUnits(1) }
                }
            }
        }
    }

    func stop() {
        generation = UUID(); isRunning = false
        pedometer.stopUpdates(); motion.stopDeviceMotionUpdates()
    }
}

@MainActor @Observable
final class SpeechMissionController {
    var isRunning = false
    var message = "先听 / 看三拍准备，再跟着亮起的节拍说词语。"
    var transcript = ""
    var startedAt = Date()
    private var engine: AVAudioEngine?
    private var task: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var generation = UUID()
    private var gate = VoiceBeatGate()
    private var beatTimer: Timer?
    private var cleanup: (() -> Void)?

    func start(_ mission: WakeMission, prepareAudio: () throws -> Void,
               restoreAudio: @escaping () -> Void, onWord: @escaping () -> Void,
               onBeat: @escaping () -> Void) async {
        stop()
        let token = UUID(); generation = token
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        let micAllowed = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard generation == token else { return }
        guard speechAllowed && micAllowed else {
            message = "请在设置中允许麦克风和语音识别，然后点开始重试。"; return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: mission.speechLocale)),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            message = "此语言的本机语音识别暂不可用。请在系统中准备该语言的语音资源，或在任务设置中换一种语言。"; return
        }
        do {
            try prepareAudio(); cleanup = restoreAudio
            let audio = AVAudioEngine()
            try audio.inputNode.setVoiceProcessingEnabled(true)
            let recognition = SFSpeechAudioBufferRecognitionRequest()
            recognition.requiresOnDeviceRecognition = true
            recognition.shouldReportPartialResults = true
            recognition.contextualStrings = [mission.text]
            let format = audio.inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw SpeechMissionError.inputUnavailable }
            audio.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                recognition.append(buffer)
            }
            engine = audio; request = recognition; gate = VoiceBeatGate(); transcript = ""
            task = recognizer.recognitionTask(with: recognition) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                        let segments = result.bestTranscription.segments
                        // Chinese phrases may span several segments; use the first segment's audio timestamp.
                        for end in segments.indices {
                            for start in max(0, end - 11)...end {
                                let word = segments[start...end].map(\.substring).joined(separator: " ")
                                if self.gate.accept(word: word, expected: mission.text,
                                                    timestamp: segments[start].timestamp, bpm: mission.beatsPerMinute) {
                                    self.message = "对上节拍了！"; onWord()
                                }
                            }
                        }
                    }
                    if error != nil || result?.isFinal == true {
                        self.stop()
                        self.message = error?.localizedDescription ?? "本轮识别结束，点开始继续；已完成次数保留。"
                    }
                }
            }
            audio.prepare(); startedAt = Date(); try audio.start()
            isRunning = true; message = "准备三拍，然后在节拍亮起时说词语。"
            beatTimer = Timer.scheduledTimer(withTimeInterval: 60 / Double(mission.beatsPerMinute), repeats: true) { _ in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == token, self.isRunning else { return }
                    onBeat()
                }
            }
        } catch {
            stop(); message = "语音启动失败：\(error.localizedDescription)"
        }
    }

    func stop() {
        generation = UUID(); isRunning = false
        beatTimer?.invalidate(); beatTimer = nil
        engine?.stop(); engine?.inputNode.removeTap(onBus: 0)
        engine = nil; request?.endAudio(); task?.cancel(); task = nil; request = nil
        cleanup?(); cleanup = nil
    }
}

private enum SpeechMissionError: LocalizedError {
    case inputUnavailable
    var errorDescription: String? { "麦克风输入不可用，请结束通话或其他录音后重试。" }
}
