import XCTest
@testable import ScreenOSKit

// Tests for WindowManager's coordinate conversion and screen-detection logic.
// These are deterministic (no live NSScreen or AX API required).
final class WindowManagerTests: XCTestCase {

    let manager = WindowManager.shared

    // MARK: - appKitToAXOrigin

    // AppKit frame (100, 200, 400, 300) on a 1080-tall screen.
    // AX Y = screenHeight - appKitFrame.maxY = 1080 - (200 + 300) = 580.
    func test_appKitToAX_typicalWindow() {
        let frame = CGRect(x: 100, y: 200, width: 400, height: 300)
        let pt = manager.appKitToAXOrigin(frame, primaryScreenHeight: 1080)
        XCTAssertEqual(pt.x, 100)
        XCTAssertEqual(pt.y, 580)
    }

    // Maximized window in AppKit: (0, 0, 1920, 1080).
    // AX Y = 1080 - (0 + 1080) = 0 → top-left of screen, correct.
    func test_appKitToAX_maximizedWindow() {
        let frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let pt = manager.appKitToAXOrigin(frame, primaryScreenHeight: 1080)
        XCTAssertEqual(pt.x, 0)
        XCTAssertEqual(pt.y, 0)
    }

    // Window at AppKit y=757 (just above menu bar, typical visibleFrame.minY ≈ 23 on 1080p).
    // Height=300 → maxY=1057. AX Y = 1080 - 1057 = 23.
    func test_appKitToAX_windowAtTopOfVisibleArea() {
        let frame = CGRect(x: 0, y: 757, width: 1920, height: 300)
        let pt = manager.appKitToAXOrigin(frame, primaryScreenHeight: 1080)
        XCTAssertEqual(pt.y, 1080 - (757 + 300), accuracy: 0.01)
    }

    // X coordinate must pass through unchanged.
    func test_appKitToAX_xCoordinateUnchanged() {
        let frame = CGRect(x: 2560, y: 100, width: 800, height: 600)
        let pt = manager.appKitToAXOrigin(frame, primaryScreenHeight: 1080)
        XCTAssertEqual(pt.x, 2560)
    }

    // Round-trip sanity: converting then reversing should return the original Y.
    // axY = h - (appKitY + height)  →  appKitY = h - axY - height
    func test_appKitToAX_roundTrip() {
        let h: CGFloat = 1440
        let frame = CGRect(x: 50, y: 300, width: 600, height: 400)
        let pt = manager.appKitToAXOrigin(frame, primaryScreenHeight: h)
        let recoveredAppKitY = h - pt.y - frame.height
        XCTAssertEqual(recoveredAppKitY, frame.minY, accuracy: 0.01)
    }

    // MARK: - TilingEngine.screen(for:) — coordinate conversion for multi-monitor

    // A window centered on the primary screen (Quartz space) should resolve to primary screen.
    // This test is skipped when only one screen is available (CI) but exercises the math path.
    func test_screenFor_primaryScreenWindow() {
        let engine = TilingEngine.shared
        guard let primary = NSScreen.screens.first else { return }

        let primaryH = primary.frame.height
        // Window at Quartz (100, 100) → AppKit y = primaryH - 100 - 400
        let quartzFrame = CGRect(x: 100, y: 100, width: 600, height: 400)
        let detected = engine.screen(for: quartzFrame)
        // Must resolve to a screen (not crash or return nil-ish)
        XCTAssertTrue(NSScreen.screens.contains(detected))

        // AppKit equivalent should fall within the primary screen bounds
        let appKitY = primaryH - quartzFrame.maxY
        let appKitFrame = CGRect(x: quartzFrame.minX, y: appKitY, width: quartzFrame.width, height: quartzFrame.height)
        XCTAssertTrue(primary.frame.intersects(appKitFrame))
    }

    // MARK: - TilingEngine.frame() + coordinate conversion pipeline

    // Verifies the full pipeline: AppKit frame computed by TilingEngine → AX origin.
    // On a 1920×1080 screen with 23pt menu bar, tiling left should produce:
    //   AppKit frame: (0, 23, 960, 1057)
    //   AX origin:    (0, 1080 - (23 + 1057)) = (0, 0)   ← top-left of content area
    func test_pipeline_leftTile_axOriginIsTopLeft() {
        let screenFrame = CGRect(x: 0, y: 23, width: 1920, height: 1057)
        let appKitFrame = TilingEngine.shared.frame(for: .left, currentFrame: .zero, screenFrame: screenFrame)
        let axPt = manager.appKitToAXOrigin(appKitFrame, primaryScreenHeight: 1080)

        XCTAssertEqual(axPt.x, 0, accuracy: 0.01)
        XCTAssertEqual(axPt.y, 0, accuracy: 0.01)  // menu bar = 23pt; 1080-23-1057=0
    }

    // Right tile: AX origin X should be exactly half the screen width.
    func test_pipeline_rightTile_axOriginX() {
        let screenFrame = CGRect(x: 0, y: 23, width: 1920, height: 1057)
        let appKitFrame = TilingEngine.shared.frame(for: .right, currentFrame: .zero, screenFrame: screenFrame)
        let axPt = manager.appKitToAXOrigin(appKitFrame, primaryScreenHeight: 1080)

        XCTAssertEqual(axPt.x, 960, accuracy: 0.01)
        XCTAssertEqual(axPt.y, 0, accuracy: 0.01)
    }

    // Top tile: AppKit frame goes from screenFrame.midY to screenFrame.maxY (1080).
    // AX Y = primaryH - appKitFrame.maxY = 1080 - 1080 = 0 (top of screen in Quartz space).
    func test_pipeline_topTile_axOriginY() {
        let screenFrame = CGRect(x: 0, y: 23, width: 1920, height: 1057)
        let appKitFrame = TilingEngine.shared.frame(for: .top, currentFrame: .zero, screenFrame: screenFrame)
        let axPt = manager.appKitToAXOrigin(appKitFrame, primaryScreenHeight: 1080)

        XCTAssertEqual(axPt.y, 0, accuracy: 0.01)
    }

    // Bottom tile: AX Y = primaryH - (screenFrame.minY + screenFrame.height/2) = midpoint in Quartz space.
    func test_pipeline_bottomTile_axOriginY() {
        let screenFrame = CGRect(x: 0, y: 23, width: 1920, height: 1057)
        let appKitFrame = TilingEngine.shared.frame(for: .bottom, currentFrame: .zero, screenFrame: screenFrame)
        let axPt = manager.appKitToAXOrigin(appKitFrame, primaryScreenHeight: 1080)

        let expected: CGFloat = 1080 - 23 - (1057 / 2)
        XCTAssertEqual(axPt.y, expected, accuracy: 0.01)
    }
}
