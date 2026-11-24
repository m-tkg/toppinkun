import AppKit

/// 固定中のウィンドウを示す色付きの枠。ウィンドウの外側に沿って描き、中身や信号機ボタンには重ねない。
/// クリックは素通しし、ミラーより上のレベルに置く（ミラー表示中も本物を操作中も見える）。
@MainActor
final class PinBorderPanel: NSPanel {
    static let lineWidth: CGFloat = 4

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        contentView = BorderView()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// 対象ウィンドウのフレーム（AppKit 座標）を囲む位置へ移動する。
    func surround(_ windowFrame: NSRect) {
        setFrame(windowFrame.insetBy(dx: -Self.lineWidth, dy: -Self.lineWidth), display: true)
    }
}

private final class BorderView: NSView {
    /// macOS 標準ウィンドウの角丸半径の目安（ウィンドウ外側に沿わせるため線幅ぶん足す）。
    private let windowCornerRadius: CGFloat = 12

    override func draw(_ dirtyRect: NSRect) {
        let width = PinBorderPanel.lineWidth
        let rect = bounds.insetBy(dx: width / 2, dy: width / 2)
        let radius = windowCornerRadius + width / 2
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        path.lineWidth = width
        NSColor.systemOrange.setStroke()
        path.stroke()
    }
}
