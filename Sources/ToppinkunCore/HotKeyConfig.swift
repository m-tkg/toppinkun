import Foundation

/// グローバルホットキーの設定。
///
/// Carbon `RegisterEventHotKey` にそのまま渡せる値（仮想キーコードと Carbon 修飾フラグ）を保持する。
/// `keyLabel` は表示用ラベルで、登録時に NSEvent から取り込む（キーコードからの逆引き表は持たない）。
public struct HotKeyConfig: Codable, Equatable {
    /// 仮想キーコード（Carbon / kVK_*）。
    public var keyCode: UInt32
    /// Carbon の修飾フラグ（`cmdKey` などの OR）。
    public var carbonModifiers: UInt32
    /// 表示用のキーラベル（例: "T", "Space", "F5"）。
    public var keyLabel: String

    // Carbon 修飾フラグ（Events.h）。AppKit に依存しないようここで定義する。
    public static let cmdKey: UInt32 = 0x0100
    public static let shiftKey: UInt32 = 0x0200
    public static let optionKey: UInt32 = 0x0800
    public static let controlKey: UInt32 = 0x1000

    public init(keyCode: UInt32, carbonModifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.keyLabel = keyLabel
    }

    /// 前面ウィンドウの固定/解除の既定ホットキー: ⌃⌘T。
    public static let defaultPin = HotKeyConfig(
        keyCode: 17, // kVK_ANSI_T
        carbonModifiers: HotKeyConfig.controlKey | HotKeyConfig.cmdKey,
        keyLabel: "T"
    )

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = HotKeyConfig.defaultPin
        self.keyCode = try c.decodeIfPresent(UInt32.self, forKey: .keyCode) ?? d.keyCode
        self.carbonModifiers = try c.decodeIfPresent(UInt32.self, forKey: .carbonModifiers) ?? d.carbonModifiers
        self.keyLabel = try c.decodeIfPresent(String.self, forKey: .keyLabel) ?? d.keyLabel
    }

    private enum CodingKeys: String, CodingKey {
        case keyCode, carbonModifiers, keyLabel
    }

    /// 修飾キーの記号表現。表示順は Apple 慣習に従う（⌃ ⌥ ⇧ ⌘）。
    public var modifierSymbols: String {
        var s = ""
        if carbonModifiers & Self.controlKey != 0 { s += "⌃" }
        if carbonModifiers & Self.optionKey != 0 { s += "⌥" }
        if carbonModifiers & Self.shiftKey != 0 { s += "⇧" }
        if carbonModifiers & Self.cmdKey != 0 { s += "⌘" }
        return s
    }

    /// メニュー/設定に表示するホットキー文字列（例: "⌃⌘T"）。
    public var displayString: String {
        modifierSymbols + keyLabel
    }
}
