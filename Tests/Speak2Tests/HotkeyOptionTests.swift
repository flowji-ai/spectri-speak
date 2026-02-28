import XCTest
@testable import Speak2

final class HotkeyOptionTests: XCTestCase {

    // MARK: - Toggle Mode

    func testDoubleTapControlIsToggleMode() {
        XCTAssertTrue(HotkeyOption.doubleTapControl.isToggleMode)
    }

    func testFnKeyIsNotToggleMode() {
        XCTAssertFalse(HotkeyOption.fnKey.isToggleMode)
    }

    func testRightOptionIsNotToggleMode() {
        XCTAssertFalse(HotkeyOption.rightOption.isToggleMode)
    }

    func testRightCommandIsNotToggleMode() {
        XCTAssertFalse(HotkeyOption.rightCommand.isToggleMode)
    }

    func testHyperKeyIsNotToggleMode() {
        XCTAssertFalse(HotkeyOption.hyperKey.isToggleMode)
    }

    func testCtrlOptionSpaceIsNotToggleMode() {
        XCTAssertFalse(HotkeyOption.ctrlOptionSpace.isToggleMode)
    }

    func testOnlyDoubleTapControlIsToggleMode() {
        let toggleOptions = HotkeyOption.allCases.filter { $0.isToggleMode }
        XCTAssertEqual(toggleOptions.count, 1)
        XCTAssertEqual(toggleOptions.first, .doubleTapControl)
    }

    // MARK: - Display Names

    func testDoubleTapControlDisplayName() {
        XCTAssertEqual(HotkeyOption.doubleTapControl.displayName, "Double-tap Control (toggle)")
    }

    func testAllHoldModesDisplayNamesContainHold() {
        let holdOptions = HotkeyOption.allCases.filter { !$0.isToggleMode }
        for option in holdOptions {
            XCTAssertTrue(option.displayName.contains("hold"),
                          "\(option.rawValue) display name should contain 'hold' but was '\(option.displayName)'")
        }
    }

    func testToggleModeDisplayNameContainsToggle() {
        let toggleOptions = HotkeyOption.allCases.filter { $0.isToggleMode }
        for option in toggleOptions {
            XCTAssertTrue(option.displayName.contains("toggle"),
                          "\(option.rawValue) display name should contain 'toggle' but was '\(option.displayName)'")
        }
    }

    func testAllCasesHaveNonEmptyDisplayNames() {
        for option in HotkeyOption.allCases {
            XCTAssertFalse(option.displayName.isEmpty, "\(option.rawValue) should have a non-empty display name")
        }
    }

    // MARK: - Raw Values

    func testDoubleTapControlRawValue() {
        XCTAssertEqual(HotkeyOption.doubleTapControl.rawValue, "doubleTapControl")
    }

    func testRoundTripFromRawValue() {
        for option in HotkeyOption.allCases {
            let roundTripped = HotkeyOption(rawValue: option.rawValue)
            XCTAssertEqual(roundTripped, option, "Round-trip failed for \(option.rawValue)")
        }
    }

    // MARK: - CaseIterable

    func testAllCasesCount() {
        // 5 hold modes + 1 toggle mode = 6 total
        XCTAssertEqual(HotkeyOption.allCases.count, 6)
    }
}
