import AppKit
import OSLog
import ToppinkunCore

private let log = Logger(subsystem: "com.mtkg.toppinkun", category: "pin")

/// ウィンドウ固定の実行部。判定は `PinState`（Core）に任せ、ここでは OS イベントの入力と
/// 副作用（ミラーの開始/停止・表示/非表示・追従）だけを担う。
@MainActor
final class PinController {
    private var state = PinState<PinnedWindow>()
    private let panel = MirrorPanel()
    /// 固定中のウィンドウを示す枠。
    private let border = PinBorderPanel()
    private var stream: WindowMirrorStream?
    /// ミラーを表示したい状態か（キャプチャ開始直後で映像がまだ無い間は、最初のフレーム到着で表示する）。
    private var wantsVisible = false
    private var hasFrame = false
    private var trackTimer: Timer?
    private var lastBounds: CGRect = .zero
    private var observers: [NSObjectProtocol] = []

    /// 固定状態が変わったとき（メニュー更新用）。
    var onChange: (() -> Void)?

    var pinned: PinnedWindow? { state.pinned }

    init() {
        panel.onClick = { [weak self] in
            guard let window = self?.state.pinned else { return }
            WindowActivator.activate(window)
        }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let pid = app?.processIdentifier
            MainActor.assumeIsolated { self?.send(.frontmostAppChanged(pid: pid)) }
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            MainActor.assumeIsolated { self?.send(.appTerminated(pid: pid)) }
        })
    }

    /// ホットキー/メニュー: 前面アプリの最前面ウィンドウを固定（同じなら解除、別なら付け替え）。
    func toggle() {
        guard Permissions.hasScreenCapture else {
            Permissions.requestScreenCapture()
            return
        }
        send(.toggleRequested(focused: frontmostWindow()))
    }

    func unpin() {
        send(.unpinRequested)
    }

    private func frontmostWindow() -> PinnedWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let info = WindowLocator.frontWindow(ofPID: app.processIdentifier) else {
            return nil
        }
        return PinnedWindow(
            windowID: info.windowID,
            ownerPID: info.ownerPID,
            appName: app.localizedName ?? info.ownerName,
            title: info.title
        )
    }

    private func send(_ event: PinEvent<PinnedWindow>) {
        let actions = state.handle(event)
        for action in actions {
            switch action {
            case .pinned(let window):
                startMirror(window)
            case .unpinned:
                stopMirror()
            case .showMirror(let window):
                showMirror(window)
            case .hideMirror:
                hideMirror()
            case .noFocusedWindow:
                NSSound.beep()
            }
        }
        if actions.contains(where: Self.changesPinnedState) { onChange?() }
    }

    private static func changesPinnedState(_ action: PinAction<PinnedWindow>) -> Bool {
        switch action {
        case .pinned, .unpinned: return true
        default: return false
        }
    }

    // MARK: - ミラー

    /// 固定開始。対象アプリが前面なのでミラーは隠したまま、キャプチャもまだ始めない
    /// （他アプリが前面になった時点で開始する）。
    private func startMirror(_ window: PinnedWindow) {
        guard let info = WindowLocator.info(for: window.windowID) else { return }
        lastBounds = info.bounds
        hasFrame = false
        wantsVisible = false
        panel.clearContents()
        panel.setFrame(WindowLocator.appKitFrame(fromCG: info.bounds), display: false)
        panel.orderOut(nil)
        border.surround(WindowLocator.appKitFrame(fromCG: info.bounds))
        updateBorderVisibility(isWindowOnScreen: info.isOnScreen)

        trackTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.track() }
        }
    }

    private func stopMirror() {
        trackTimer?.invalidate()
        trackTimer = nil
        stopCapture()
        wantsVisible = false
        hasFrame = false
        panel.orderOut(nil)
        panel.clearContents()
        border.orderOut(nil)
    }

    /// 他アプリが前面になった: キャプチャを始め、映像があればすぐ表示する。
    /// 直前の映像（キャプチャ停止時の最終フレーム）が残っていれば即表示し、最新フレームで置き換わる。
    private func showMirror(_ window: PinnedWindow) {
        wantsVisible = true
        refreshFrame()
        if hasFrame { panel.orderFrontRegardless() }
        border.orderFrontRegardless()
        startCapture(window)
    }

    /// 固定中アプリが前面になった: ミラーを隠し、キャプチャも止める。
    /// キャプチャ中は macOS が対象ウィンドウのタイトルバーに「共有中」バッジを重ね、信号機ボタンを塞ぐため。
    private func hideMirror() {
        wantsVisible = false
        panel.orderOut(nil)
        stopCapture()
    }

    private func startCapture(_ window: PinnedWindow) {
        guard stream == nil, let info = WindowLocator.info(for: window.windowID) else { return }
        let stream = WindowMirrorStream(
            windowID: window.windowID,
            onFrame: { [weak self] surface in self?.receive(surface) },
            onStop: { [weak self] _ in self?.unpin() }
        )
        self.stream = stream
        let pixelSize = pixelSize(for: info.bounds)
        Task { @MainActor [weak self] in
            do {
                try await stream.start(pixelSize: pixelSize)
                // 開始待ちの間に隠された/付け替えられた場合は、遅れて始まったキャプチャを止める。
                if self?.stream !== stream { stream.stop() }
            } catch {
                log.error("mirror start failed: \(error.localizedDescription, privacy: .public)")
                if self?.stream === stream { self?.unpin() }
            }
        }
    }

    private func stopCapture() {
        stream?.stop()
        stream = nil
    }

    private func receive(_ surface: IOSurface) {
        guard stream != nil else { return }
        panel.display(surface: surface)
        hasFrame = true
        if wantsVisible && !panel.isVisible {
            panel.orderFrontRegardless()
            border.orderFrontRegardless() // 枠をミラーより手前に保つ
        }
    }

    /// 固定ウィンドウの消滅・移動・リサイズに追従する。
    private func track() {
        guard let window = state.pinned else { return }
        guard let info = WindowLocator.info(for: window.windowID) else {
            send(.windowClosed(window))
            return
        }
        refreshFrame()
        updateBorderVisibility(isWindowOnScreen: info.isOnScreen)
    }

    private func refreshFrame() {
        guard let window = state.pinned, let info = WindowLocator.info(for: window.windowID) else { return }
        guard info.bounds != lastBounds else { return }
        let sizeChanged = info.bounds.size != lastBounds.size
        lastBounds = info.bounds
        panel.setFrame(WindowLocator.appKitFrame(fromCG: info.bounds), display: true)
        border.surround(WindowLocator.appKitFrame(fromCG: info.bounds))
        if sizeChanged { stream?.update(pixelSize: pixelSize(for: info.bounds)) }
    }

    /// 枠は「ミラー表示中」または「本物のウィンドウが画面上にある」間だけ出す
    /// （最小化中・別 Space で本物が見えないときに、何も無い場所を囲まないように）。
    private func updateBorderVisibility(isWindowOnScreen: Bool) {
        let visible = state.pinned != nil && (wantsVisible || isWindowOnScreen)
        if visible && !border.isVisible {
            border.orderFrontRegardless()
        } else if !visible && border.isVisible {
            border.orderOut(nil)
        }
    }

    private func pixelSize(for bounds: CGRect) -> CGSize {
        let appKitFrame = WindowLocator.appKitFrame(fromCG: bounds)
        let scale = NSScreen.screens.first(where: { $0.frame.intersects(appKitFrame) })?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor ?? 2
        return CGSize(width: bounds.width * scale, height: bounds.height * scale)
    }
}
