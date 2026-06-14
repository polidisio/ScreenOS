import XCTest
@testable import ScreenOSKit

// NOTE: Full ShowDesktopManager tests require Accessibility permission
// (AXUIElement cannot minimize/restore windows without it).
// The tests here verify the state machine and API surface without
// exercising the actual AX calls.
final class ShowDesktopManagerTests: XCTestCase {

    // MARK: - API surface

    func test_sharedInstance_isAvailable() {
        XCTAssertNotNil(ShowDesktopManager.shared)
    }

    func test_isActive_isBool() {
        let _ = ShowDesktopManager.shared.isActive  // must compile + not crash
    }

    func test_toggle_doesNotCrash() {
        // With no Accessibility permission in CI, the AX calls silently fail.
        // What matters here is that the state machine transitions correctly
        // and the function doesn't throw or crash.
        let manager = ShowDesktopManager.shared
        let stateBefore = manager.isActive
        manager.toggle()
        // State should have changed
        XCTAssertNotEqual(manager.isActive, stateBefore)
        // Restore
        manager.toggle()
        XCTAssertEqual(manager.isActive, stateBefore)
    }

    func test_doubleToggle_returnsToOriginalState() {
        let manager = ShowDesktopManager.shared
        let original = manager.isActive
        manager.toggle()
        manager.toggle()
        XCTAssertEqual(manager.isActive, original)
    }

    func test_isActive_reflectsHideState() {
        let manager = ShowDesktopManager.shared
        // Force to known state: toggle until not active
        if manager.isActive { manager.toggle() }
        XCTAssertFalse(manager.isActive)

        manager.toggle()   // hide
        XCTAssertTrue(manager.isActive)

        manager.toggle()   // restore
        XCTAssertFalse(manager.isActive)
    }

    func test_multipleToggles_stateIsConsistent() {
        let manager = ShowDesktopManager.shared
        if manager.isActive { manager.toggle() }

        for i in 0..<6 {
            let expectedActive = (i % 2 == 0)  // even iterations: active after toggle
            manager.toggle()
            XCTAssertEqual(manager.isActive, expectedActive,
                           "After \(i + 1) toggle(s), isActive should be \(expectedActive)")
        }

        // Leave in clean state
        if manager.isActive { manager.toggle() }
    }
}
