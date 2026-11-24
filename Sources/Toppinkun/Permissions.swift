import AppKit
import ApplicationServices
import ScreenCaptureKit

/// Toppinkun が使う TCC 権限。
/// - 画面収録（必須）: 固定ウィンドウを ScreenCaptureKit でミラーするため。
/// - アクセシビリティ（任意）: ミラーをクリックしたとき、本物のウィンドウを正確に前面化するため。
enum Permissions {
    static var hasScreenCapture: Bool { CGPreflightScreenCaptureAccess() }

    /// 未許可ならシステムの許可要求を出す（初回はダイアログ、以降はシステム設定で許可が必要）。
    ///
    /// 新しい macOS では `CGRequestScreenCaptureAccess` だけだとシステム設定の一覧に載らないことがあるため、
    /// ScreenCaptureKit の `SCShareableContent` も呼んで TCC へ確実に登録させる（結果は使わない）。
    @discardableResult
    static func requestScreenCapture() -> Bool {
        let granted = CGRequestScreenCaptureAccess()
        if !granted {
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { _, _ in }
        }
        return granted
    }

    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    @discardableResult
    static func requestAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openScreenCaptureSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private static func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}
