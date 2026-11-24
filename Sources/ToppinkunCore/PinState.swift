import Foundation

/// 固定対象になりうるウィンドウ。AX 要素などのプラットフォーム依存の表現をアプリ側で包んで渡す。
/// 同一性（`==`）は「同じウィンドウか」、`ownerPID` は「どのアプリのウィンドウか」の判定に使う。
public protocol PinnableWindow: Equatable {
    var ownerPID: Int32 { get }
}

/// 状態機械への入力。
public enum PinEvent<Window: PinnableWindow>: Equatable {
    /// ホットキー押下。`focused` は押下時の前面アプリのフォーカスウィンドウ（取れなければ nil）。
    case toggleRequested(focused: Window?)
    /// メニュー等からの明示的な解除。
    case unpinRequested
    /// 前面アプリ、または前面アプリ内のフォーカスウィンドウが変わった。
    case focusChanged(focused: Window?)
    /// ウィンドウが閉じられた。
    case windowClosed(Window)
    /// アプリが終了した。
    case appTerminated(pid: Int32)
}

/// 状態機械の出力（アプリ側が実行する副作用）。
public enum PinAction<Window: PinnableWindow>: Equatable {
    case pinned(Window)
    case unpinned(Window)
    /// 固定ウィンドウを最前面へ上げ直す。
    case raise(Window)
    /// ホットキーが押されたが固定できるウィンドウが無かった。
    case noFocusedWindow
}

/// 「最前面に固定するウィンドウ」を1枚だけ管理する純粋な状態機械。
///
/// macOS には他アプリのウィンドウレベルを変える公開 API が無いため、Toppinkun は
/// 「固定ウィンドウが覆われうる契機（前面の変化）ごとに上げ直す」方式で最前面を擬似的に保つ。
/// どの契機で上げ直すか・いつ固定を外すかの判定をここに集約する。
public struct PinState<Window: PinnableWindow> {
    public private(set) var pinned: Window?

    public init() {}

    public mutating func handle(_ event: PinEvent<Window>) -> [PinAction<Window>] {
        switch event {
        case .toggleRequested(let focused):
            guard let focused else { return [.noFocusedWindow] }
            if let current = pinned {
                pinned = nil
                if current == focused { return [.unpinned(current)] }
                pinned = focused
                return [.unpinned(current), .pinned(focused)]
            }
            pinned = focused
            return [.pinned(focused)]

        case .unpinRequested:
            return unpin()

        case .focusChanged(let focused):
            guard let current = pinned else { return [] }
            // 固定中アプリ自身が前面なら上げ直さない（フォーカスを奪わず、アプリ内の切替を妨げない）。
            if let focused, focused.ownerPID == current.ownerPID { return [] }
            return [.raise(current)]

        case .windowClosed(let window):
            guard pinned == window else { return [] }
            return unpin()

        case .appTerminated(let pid):
            guard pinned?.ownerPID == pid else { return [] }
            return unpin()
        }
    }

    private mutating func unpin() -> [PinAction<Window>] {
        guard let current = pinned else { return [] }
        pinned = nil
        return [.unpinned(current)]
    }
}
