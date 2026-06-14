import XCTest
@testable import ScreenOSKit

final class HotkeyManagerTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        // Clean up after each test so hotkey state doesn't bleed between tests
        HotkeyManager.shared.unregisterAll()
        HotkeyManager.shared.onShowDesktop     = nil
        HotkeyManager.shared.onTileLeft        = nil
        HotkeyManager.shared.onTileRight       = nil
        HotkeyManager.shared.onTileTop         = nil
        HotkeyManager.shared.onTileBottom      = nil
        HotkeyManager.shared.onTileTopLeft     = nil
        HotkeyManager.shared.onTileTopRight    = nil
        HotkeyManager.shared.onTileBottomLeft  = nil
        HotkeyManager.shared.onTileBottomRight = nil
        HotkeyManager.shared.onMaximize        = nil
        HotkeyManager.shared.onCenter          = nil
        HotkeyManager.shared.onSwitcher        = nil
    }

    // MARK: - Callback storage

    func test_callbackCanBeSetAndInvoked() {
        var fired = false
        HotkeyManager.shared.onShowDesktop = { fired = true }
        HotkeyManager.shared.onShowDesktop?()
        XCTAssertTrue(fired)
    }

    func test_callbackCanBeCleared() {
        var fired = false
        HotkeyManager.shared.onShowDesktop = { fired = true }
        HotkeyManager.shared.onShowDesktop = nil
        HotkeyManager.shared.onShowDesktop?()
        XCTAssertFalse(fired)
    }

    func test_allCallbacksFireIndependently() {
        var log: [String] = []
        let hm = HotkeyManager.shared

        hm.onTileLeft        = { log.append("left") }
        hm.onTileRight       = { log.append("right") }
        hm.onTileTop         = { log.append("top") }
        hm.onTileBottom      = { log.append("bottom") }
        hm.onTileTopLeft     = { log.append("topLeft") }
        hm.onTileTopRight    = { log.append("topRight") }
        hm.onTileBottomLeft  = { log.append("bottomLeft") }
        hm.onTileBottomRight = { log.append("bottomRight") }
        hm.onMaximize        = { log.append("maximize") }
        hm.onCenter          = { log.append("center") }
        hm.onSwitcher        = { log.append("switcher") }
        hm.onShowDesktop     = { log.append("showDesktop") }

        hm.onTileLeft?()
        hm.onTileRight?()
        hm.onTileTop?()
        hm.onTileBottom?()
        hm.onTileTopLeft?()
        hm.onTileTopRight?()
        hm.onTileBottomLeft?()
        hm.onTileBottomRight?()
        hm.onMaximize?()
        hm.onCenter?()
        hm.onSwitcher?()
        hm.onShowDesktop?()

        XCTAssertEqual(log, [
            "left", "right", "top", "bottom",
            "topLeft", "topRight", "bottomLeft", "bottomRight",
            "maximize", "center", "switcher", "showDesktop"
        ])
    }

    func test_callbackReplacement_usesLatestClosure() {
        var result = 0
        HotkeyManager.shared.onShowDesktop = { result = 1 }
        HotkeyManager.shared.onShowDesktop = { result = 2 }
        HotkeyManager.shared.onShowDesktop?()
        XCTAssertEqual(result, 2)
    }

    // MARK: - Registration lifecycle

    func test_unregisterAll_doesNotCrash() {
        HotkeyManager.shared.unregisterAll()
        HotkeyManager.shared.unregisterAll()   // idempotent
    }

    func test_registerAndUnregister_doesNotCrash() {
        HotkeyManager.shared.registerDefaults()
        HotkeyManager.shared.unregisterAll()
    }

    func test_registerWithSavedShortcuts_doesNotCrash() {
        HotkeyManager.shared.registerWithSavedShortcuts()
        HotkeyManager.shared.unregisterAll()
    }

    func test_multipleRegisterCycles_doNotCrash() {
        for _ in 0..<3 {
            HotkeyManager.shared.registerDefaults()
            HotkeyManager.shared.unregisterAll()
        }
    }

    // MARK: - Callback invocation count

    func test_callbackInvokedExactlyOnce() {
        var callCount = 0
        HotkeyManager.shared.onCenter = { callCount += 1 }
        HotkeyManager.shared.onCenter?()
        XCTAssertEqual(callCount, 1)
    }

    func test_callbackInvokedMultipleTimes() {
        var callCount = 0
        HotkeyManager.shared.onMaximize = { callCount += 1 }
        HotkeyManager.shared.onMaximize?()
        HotkeyManager.shared.onMaximize?()
        HotkeyManager.shared.onMaximize?()
        XCTAssertEqual(callCount, 3)
    }

    // MARK: - Thread safety (basic check)

    func test_callbacksCanBeSetFromAnyThread() {
        let expectation = self.expectation(description: "callback set from background thread")

        DispatchQueue.global().async {
            HotkeyManager.shared.onSwitcher = { }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }
}
