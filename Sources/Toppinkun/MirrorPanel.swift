import AppKit

/// 固定ウィンドウの映像を最前面に表示するパネル。
/// アクティブ化しない（他アプリのフォーカスを奪わない）枠なしパネルで、全 Space・フルスクリーン上にも出す。
@MainActor
final class MirrorPanel: NSPanel {
    private let mirrorView = MirrorView()

    /// ミラーがクリックされたとき（本物のウィンドウを前面化する）。
    var onClick: (() -> Void)? {
        get { mirrorView.onClick }
        set { mirrorView.onClick = newValue }
    }

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        contentView = mirrorView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// 最新フレーム（IOSurface）を表示する。
    func display(surface: IOSurface) {
        mirrorView.layer?.contents = surface
    }

    func clearContents() {
        mirrorView.layer?.contents = nil
    }
}

/// ミラー映像を描画し、クリックを受ける view。
private final class MirrorView: NSView {
    var onClick: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.contentsGravity = .resizeAspect
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
