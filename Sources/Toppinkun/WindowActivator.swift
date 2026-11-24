import AppKit
import ApplicationServices

/// 固定ウィンドウを本物として前面化する（ミラークリック時）。
/// アプリをアクティブ化し、AX 権限があれば位置・サイズが一致するウィンドウを raise して確実に手前へ出す
/// （CGWindowID と AX 要素を対応付ける公開 API が無いため、フレーム一致で特定する）。
enum WindowActivator {
    static func activate(_ window: PinnedWindow) {
        if Permissions.hasAccessibility, let info = WindowLocator.info(for: window.windowID) {
            raise(pid: window.ownerPID, matching: info.bounds)
        }
        NSRunningApplication(processIdentifier: window.ownerPID)?.activate(options: [])
    }

    private static func raise(pid: Int32, matching bounds: CGRect) {
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return }
        guard let target = windows.first(where: { frame(of: $0).map { isClose($0, bounds) } ?? false }) else { return }
        AXUIElementSetAttributeValue(target, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(target, kAXRaiseAction as CFString)
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let posValue, let sizeValue,
              CFGetTypeID(posValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            return nil
        }
        var point = CGPoint.zero
        var size = CGSize.zero
        // swiftlint:disable:next force_cast
        AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
        // swiftlint:disable:next force_cast
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    private static func isClose(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 2 && abs(a.minY - b.minY) < 2
            && abs(a.width - b.width) < 2 && abs(a.height - b.height) < 2
    }
}
