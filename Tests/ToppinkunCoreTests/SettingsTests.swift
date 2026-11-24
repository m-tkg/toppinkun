import XCTest
@testable import ToppinkunCore

/// `ToppinkunCore.Settings` の Codable 互換性テスト。
/// 設定の永続化そのもの（ファイル入出力）は kunkit の `KunSettingsStore` が担うため、
/// ここではアプリ固有の設定モデルが「欠損キーを既定値で補完する」前方/後方互換を検証する。
final class SettingsTests: XCTestCase {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    func testEncodeDecodeRoundTrip() throws {
        var settings = Settings.default
        settings.pin.hotKey = HotKeyConfig(keyCode: 0, carbonModifiers: HotKeyConfig.optionKey, keyLabel: "A")
        let data = try encoder.encode(settings)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }

    func testDecodesEmptyObjectAsDefault() throws {
        // 空 JSON（全キー欠損）でも既定値で埋まる。
        let data = Data("{}".utf8)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(decoded, .default)
    }

    func testDefaultPinHotKeyIsControlCommandT() {
        XCTAssertEqual(Settings.default.pin.hotKey, .defaultPin)
    }

    func testDecodesLegacyFileWithoutPinSection() throws {
        // テンプレート由来の古い設定（general のみ）でも固定設定は既定値で補完される。
        let data = Data(#"{"general":{}}"#.utf8)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(decoded.pin, PinSettings())
    }
}
