import XCTest
@testable import ScreenOSKit

// Tests for SwitcherPanel.filter(_:query:) — the pure search logic
// that powers the window switcher search field.
final class SwitcherFilterTests: XCTestCase {

    private var nextID: UInt32 = 1

    private func makeWindow(title: String, appName: String) -> ScreenWindow {
        defer { nextID += 1 }
        return ScreenWindow(
            id: nextID,
            pid: 1,
            appName: appName,
            appIcon: nil,
            title: title,
            frame: .zero,
            layer: 0,
            isMinimized: false,
            isOnScreen: true,
            axElement: nil
        )
    }

    private lazy var windows: [ScreenWindow] = [
        makeWindow(title: "AppDelegate.swift",    appName: "Xcode"),
        makeWindow(title: "ContentView.swift",    appName: "Xcode"),
        makeWindow(title: "GitHub — Safari",      appName: "Safari"),
        makeWindow(title: "Terminal",              appName: "Terminal"),
        makeWindow(title: "Untitled — TextEdit",  appName: "TextEdit"),
        makeWindow(title: "Finder",               appName: "Finder"),
    ]

    // MARK: - Empty / whitespace query

    func test_emptyQuery_returnsAllWindows() {
        let result = SwitcherPanel.filter(windows, query: "")
        XCTAssertEqual(result.count, windows.count)
    }

    func test_whitespaceOnlyQuery_returnsAllWindows() {
        XCTAssertEqual(SwitcherPanel.filter(windows, query: "   ").count, windows.count)
        XCTAssertEqual(SwitcherPanel.filter(windows, query: "\t").count, windows.count)
    }

    // MARK: - Title matching

    func test_filterByTitleSubstring_caseInsensitive() {
        let result = SwitcherPanel.filter(windows, query: "swift")
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.title.lowercased().contains("swift") })
    }

    func test_filterByTitle_uppercaseQuery() {
        let result = SwitcherPanel.filter(windows, query: "FINDER")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Finder")
    }

    func test_filterByTitle_mixedCase() {
        let result = SwitcherPanel.filter(windows, query: "GitHub")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.appName, "Safari")
    }

    // MARK: - App name matching

    func test_filterByAppName_returnsAllWindowsFromThatApp() {
        let result = SwitcherPanel.filter(windows, query: "xcode")
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.appName == "Xcode" })
    }

    func test_filterByAppName_singleResult() {
        let result = SwitcherPanel.filter(windows, query: "textedit")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.appName, "TextEdit")
    }

    // MARK: - Title OR app name

    func test_queryMatchesTitleInOneAppAndNameInAnother() {
        // "terminal" matches the Terminal window title AND the Terminal app name
        let result = SwitcherPanel.filter(windows, query: "terminal")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.appName, "Terminal")
    }

    // MARK: - No match

    func test_noMatch_returnsEmpty() {
        let result = SwitcherPanel.filter(windows, query: "zzznomatch")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Order preservation

    func test_filterPreservesOriginalOrder() {
        let result = SwitcherPanel.filter(windows, query: "xcode")
        let expectedTitles = windows
            .filter { $0.appName == "Xcode" }
            .map(\.title)
        XCTAssertEqual(result.map(\.title), expectedTitles)
    }

    // MARK: - Edge cases

    func test_filterOnEmptyInput_returnsEmpty() {
        let result = SwitcherPanel.filter([], query: "xcode")
        XCTAssertTrue(result.isEmpty)
    }

    func test_filterWithSingleCharacter() {
        let result = SwitcherPanel.filter(windows, query: "x")
        // Matches "Xcode" app name (2 windows) and "TextEdit" app name (1 window)
        XCTAssertGreaterThanOrEqual(result.count, 2)
    }

    func test_filterWithSpecialCharacters() {
        // Em dash in "GitHub — Safari"
        let result = SwitcherPanel.filter(windows, query: "—")
        XCTAssertGreaterThanOrEqual(result.count, 1)
    }
}
