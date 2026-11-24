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
    private var stream: WindowMirrorStream?
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
            case .showMirror:
                refreshFrame()
                panel.orderFrontRegardless()
            case .hideMirror:
                panel.orderOut(nil)
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

    private func startMirror(_ window: PinnedWindow) {
        guard let info = WindowLocator.info(for: window.windowID) else { return }
        lastBounds = info.bounds
        panel.clearContents()
        panel.setFrame(WindowLocator.appKitFrame(fromCG: info.bounds), display: false)
        // 固定直後は対象アプリが前面なのでパネルは隠したまま（他アプリが前面になったら出す）。
        panel.orderOut(nil)

        let stream = WindowMirrorStream(
            windowID: window.windowID,
            onFrame: { [weak self] surface in self?.panel.display(surface: surface) },
            onStop: { [weak self] _ in self?.unpin() }
        )
        self.stream = stream
        let pixelSize = pixelSize(for: info.bounds)
        Task { @MainActor [weak self] in
            do {
                try await stream.start(pixelSize: pixelSize)
            } catch {
                log.error("mirror start failed: \(error.localizedDescription, privacy: .public)")
                if self?.stream === stream { self?.unpin() }
            }
        }

        trackTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.track() }
        }
    }

    private func stopMirror() {
        trackTimer?.invalidate()
        trackTimer = nil
        stream?.stop()
        stream = nil
        panel.orderOut(nil)
        panel.clearContents()
    }

    /// 固定ウィンドウの消滅・移動・リサイズに追従する。
    private func track() {
        guard let window = state.pinned else { return }
        guard WindowLocator.info(for: window.windowID) != nil else {
            send(.windowClosed(window))
            return
        }
        refreshFrame()
    }

    private func refreshFrame() {
        guard let window = state.pinned, let info = WindowLocator.info(for: window.windowID) else { return }
        guard info.bounds != lastBounds else { return }
        let sizeChanged = info.bounds.size != lastBounds.size
        lastBounds = info.bounds
        panel.setFrame(WindowLocator.appKitFrame(fromCG: info.bounds), display: true)
        if sizeChanged { stream?.update(pixelSize: pixelSize(for: info.bounds)) }
    }

    private func pixelSize(for bounds: CGRect) -> CGSize {
        let appKitFrame = WindowLocator.appKitFrame(fromCG: bounds)
        let scale = NSScreen.screens.first(where: { $0.frame.intersects(appKitFrame) })?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor ?? 2
        return CGSize(width: bounds.width * scale, height: bounds.height * scale)
    }
}
