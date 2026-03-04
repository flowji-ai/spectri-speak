import XCTest
@testable import Speak2

final class HotkeyOptionTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        // Clean up UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: "hotkeyOption")
        UserDefaults.standard.removeObject(forKey: "hotkeyToggleMode")
    }

    // MARK: - Toggle Mode (static property)

    func testIsToggleModeDefaultsFalse() {
        UserDefaults.standard.removeObject(forKey: "hotkeyToggleMode")
        XCTAssertFalse(HotkeyOption.isToggleMode)
    }

    func testIsToggleModeRoundTrips() {
        HotkeyOption.isToggleMode = true
        XCTAssertTrue(HotkeyOption.isToggleMode)

        HotkeyOption.isToggleMode = false
        XCTAssertFalse(HotkeyOption.isToggleMode)
    }

    // MARK: - Key Names

    func testKeyNames() {
        XCTAssertEqual(HotkeyOption.fnKey.keyName, "Fn")
        XCTAssertEqual(HotkeyOption.rightOption.keyName, "Right Option")
        XCTAssertEqual(HotkeyOption.rightCommand.keyName, "Right Command")
        XCTAssertTrue(HotkeyOption.hyperKey.keyName.contains("Hyper"))
        XCTAssertTrue(HotkeyOption.ctrlOptionSpace.keyName.contains("Ctrl"))
    }

    // MARK: - Display Names

    func testDisplayNameContainsHoldWhenNotToggleMode() {
        HotkeyOption.isToggleMode = false
        for option in HotkeyOption.allCases {
            XCTAssertTrue(option.displayName.contains("hold"),
                          "\(option.rawValue) display name should contain 'hold' but was '\(option.displayName)'")
        }
    }

    func testDisplayNameContainsPressTwiceWhenToggleMode() {
        HotkeyOption.isToggleMode = true
        for option in HotkeyOption.allCases {
            XCTAssertTrue(option.displayName.contains("press twice"),
                          "\(option.rawValue) display name should contain 'press twice' but was '\(option.displayName)'")
        }
    }

    func testAllCasesHaveNonEmptyDisplayNames() {
        for option in HotkeyOption.allCases {
            XCTAssertFalse(option.displayName.isEmpty, "\(option.rawValue) should have a non-empty display name")
        }
    }

    // MARK: - Raw Values

    func testRoundTripFromRawValue() {
        for option in HotkeyOption.allCases {
            let roundTripped = HotkeyOption(rawValue: option.rawValue)
            XCTAssertEqual(roundTripped, option, "Round-trip failed for \(option.rawValue)")
        }
    }

    // MARK: - CaseIterable

    func testAllCasesCount() {
        // 6 hotkey options (doubleTapControl removed, custom added)
        XCTAssertEqual(HotkeyOption.allCases.count, 6)
    }

    // MARK: - Migration

    func testDoubleTapControlMigratesToFnKeyWithToggle() {
        UserDefaults.standard.set("doubleTapControl", forKey: "hotkeyOption")
        HotkeyOption.isToggleMode = false

        let saved = HotkeyOption.saved
        XCTAssertEqual(saved, .fnKey)
        XCTAssertTrue(HotkeyOption.isToggleMode)
        // Verify the raw value was updated
        XCTAssertEqual(UserDefaults.standard.string(forKey: "hotkeyOption"), "fn")
    }

    func testSavedDefaultsToFnKey() {
        UserDefaults.standard.removeObject(forKey: "hotkeyOption")
        XCTAssertEqual(HotkeyOption.saved, .fnKey)
    }

    func testSavedRoundTrips() {
        for option in HotkeyOption.allCases {
            HotkeyOption.saved = option
            XCTAssertEqual(HotkeyOption.saved, option)
        }
    }
}
