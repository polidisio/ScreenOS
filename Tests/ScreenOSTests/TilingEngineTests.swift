import XCTest
@testable import ScreenOSKit

// Simulates a 1920×1080 display with menu bar (23 pt) and no dock.
// All tiling assertions use this fixed rect so tests are deterministic
// and don't depend on the hardware running the suite.
private let screen = CGRect(x: 0, y: 23, width: 1920, height: 1057)

final class TilingEngineTests: XCTestCase {

    let engine = TilingEngine.shared

    // MARK: - Half-screen positions

    func test_left_occupiesLeftHalf() {
        let frame = engine.frame(for: .left, currentFrame: .zero, screenFrame: screen)
        XCTAssertEqual(frame.minX, screen.minX)
        XCTAssertEqual(frame.minY, screen.minY)
        XCTAssertEqual(frame.width, screen.width / 2)
        XCTAssertEqual(frame.height, screen.height)
    }

    func test_right_occupiesRightHalf() {
        let frame = engine.frame(for: .right, currentFrame: .zero, screenFrame: screen)
        XCTAssertEqual(frame.minX, screen.midX)
        XCTAssertEqual(frame.minY, screen.minY)
        XCTAssertEqual(frame.width, screen.width / 2)
        XCTAssertEqual(frame.height, screen.height)
    }

    func test_top_occupiesUpperHalf() {
        // macOS: higher Y values = upper part of screen
        let frame = engine.frame(for: .top, currentFrame: .zero, screenFrame: screen)
        XCTAssertEqual(frame.minY, screen.midY)
        XCTAssertEqual(frame.width, screen.width)
        XCTAssertEqual(frame.height, screen.height / 2)
    }

    func test_bottom_occupiesLowerHalf() {
        let frame = engine.frame(for: .bottom, currentFrame: .zero, screenFrame: screen)
        XCTAssertEqual(frame.minY, screen.minY)
        XCTAssertEqual(frame.width, screen.width)
        XCTAssertEqual(frame.height, screen.height / 2)
    }

    // MARK: - Quarter positions

    func test_topLeft_occupiesUpperLeftQuarter() {
        let frame = engine.frame(for: .topLeft, currentFrame: .zero, screenFrame: screen)
        XCTAssertEqual(frame.minX, screen.minX)
        XCTAssertEqual(frame.minY, screen.midY)
        XCTAssertEqual(frame.width, screen.width / 2)
        XCTAssertEqual(frame.height, screen.height / 2)
    }

    func test_topRight_occupiesUpperRightQuarter() {
        let frame = engine.frame(for: .topRight, currentFrame: .zero, screenFrame: screen)
        XCTAssertEqual(frame.minX, screen.midX)
        XCTAssertEqual(frame.minY, screen.midY)
        XCTAssertEqual(frame.width, screen.width / 2)
        XCTAssertEqual(frame.height, screen.height / 2)
    }

    func test_bottomLeft_occupiesLowerLeftQuarter() {
        let frame = engine.frame(for: .bottomLeft, currentFrame: .zero, screenFrame: screen)
        XCTAssertEqual(frame.minX, screen.minX)
        XCTAssertEqual(frame.minY, screen.minY)
        XCTAssertEqual(frame.width, screen.width / 2)
        XCTAssertEqual(frame.height, screen.height / 2)
    }

    func test_bottomRight_occupiesLowerRightQuarter() {
        let frame = engine.frame(for: .bottomRight, currentFrame: .zero, screenFrame: screen)
        XCTAssertEqual(frame.minX, screen.midX)
        XCTAssertEqual(frame.minY, screen.minY)
        XCTAssertEqual(frame.width, screen.width / 2)
        XCTAssertEqual(frame.height, screen.height / 2)
    }

    // MARK: - Special positions

    func test_maximize_fillsEntireScreen() {
        let frame = engine.frame(for: .maximize, currentFrame: .zero, screenFrame: screen)
        XCTAssertEqual(frame, screen)
    }

