import AVFoundation
import Foundation

@MainActor
final class MusicPlayer {
    private var player: AVAudioPlayer?
    private var interruptionObserver: NSObjectProtocol?
    private(set) var isRinging = false
    static var soundsDirectory: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Sounds", isDirectory: true)
    }

    init() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor [weak self] in
                guard type == AVAudioSession.InterruptionType.ended.rawValue,
                      let self, self.isRinging else { return }
                try? AVAudioSession.sharedInstance().setActive(true)
                self.player?.play()
            }
        }
    }

    func ring(_ sound: AlarmSound) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
        let url: URL
        if let file = sound.fileName {
            url = Self.soundsDirectory.appendingPathComponent(file)
        } else {
            guard let resource = Bundle.main.url(forResource: "MorningSpark", withExtension: "wav") else {
                throw AlarmValidationError.missingSound
            }
            url = resource
        }
        let next = try AVAudioPlayer(contentsOf: url)
        next.numberOfLoops = -1
        next.volume = 1
        guard next.prepareToPlay(), next.play() else { throw MusicError.cannotPlay }
        player = next
        isRinging = true
    }

    func stop() {
        isRinging = false
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Copy owned audio into the sandbox and create a short PCM CAF clip for AlarmKit.
    /// The full song is used during the quiz; system alerts use the first 28 seconds.
    static func importAudio(_ source: URL) throws -> AlarmSound {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let input = try AVAudioFile(forReading: source)
        guard input.length > 0 else { throw MusicError.cannotPlay }
        let directory = soundsDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let identifier = UUID().uuidString
        let fileName = identifier + "." + source.pathExtension.lowercased()
        let alertName = identifier + "-alert.caf"
        let fullURL = directory.appendingPathComponent(fileName)
        let alertURL = directory.appendingPathComponent(alertName)
        do {
            try FileManager.default.copyItem(at: source, to: fullURL)
            let output = try AVAudioFile(forWriting: alertURL, settings: input.processingFormat.settings)
            let frames = AVAudioFrameCount(min(input.length, AVAudioFramePosition(input.processingFormat.sampleRate * 28)))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: min(frames, 8192)) else {
                throw MusicError.cannotPlay
            }
            var remaining = frames
            while remaining > 0 {
                try input.read(into: buffer, frameCount: min(remaining, buffer.frameCapacity))
                guard buffer.frameLength > 0 else { break }
                try output.write(from: buffer)
                remaining -= buffer.frameLength
            }
            guard remaining < frames else { throw MusicError.cannotPlay }
            return AlarmSound(title: source.deletingPathExtension().lastPathComponent,
                              fileName: fileName, alertFileName: alertName)
        } catch {
            try? FileManager.default.removeItem(at: fullURL)
            try? FileManager.default.removeItem(at: alertURL)
            throw error
        }
    }
}

enum MusicError: LocalizedError {
    case cannotPlay
    var errorDescription: String? { "音乐无法播放，请导入未加密的 MP3、M4A、WAV 或 CAF 文件。" }
}
