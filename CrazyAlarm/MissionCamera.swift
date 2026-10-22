import AVFoundation
import SwiftUI
import UIKit
import Vision

struct TakeMissionPhoto: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera; picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: TakeMissionPhoto
        init(_ parent: TakeMissionPhoto) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

enum MissionCameraMode: Sendable { case barcode, squat }

struct LiveMissionCamera: UIViewControllerRepresentable {
    let mode: MissionCameraMode
    var onSample: @MainActor (String?, Double?) -> Void
    var onError: @MainActor (String) -> Void
    func makeUIViewController(context: Context) -> CameraMissionController {
        CameraMissionController(mode: mode, onSample: onSample, onError: onError)
    }
    func updateUIViewController(_ controller: CameraMissionController, context: Context) {}
    static func dismantleUIViewController(_ controller: CameraMissionController, coordinator: ()) { controller.owner.stop() }
}

final class CameraMissionController: UIViewController {
    let owner: CameraSessionOwner
    private var preview: AVCaptureVideoPreviewLayer?
    init(mode: MissionCameraMode, onSample: @escaping @MainActor (String?, Double?) -> Void,
         onError: @escaping @MainActor (String) -> Void) {
        owner = CameraSessionOwner(mode: mode, onSample: onSample, onError: onError)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let layer = AVCaptureVideoPreviewLayer(session: owner.session)
        layer.videoGravity = .resizeAspectFill; view.layer.addSublayer(layer); preview = layer
        owner.start()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews(); preview?.frame = view.bounds
        if let connection = preview?.connection, connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
    }
}

/// All session mutations run on one queue; image inference has its own serial queue.
final class CameraSessionOwner: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "CrazyAlarm.camera.session")
    private let frames = DispatchQueue(label: "CrazyAlarm.camera.frames", qos: .userInitiated)
    private let processor: CameraFrameProcessor
    private let mode: MissionCameraMode
    private let onError: @MainActor (String) -> Void
    private var stopped = false
    init(mode: MissionCameraMode, onSample: @escaping @MainActor (String?, Double?) -> Void,
         onError: @escaping @MainActor (String) -> Void) {
        self.mode = mode; self.onError = onError
        processor = CameraFrameProcessor(mode: mode, onSample: onSample)
    }
    func start() {
        queue.async { [self] in
            guard !stopped else { return }
            guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
                fail("相机权限未开启，请在系统设置中允许 CrazyAlarm。"); return
            }
            session.beginConfiguration(); session.sessionPreset = .high
            let position: AVCaptureDevice.Position = mode == .squat ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
                session.commitConfiguration(); fail("相机暂时无法打开，请结束通话或其他相机使用后重试。"); return
            }
            session.addInput(input)
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            guard session.canAddOutput(output) else { session.commitConfiguration(); fail("相机画面暂不可用。"); return }
            session.addOutput(output); output.setSampleBufferDelegate(processor, queue: frames)
            if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            session.commitConfiguration(); session.startRunning()
        }
    }
    func stop() {
        queue.async { [self] in stopped = true; if session.isRunning { session.stopRunning() } }
    }
    private func fail(_ message: String) { Task { @MainActor [onError] in onError(message) } }
}

final class CameraFrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let mode: MissionCameraMode
    let onSample: @MainActor (String?, Double?) -> Void
    private var lastFrame = -Double.infinity
    private var lastBarcode = ""
    private var lastScan = -Double.infinity
    init(mode: MissionCameraMode, onSample: @escaping @MainActor (String?, Double?) -> Void) {
        self.mode = mode; self.onSample = onSample
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let time = ProcessInfo.processInfo.systemUptime
        guard time - lastFrame >= 0.1, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrame = time
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
        do {
            if mode == .barcode {
                let request = VNDetectBarcodesRequest()
                try handler.perform([request])
                if let code = request.results?.first?.payloadStringValue, !code.isEmpty,
                   code != lastBarcode || time - lastScan > 2 {
                    lastBarcode = code; lastScan = time
                    Task { @MainActor [onSample] in onSample(code, nil) }
                }
            } else {
                let request = VNDetectHumanBodyPoseRequest()
                try handler.perform([request])
                let aspect = Double(CVPixelBufferGetHeight(buffer)) / Double(CVPixelBufferGetWidth(buffer))
                let angle = request.results?.first.flatMap { Self.kneeAngle($0, aspect: aspect) }
                Task { @MainActor [onSample] in onSample(nil, angle) }
            }
        } catch {
            if mode == .squat { Task { @MainActor [onSample] in onSample(nil, nil) } }
        }
    }
    private static func kneeAngle(_ body: VNHumanBodyPoseObservation, aspect: Double) -> Double? {
        guard let points = try? body.recognizedPoints(.all) else { return nil }
        func angle(_ hip: VNHumanBodyPoseObservation.JointName, _ knee: VNHumanBodyPoseObservation.JointName,
                   _ ankle: VNHumanBodyPoseObservation.JointName) -> Double? {
            guard let h = points[hip], let k = points[knee], let a = points[ankle],
                  min(h.confidence, k.confidence, a.confidence) > 0.45 else { return nil }
            // Convert normalized x/y to portrait pixel aspect before measuring the angle.
            let ux = Double(h.x - k.x), uy = Double(h.y - k.y) * aspect
            let vx = Double(a.x - k.x), vy = Double(a.y - k.y) * aspect
            let length = sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
            guard length > 0.00001 else { return nil }
            return acos(max(-1, min(1, (ux * vx + uy * vy) / length))) * 180 / .pi
        }
        return [angle(.leftHip, .leftKnee, .leftAnkle), angle(.rightHip, .rightKnee, .rightAnkle)]
            .compactMap { $0 }.min()
    }
}
