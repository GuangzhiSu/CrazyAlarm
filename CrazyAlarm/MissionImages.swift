import Foundation
import UIKit
import Vision

enum MissionImages {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CrazyAlarm/References", isDirectory: true)
    }
    static func save(_ image: UIImage) throws -> String {
        let name = UUID().uuidString + ".jpg"
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = normalized(image).jpegData(compressionQuality: 0.88) else { throw MissionImageError.unreadable }
        try data.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return name
    }
    static func load(_ name: String?) -> UIImage? {
        guard let name, name == (name as NSString).lastPathComponent else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(name).path)
    }
    static func normalized(_ image: UIImage) -> UIImage {
        let scale = min(1, 1024 / max(image.size.width, image.size.height))
        let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
    static func match(_ image: UIImage, reference: String, difficulty: Int) throws -> (Bool, String) {
        guard let saved = load(reference) else { throw MissionError.missingReference }
        func feature(_ image: UIImage) throws -> VNFeaturePrintObservation {
            guard let cg = normalized(image).cgImage else { throw MissionImageError.unreadable }
            let request = VNGenerateImageFeaturePrintRequest()
            request.revision = VNGenerateImageFeaturePrintRequestRevision2
            request.imageCropAndScaleOption = .centerCrop
            try VNImageRequestHandler(cgImage: cg).perform([request])
            guard let result = request.results?.first else { throw MissionImageError.unreadable }
            return result
        }
        let referencePrint = try feature(saved), actual = try feature(image)
        var distance: Float = 0
        try referencePrint.computeDistance(&distance, to: actual)
        let threshold: Float = difficulty == 1 ? 0.7 : difficulty == 2 ? 0.5 : 0.35
        let passed = distance.isFinite && distance <= threshold
        return (passed, passed ? "照片匹配成功" : "还没匹配上，请靠近参考物体，调整角度和光线后重拍。")
    }
    static func find(_ item: HouseholdItem, in image: UIImage) throws -> (Bool, String) {
        guard let cg = normalized(image).cgImage else { throw MissionImageError.unreadable }
        let request = VNClassifyImageRequest()
        try VNImageRequestHandler(cgImage: cg).perform([request])
        let match = (request.results ?? []).filter { item.matches($0.identifier) }.max { $0.confidence < $1.confidence }
        guard let match, match.confidence >= 0.35 else {
            return (false, "还未清楚识别到\(item.title)，请让物品占据画面中心并保持光线充足。")
        }
        return (true, "识别到\(item.title)（置信度 \(Int(match.confidence * 100))%）")
    }
}

enum MissionImageError: LocalizedError {
    case unreadable
    var errorDescription: String? { "无法分析这张照片，请重新拍摄。" }
}