    func test_center_is60x80PercentOfScreen() {
        let frame = engine.frame(for: .center, currentFrame: .zero, screenFrame: screen)
        XCTAssertEqual(frame.width,  screen.width  * 0.6, accuracy: 0.01)
        XCTAssertEqual(frame.height, screen.height * 0.8, accuracy: 0.01)
    }

    func test_center_isCenteredWithinScreen() {
        let frame = engine.frame(for: .center, currentFrame: .zero, screenFrame: screen)
        XCTAssertEqual(frame.midX, screen.midX, accuracy: 0.01)
        XCTAssertEqual(frame.midY, screen.midY, accuracy: 0.01)
    }

    // MARK: - Non-overlap assertions

    func test_leftAndRight_doNotOverlap() {
        let l = engine.frame(for: .left,  currentFrame: .zero, screenFrame: screen)
        let r = engine.frame(for: .right, currentFrame: .zero, screenFrame: screen)
        XCTAssertFalse(l.insetBy(dx: 0.1, dy: 0.1).intersects(r.insetBy(dx: 0.1, dy: 0.1)))
    }

    func test_topAndBottom_doNotOverlap() {
        let t = engine.frame(for: .top,    currentFrame: .zero, screenFrame: screen)
        let b = engine.frame(for: .bottom, currentFrame: .zero, screenFrame: screen)
        XCTAssertFalse(t.insetBy(dx: 0, dy: 0.1).intersects(b.insetBy(dx: 0, dy: 0.1)))
    }

    func test_fourQuarters_doNotOverlapEachOther() {
        let quarters: [TilingEngine.TilingPosition] = [.topLeft, .topRight, .bottomLeft, .bottomRight]
        let frames = quarters.map { engine.frame(for: $0, currentFrame: .zero, screenFrame: screen) }

        for (i, a) in frames.enumerated() {
            for (j, b) in frames.enumerated() where i != j {
                XCTAssertFalse(
                    a.insetBy(dx: 0.1, dy: 0.1).intersects(b.insetBy(dx: 0.1, dy: 0.1)),
                    "\(quarters[i]) overlaps \(quarters[j])"
                )
            }
        }
    }

    // MARK: - Coverage

    func test_leftRight_unionEqualsScreen() {
        let l = engine.frame(for: .left,  currentFrame: .zero, screenFrame: screen)
        let r = engine.frame(for: .right, currentFrame: .zero, screenFrame: screen)
        XCTAssertEqual(l.union(r), screen)
    }

    func test_allPositions_fitWithinScreen() {
        for position in TilingEngine.TilingPosition.allCases {
            let frame = engine.frame(for: position, currentFrame: .zero, screenFrame: screen)
            let fitsX = frame.minX >= screen.minX && frame.maxX <= screen.maxX + 0.01
            let fitsY = frame.minY >= screen.minY && frame.maxY <= screen.maxY + 0.01
            XCTAssertTrue(fitsX && fitsY,
                          "\(position.rawValue): frame \(frame) exceeds screen \(screen)")
        }
    }

    func test_allCasesAreReachable() {
        // Verify CaseIterable covers all 10 positions
        XCTAssertEqual(TilingEngine.TilingPosition.allCases.count, 10)
    }

    // MARK: - Offset screens

    func test_offsetScreen_maintainsRelativePositions() {
        // Screen at x=2560 (second monitor)
        let secondScreen = CGRect(x: 2560, y: 23, width: 1920, height: 1057)

        let left  = engine.frame(for: .left,  currentFrame: .zero, screenFrame: secondScreen)
        let right = engine.frame(for: .right, currentFrame: .zero, screenFrame: secondScreen)

        XCTAssertEqual(left.minX,  secondScreen.minX)
        XCTAssertEqual(right.minX, secondScreen.midX)
        XCTAssertEqual(left.union(right), secondScreen)
    }
}
