import AppKit

/// `CGWindowList` からウィンドウ情報を引くヘルパー（AX 権限は不要）。
/// 座標は CoreGraphics のグローバル座標（原点はメイン画面の左上、y は下向き）。
enum WindowLocator {
    struct Info {
        let windowID: CGWindowID
        let ownerPID: Int32
        let ownerName: String
        let title: String
        let bounds: CGRect
        /// 画面上に表示されているか（最小化中・別 Space なら false）。
        let isOnScreen: Bool
    }

    /// 指定アプリの最前面の通常ウィンドウ（layer 0）。メニューやツールチップ等の小片は除く。
    static func frontWindow(ofPID pid: Int32) -> Info? {
        let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.lazy
            .compactMap(info(from:))
            .first { $0.ownerPID == pid && $0.bounds.width >= 40 && $0.bounds.height >= 40 }
    }

    /// 指定ウィンドウの現在の情報。ウィンドウが閉じられていれば nil。
    static func info(for windowID: CGWindowID) -> Info? {
        let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]] ?? []
        return list.lazy.compactMap(info(from:)).first { $0.windowID == windowID }
    }

    private static func info(from dict: [String: Any]) -> Info? {
        guard (dict[kCGWindowLayer as String] as? Int) == 0,
              let number = dict[kCGWindowNumber as String] as? Int,
              let pid = dict[kCGWindowOwnerPID as String] as? Int,
              let boundsDict = dict[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDict) else {
            return nil
        }
        return Info(
            windowID: CGWindowID(number),
            ownerPID: Int32(pid),
            ownerName: dict[kCGWindowOwnerName as String] as? String ?? "",
            title: dict[kCGWindowName as String] as? String ?? "",
            bounds: bounds,
            isOnScreen: dict[kCGWindowIsOnscreen as String] as? Bool ?? false
        )
    }

    /// CoreGraphics 座標（左上原点）を AppKit のスクリーン座標（左下原点）へ変換する。
    static func appKitFrame(fromCG rect: CGRect) -> NSRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
