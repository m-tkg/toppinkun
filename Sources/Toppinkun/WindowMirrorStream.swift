import AppKit
import CoreMedia
import OSLog
import ScreenCaptureKit

private let log = Logger(subsystem: "com.mtkg.toppinkun", category: "mirror")

/// 1枚のウィンドウを ScreenCaptureKit でライブキャプチャし、フレームを main で通知する。
/// 他のウィンドウに覆われていてもウィンドウ単体の映像が取れる（`desktopIndependentWindow`）。
final class WindowMirrorStream: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    enum StreamError: LocalizedError {
        case windowNotFound
        var errorDescription: String? { "window not found in shareable content" }
    }

    private let windowID: CGWindowID
    private let onFrame: @MainActor (IOSurface) -> Void
    private let onStop: @MainActor (Error?) -> Void
    private let queue = DispatchQueue(label: "com.mtkg.toppinkun.mirror")
    private var stream: SCStream?

    init(windowID: CGWindowID,
         onFrame: @escaping @MainActor (IOSurface) -> Void,
         onStop: @escaping @MainActor (Error?) -> Void) {
        self.windowID = windowID
        self.onFrame = onFrame
        self.onStop = onStop
    }

    func start(pixelSize: CGSize) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            throw StreamError.windowNotFound
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let stream = SCStream(filter: filter, configuration: Self.configuration(pixelSize: pixelSize), delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
    }

    /// ウィンドウのサイズ変更に追従する。
    func update(pixelSize: CGSize) {
        stream?.updateConfiguration(Self.configuration(pixelSize: pixelSize)) { error in
            if let error { log.error("updateConfiguration failed: \(error.localizedDescription, privacy: .public)") }
        }
    }

    func stop() {
        let stream = self.stream
        self.stream = nil
        stream?.stopCapture { _ in }
    }

    private static func configuration(pixelSize: CGSize) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = max(1, Int(pixelSize.width))
        config.height = max(1, Int(pixelSize.height))
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.queueDepth = 3
        return config
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(
                sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let statusRaw = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: statusRaw) == .complete,
              let pixelBuffer = sampleBuffer.imageBuffer,
              let surfaceRef = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else {
            return
        }
        let surface = unsafeBitCast(surfaceRef, to: IOSurface.self)
        DispatchQueue.main.async { [onFrame] in
            MainActor.assumeIsolated { onFrame(surface) }
        }
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        log.error("stream stopped: \(error.localizedDescription, privacy: .public)")
        DispatchQueue.main.async { [onStop] in
            MainActor.assumeIsolated { onStop(error) }
        }
    }
}
