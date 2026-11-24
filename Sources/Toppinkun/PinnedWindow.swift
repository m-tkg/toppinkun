import AppKit
import ToppinkunCore

/// 固定対象のウィンドウ。同一性は `CGWindowID` で判定する（タイトル等は表示用で変わりうる）。
struct PinnedWindow: PinnableWindow {
    let windowID: CGWindowID
    let ownerPID: Int32
    let appName: String
    let title: String

    static func == (lhs: PinnedWindow, rhs: PinnedWindow) -> Bool {
        lhs.windowID == rhs.windowID
    }

    /// メニュー表示用の名前（タイトルが空ならアプリ名のみ）。
    var displayName: String {
        title.isEmpty ? appName : "\(appName) — \(title)"
    }
}
