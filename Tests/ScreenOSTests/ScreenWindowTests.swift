import XCTest
@testable import ScreenOSKit

final class ScreenWindowTests: XCTestCase {

    // MARK: - Helpers

    private func makeWindow(
        id: CGWindowID = 1,
        pid: pid_t = 100,
        appName: String = "TestApp",
        title: String = "Test Window",
        frame: CGRect = CGRect(x: 100, y: 200, width: 800, height: 600),
        layer: UInt32 = 0,
        isMinimized: Bool = false
    ) -> ScreenWindow {
        ScreenWindow(
            id: id,
            pid: pid,
            appName: appName,
            appIcon: nil,
            title: title,
            frame: frame,
            layer: layer,
            isMinimized: isMinimized,
            isOnScreen: !isMinimized,
            axElement: nil
        )
    }

    // MARK: - Equality

    func test_equality_isByWindowID() {
        let w1 = makeWindow(id: 42, pid: 100)
        let w2 = makeWindow(id: 42, pid: 999, appName: "Different", title: "Different")
        XCTAssertEqual(w1, w2, "Windows with the same id should be equal regardless of other fields")
    }

    func test_inequality_differentIDs() {
        let w1 = makeWindow(id: 1)
        let w2 = makeWindow(id: 2)
        XCTAssertNotEqual(w1, w2)
    }

    // MARK: - Hashing

    func test_hash_isByWindowID() {
        let w1 = makeWindow(id: 7)
        let w2 = makeWindow(id: 7, pid: 9999)
        XCTAssertEqual(w1.hashValue, w2.hashValue)
    }

    func test_usableInSet_deduplicatesByID() {
        let w1 = makeWindow(id: 1)
        let w2 = makeWindow(id: 2)
        let w3 = makeWindow(id: 1)   // duplicate of w1
        let set = Set([w1, w2, w3])
        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(w1))
        XCTAssertTrue(set.contains(w2))
    }

    func test_usableAsDictionaryKey() {
        let w1 = makeWindow(id: 1)
        var dict: [ScreenWindow: String] = [:]
        dict[w1] = "value"
        let w1Duplicate = makeWindow(id: 1, pid: 555)
        XCTAssertEqual(dict[w1Duplicate], "value")
    }

    // MARK: - Properties

    func test_allPropertiesAreStoredCorrectly() {
        let frame = CGRect(x: 10, y: 20, width: 1280, height: 800)
        let w = ScreenWindow(
            id: 99,
            pid: 1234,
            appName: "Safari",
            appIcon: nil,
            title: "GitHub — Safari",
            frame: frame,
            layer: 3,
            isMinimized: false,
            isOnScreen: true,
            axElement: nil
        )
        XCTAssertEqual(w.id, 99)
        XCTAssertEqual(w.pid, 1234)
        XCTAssertEqual(w.appName, "Safari")
        XCTAssertNil(w.appIcon)
        XCTAssertEqual(w.title, "GitHub — Safari")
        XCTAssertEqual(w.frame, frame)
        XCTAssertEqual(w.layer, 3)
        XCTAssertFalse(w.isMinimized)
        XCTAssertTrue(w.isOnScreen)
        XCTAssertNil(w.axElement)
    }

    func test_minimizedWindow_isNotOnScreen() {
        let w = makeWindow(isMinimized: true)
        XCTAssertTrue(w.isMinimized)
        XCTAssertFalse(w.isOnScreen)
    }

    func test_visibleWindow_isOnScreen() {
        let w = makeWindow(isMinimized: false)
        XCTAssertFalse(w.isMinimized)
        XCTAssertTrue(w.isOnScreen)
    }

    // MARK: - Identifiable

    func test_identifiable_idMatchesCGWindowID() {
        let w = makeWindow(id: 55)
        XCTAssertEqual(w.id, 55)
    }

    // MARK: - Layer ordering

    func test_lowerLayer_isOrderedFirst() {
        let windows = [
            makeWindow(id: 1, layer: 5),
            makeWindow(id: 2, layer: 1),
            makeWindow(id: 3, layer: 3),
        ]
        let sorted = windows.sorted { $0.layer < $1.layer }
        XCTAssertEqual(sorted.map(\.id), [2, 3, 1])
    }
}
