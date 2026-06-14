import XCTest
import Carbon
@testable import ScreenOSKit

final class ShortcutTests: XCTestCase {

    // MARK: - Display strings

    func test_cmdD_displayString() {
        let s = ShortcutRecorder.Shortcut(keyCode: UInt16(kVK_ANSI_D), flags: UInt32(cmdKey))
        XCTAssertEqual(s.displayString, "⌘D")
    }

    func test_cmdShiftD_containsAllModifiers() {
        let s = ShortcutRecorder.Shortcut(keyCode: UInt16(kVK_ANSI_D), flags: UInt32(cmdKey | shiftKey))
        XCTAssertTrue(s.displayString.contains("⌘"))
        XCTAssertTrue(s.displayString.contains("⇧"))
        XCTAssertTrue(s.displayString.contains("D"))
    }

    func test_cmdOptionLeft_arrowSymbol() {
        let s = ShortcutRecorder.Shortcut(keyCode: UInt16(kVK_LeftArrow), flags: UInt32(cmdKey | optionKey))
        XCTAssertTrue(s.displayString.contains("⌘"))
        XCTAssertTrue(s.displayString.contains("⌥"))
        XCTAssertTrue(s.displayString.contains("←"))
    }

    func test_cmdOptionRight_arrowSymbol() {
        let s = ShortcutRecorder.Shortcut(keyCode: UInt16(kVK_RightArrow), flags: UInt32(cmdKey | optionKey))
        XCTAssertTrue(s.displayString.contains("→"))
    }

    func test_cmdOptionUp_arrowSymbol() {
        let s = ShortcutRecorder.Shortcut(keyCode: UInt16(kVK_UpArrow), flags: UInt32(cmdKey | optionKey))
        XCTAssertTrue(s.displayString.contains("↑"))
    }

    func test_cmdOptionDown_arrowSymbol() {
        let s = ShortcutRecorder.Shortcut(keyCode: UInt16(kVK_DownArrow), flags: UInt32(cmdKey | optionKey))
        XCTAssertTrue(s.displayString.contains("↓"))
    }

    func test_cmdGrave_backtickSymbol() {
        let s = ShortcutRecorder.Shortcut(keyCode: UInt16(kVK_ANSI_Grave), flags: UInt32(cmdKey))
        XCTAssertTrue(s.displayString.contains("`"))
    }

    func test_cmdOptionM_letterM() {
        let s = ShortcutRecorder.Shortcut(keyCode: UInt16(kVK_ANSI_M), flags: UInt32(cmdKey | optionKey))
        // kVK_ANSI_M = 0x2E which maps to keyName lookup.
        // Verify it doesn't crash and produces some string.
        XCTAssertFalse(s.displayString.isEmpty)
    }

    func test_allFourModifiers_allSymbolsPresent() {
        let s = ShortcutRecorder.Shortcut(
            keyCode: UInt16(kVK_ANSI_A),
            flags: UInt32(cmdKey | optionKey | shiftKey | controlKey)
        )
        XCTAssertTrue(s.displayString.contains("⌘"))
        XCTAssertTrue(s.displayString.contains("⌥"))
        XCTAssertTrue(s.displayString.contains("⇧"))
        XCTAssertTrue(s.displayString.contains("⌃"))
        XCTAssertTrue(s.displayString.contains("A"))
    }

    func test_modifierOrder_cmdBeforeOptionBeforeShift() {
        let s = ShortcutRecorder.Shortcut(
            keyCode: UInt16(kVK_ANSI_A),
            flags: UInt32(cmdKey | optionKey | shiftKey)
        )
        let str = s.displayString
        let cmdIdx   = str.firstIndex(of: "⌘")
        let optIdx   = str.firstIndex(of: "⌥")
        let shiftIdx = str.firstIndex(of: "⇧")
        if let c = cmdIdx, let o = optIdx, let sh = shiftIdx {
            XCTAssertLessThan(c, o)
            XCTAssertLessThan(o, sh)
        }
    }

    // MARK: - Codable round-trip

    func test_codableRoundTrip_preservesKeyCodeAndFlags() throws {
        let original = ShortcutRecorder.Shortcut(keyCode: 36, flags: UInt32(cmdKey | shiftKey))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShortcutRecorder.Shortcut.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_codableRoundTrip_noModifiers() throws {
        let original = ShortcutRecorder.Shortcut(keyCode: UInt16(kVK_F5), flags: 0)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShortcutRecorder.Shortcut.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Equatable

    func test_sameKeyCodeAndFlags_areEqual() {
        let s1 = ShortcutRecorder.Shortcut(keyCode: 10, flags: UInt32(cmdKey))
        let s2 = ShortcutRecorder.Shortcut(keyCode: 10, flags: UInt32(cmdKey))
        XCTAssertEqual(s1, s2)
    }

    func test_differentKeyCode_notEqual() {
        let s1 = ShortcutRecorder.Shortcut(keyCode: 10, flags: UInt32(cmdKey))
        let s2 = ShortcutRecorder.Shortcut(keyCode: 11, flags: UInt32(cmdKey))
        XCTAssertNotEqual(s1, s2)
    }

    func test_differentFlags_notEqual() {
        let s1 = ShortcutRecorder.Shortcut(keyCode: 10, flags: UInt32(cmdKey))
        let s2 = ShortcutRecorder.Shortcut(keyCode: 10, flags: UInt32(cmdKey | shiftKey))
        XCTAssertNotEqual(s1, s2)
    }

    // MARK: - JSON storage (UserDefaults simulation)

    func test_canBeStoredAndRetrievedFromUserDefaults() throws {
        let key = "test_shortcut_\(UUID().uuidString)"
        let shortcut = ShortcutRecorder.Shortcut(keyCode: UInt16(kVK_ANSI_C), flags: UInt32(cmdKey | optionKey))

        let data = try JSONEncoder().encode(shortcut)
        UserDefaults.standard.set(data, forKey: key)

        guard let retrieved = UserDefaults.standard.data(forKey: key) else {
            XCTFail("No data in UserDefaults")
            return
        }

        let decoded = try JSONDecoder().decode(ShortcutRecorder.Shortcut.self, from: retrieved)
        XCTAssertEqual(shortcut, decoded)

        UserDefaults.standard.removeObject(forKey: key)
    }
}
