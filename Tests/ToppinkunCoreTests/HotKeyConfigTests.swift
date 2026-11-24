import XCTest
@testable import ToppinkunCore

final class HotKeyConfigTests: XCTestCase {
    func testDefaultPinIsControlCommandT() {
        let c = HotKeyConfig.defaultPin
        XCTAssertEqual(c.keyCode, 17) // kVK_ANSI_T
        XCTAssertEqual(c.carbonModifiers, HotKeyConfig.controlKey | HotKeyConfig.cmdKey)
        XCTAssertEqual(c.displayString, "⌃⌘T")
    }

    func testModifierSymbolsUseAppleOrder() {
        let all = HotKeyConfig(
            keyCode: 0,
            carbonModifiers: HotKeyConfig.controlKey | HotKeyConfig.optionKey
                | HotKeyConfig.shiftKey | HotKeyConfig.cmdKey,
            keyLabel: "A"
        )
        XCTAssertEqual(all.modifierSymbols, "⌃⌥⇧⌘")
        XCTAssertEqual(all.displayString, "⌃⌥⇧⌘A")
    }

    func testNoModifiersYieldsEmptySymbols() {
        let c = HotKeyConfig(keyCode: 0, carbonModifiers: 0, keyLabel: "F5")
        XCTAssertEqual(c.displayString, "F5")
    }

    func testRoundTrips() throws {
        let c = HotKeyConfig(keyCode: 35, carbonModifiers: HotKeyConfig.cmdKey, keyLabel: "P")
        let data = try JSONEncoder().encode(c)
        XCTAssertEqual(try JSONDecoder().decode(HotKeyConfig.self, from: data), c)
    }

    func testDecodesEmptyObjectAsDefaultPin() throws {
        let decoded = try JSONDecoder().decode(HotKeyConfig.self, from: Data("{}".utf8))
        XCTAssertEqual(decoded, .defaultPin)
    }
}
