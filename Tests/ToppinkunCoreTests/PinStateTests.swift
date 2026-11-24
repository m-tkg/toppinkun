import XCTest
@testable import ToppinkunCore

/// テスト用のウィンドウ表現（pid ＋ 識別子）。
private struct FakeWindow: PinnableWindow {
    let ownerPID: Int32
    let id: Int
}

final class PinStateTests: XCTestCase {
    private let a1 = FakeWindow(ownerPID: 100, id: 1)
    private let a2 = FakeWindow(ownerPID: 100, id: 2)
    private let b1 = FakeWindow(ownerPID: 200, id: 1)
    private let c1 = FakeWindow(ownerPID: 300, id: 1)

    // MARK: - ホットキー（固定のトグル）

    func testInitiallyNothingIsPinned() {
        let state = PinState<FakeWindow>()
        XCTAssertNil(state.pinned)
    }

    func testHotKeyPinsFocusedWindow() {
        var state = PinState<FakeWindow>()
        let actions = state.handle(.toggleRequested(focused: a1))
        XCTAssertEqual(state.pinned, a1)
        XCTAssertEqual(actions, [.pinned(a1)])
    }

    func testHotKeyOnPinnedWindowUnpinsIt() {
        var state = PinState<FakeWindow>()
        _ = state.handle(.toggleRequested(focused: a1))
        let actions = state.handle(.toggleRequested(focused: a1))
        XCTAssertNil(state.pinned)
        XCTAssertEqual(actions, [.unpinned(a1)])
    }

    func testHotKeyOnAnotherWindowReplacesPin() {
        // 同時に固定できるのは1枚だけ。新しく固定すると前の固定は外れる。
        var state = PinState<FakeWindow>()
        _ = state.handle(.toggleRequested(focused: a1))
        let actions = state.handle(.toggleRequested(focused: b1))
        XCTAssertEqual(state.pinned, b1)
        XCTAssertEqual(actions, [.unpinned(a1), .pinned(b1)])
    }

    func testHotKeyOnAnotherWindowOfSameAppReplacesPin() {
        var state = PinState<FakeWindow>()
        _ = state.handle(.toggleRequested(focused: a1))
        let actions = state.handle(.toggleRequested(focused: a2))
        XCTAssertEqual(state.pinned, a2)
        XCTAssertEqual(actions, [.unpinned(a1), .pinned(a2)])
    }

    func testHotKeyWithoutFocusedWindowDoesNothing() {
        var state = PinState<FakeWindow>()
        _ = state.handle(.toggleRequested(focused: a1))
        let actions = state.handle(.toggleRequested(focused: nil))
        XCTAssertEqual(state.pinned, a1)
        XCTAssertEqual(actions, [.noFocusedWindow])
    }

    // MARK: - 明示的な解除

    func testUnpinRequestedUnpins() {
        var state = PinState<FakeWindow>()
        _ = state.handle(.toggleRequested(focused: a1))
        XCTAssertEqual(state.handle(.unpinRequested), [.unpinned(a1)])
        XCTAssertNil(state.pinned)
    }

    func testUnpinRequestedWhenNothingPinnedDoesNothing() {
        var state = PinState<FakeWindow>()
        XCTAssertEqual(state.handle(.unpinRequested), [])
    }

    // MARK: - 前面の変化（再前面化）

    func testFocusMovingToOtherAppRaisesPinnedWindow() {
        var state = PinState<FakeWindow>()
        _ = state.handle(.toggleRequested(focused: a1))
        XCTAssertEqual(state.handle(.focusChanged(focused: b1)), [.raise(a1)])
        XCTAssertEqual(state.pinned, a1)
    }

    func testFocusChangeWithUnknownFocusedWindowRaises() {
        // 前面アプリのフォーカスウィンドウが取れない（デスクトップ等）場合も覆われうるので上げ直す。
        var state = PinState<FakeWindow>()
        _ = state.handle(.toggleRequested(focused: a1))
        XCTAssertEqual(state.handle(.focusChanged(focused: nil)), [.raise(a1)])
    }

    func testFocusOnPinnedWindowItselfDoesNotRaise() {
        var state = PinState<FakeWindow>()
        _ = state.handle(.toggleRequested(focused: a1))
        XCTAssertEqual(state.handle(.focusChanged(focused: a1)), [])
    }

    func testFocusOnOtherWindowOfPinnedAppDoesNotRaise() {
        // 固定中アプリ自身の中でウィンドウを切り替える操作は妨げない
        // （上げ直すとフォーカスが固定ウィンドウへ奪われるため）。
        var state = PinState<FakeWindow>()
        _ = state.handle(.toggleRequested(focused: a1))
        XCTAssertEqual(state.handle(.focusChanged(focused: a2)), [])
    }

    func testFocusChangeWhenNothingPinnedDoesNothing() {
        var state = PinState<FakeWindow>()
        XCTAssertEqual(state.handle(.focusChanged(focused: b1)), [])
    }

    // MARK: - 固定対象の消滅

    func testPinnedWindowClosedUnpins() {
        var state = PinState<FakeWindow>()
        _ = state.handle(.toggleRequested(focused: a1))
        XCTAssertEqual(state.handle(.windowClosed(a1)), [.unpinned(a1)])
        XCTAssertNil(state.pinned)
    }

    func testOtherWindowClosedIsIgnored() {
        var state = PinState<FakeWindow>()
        _ = state.handle(.toggleRequested(focused: a1))
        XCTAssertEqual(state.handle(.windowClosed(c1)), [])
        XCTAssertEqual(state.pinned, a1)
    }

    func testPinnedAppTerminatedUnpins() {
        var state = PinState<FakeWindow>()
        _ = state.handle(.toggleRequested(focused: a1))
        XCTAssertEqual(state.handle(.appTerminated(pid: 100)), [.unpinned(a1)])
        XCTAssertNil(state.pinned)
    }

    func testOtherAppTerminatedIsIgnored() {
        var state = PinState<FakeWindow>()
        _ = state.handle(.toggleRequested(focused: a1))
        XCTAssertEqual(state.handle(.appTerminated(pid: 200)), [])
        XCTAssertEqual(state.pinned, a1)
    }
}
