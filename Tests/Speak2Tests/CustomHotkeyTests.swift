import XCTest
import CoreGraphics
@testable import Speak2

final class KeycodeNamesTests: XCTestCase {

    // MARK: - Modifier key names

    func testLeftRightCommandNames() {
        XCTAssertEqual(KeycodeNames.name(for: 0x37, isModifier: true), "Left Command")
        XCTAssertEqual(KeycodeNames.name(for: 0x36, isModifier: true), "Right Command")
    }

    func testLeftRightOptionNames() {
        XCTAssertEqual(KeycodeNames.name(for: 0x3A, isModifier: true), "Left Option")
        XCTAssertEqual(KeycodeNames.name(for: 0x3D, isModifier: true), "Right Option")
    }

    func testLeftRightShiftNames() {
        XCTAssertEqual(KeycodeNames.name(for: 0x38, isModifier: true), "Left Shift")
        XCTAssertEqual(KeycodeNames.name(for: 0x3C, isModifier: true), "Right Shift")
    }

    func testLeftRightControlNames() {
        XCTAssertEqual(KeycodeNames.name(for: 0x3B, isModifier: true), "Left Control")
        XCTAssertEqual(KeycodeNames.name(for: 0x3E, isModifier: true), "Right Control")
    }

    func testFnKeyName() {
        XCTAssertEqual(KeycodeNames.name(for: 0x3F, isModifier: true), "Fn")
    }

    func testUnknownModifierFallback() {
        XCTAssertEqual(KeycodeNames.name(for: 0xFF, isModifier: true), "Modifier 255")
    }

    // MARK: - Regular key names

    func testLetterKeys() {
        XCTAssertEqual(KeycodeNames.name(for: 0x00, isModifier: false), "A")
        XCTAssertEqual(KeycodeNames.name(for: 0x06, isModifier: false), "Z")
        XCTAssertEqual(KeycodeNames.name(for: 0x2E, isModifier: false), "M")
    }

    func testNumberKeys() {
        XCTAssertEqual(KeycodeNames.name(for: 0x1D, isModifier: false), "0")
        XCTAssertEqual(KeycodeNames.name(for: 0x12, isModifier: false), "1")
        XCTAssertEqual(KeycodeNames.name(for: 0x19, isModifier: false), "9")
    }

    func testFunctionKeys() {
        XCTAssertEqual(KeycodeNames.name(for: 0x7A, isModifier: false), "F1")
        XCTAssertEqual(KeycodeNames.name(for: 0x6F, isModifier: false), "F12")
        XCTAssertEqual(KeycodeNames.name(for: 0x71, isModifier: false), "F15")
    }

    func testSpecialKeys() {
        XCTAssertEqual(KeycodeNames.name(for: 0x31, isModifier: false), "Space")
        XCTAssertEqual(KeycodeNames.name(for: 0x24, isModifier: false), "Return")
        XCTAssertEqual(KeycodeNames.name(for: 0x30, isModifier: false), "Tab")
        XCTAssertEqual(KeycodeNames.name(for: 0x33, isModifier: false), "Delete")
        XCTAssertEqual(KeycodeNames.name(for: 0x75, isModifier: false), "Forward Delete")
    }

    func testNavigationKeys() {
        XCTAssertEqual(KeycodeNames.name(for: 0x7E, isModifier: false), "Up Arrow")
        XCTAssertEqual(KeycodeNames.name(for: 0x7D, isModifier: false), "Down Arrow")
        XCTAssertEqual(KeycodeNames.name(for: 0x7B, isModifier: false), "Left Arrow")
        XCTAssertEqual(KeycodeNames.name(for: 0x7C, isModifier: false), "Right Arrow")
        XCTAssertEqual(KeycodeNames.name(for: 0x73, isModifier: false), "Home")
        XCTAssertEqual(KeycodeNames.name(for: 0x77, isModifier: false), "End")
        XCTAssertEqual(KeycodeNames.name(for: 0x74, isModifier: false), "Page Up")
        XCTAssertEqual(KeycodeNames.name(for: 0x79, isModifier: false), "Page Down")
    }

    func testSymbolKeys() {
        XCTAssertEqual(KeycodeNames.name(for: 0x1B, isModifier: false), "-")
        XCTAssertEqual(KeycodeNames.name(for: 0x18, isModifier: false), "=")
        XCTAssertEqual(KeycodeNames.name(for: 0x32, isModifier: false), "`")
    }

    func testUnknownKeyFallback() {
        XCTAssertEqual(KeycodeNames.name(for: 0xFE, isModifier: false), "Key 254")
    }

    // MARK: - isModifier flag routes correctly

    func testModifierKeycodeWithIsModifierFalseUsesKeyTable() {
        // 0x37 is Left Command as a modifier, but as a regular key it's unknown
        let result = KeycodeNames.name(for: 0x37, isModifier: false)
        XCTAssertEqual(result, "Key 55")
    }

    func testRegularKeycodeWithIsModifierTrueUsesFallback() {
        // 0x00 (A) isn't in the modifier table
        let result = KeycodeNames.name(for: 0x00, isModifier: true)
        XCTAssertEqual(result, "Modifier 0")
    }
}

// MARK: - ModifierFlagIsSet tests

final class ModifierFlagIsSetTests: XCTestCase {

    private var manager: HotkeyManager!

    override func setUp() {
        super.setUp()
        manager = HotkeyManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    func testCommandKeycodes() {
        let withCommand = CGEventFlags.maskCommand
        let empty = CGEventFlags()

        // Left Command (0x37)
        XCTAssertTrue(manager.modifierFlagIsSet(for: 0x37, flags: withCommand))
        XCTAssertFalse(manager.modifierFlagIsSet(for: 0x37, flags: empty))

        // Right Command (0x36)
        XCTAssertTrue(manager.modifierFlagIsSet(for: 0x36, flags: withCommand))
        XCTAssertFalse(manager.modifierFlagIsSet(for: 0x36, flags: empty))
    }

    func testOptionKeycodes() {
        let withOption = CGEventFlags.maskAlternate
        let empty = CGEventFlags()

        XCTAssertTrue(manager.modifierFlagIsSet(for: 0x3A, flags: withOption))
        XCTAssertFalse(manager.modifierFlagIsSet(for: 0x3A, flags: empty))
        XCTAssertTrue(manager.modifierFlagIsSet(for: 0x3D, flags: withOption))
    }

    func testShiftKeycodes() {
        let withShift = CGEventFlags.maskShift
        let empty = CGEventFlags()

        XCTAssertTrue(manager.modifierFlagIsSet(for: 0x38, flags: withShift))
        XCTAssertFalse(manager.modifierFlagIsSet(for: 0x38, flags: empty))
        XCTAssertTrue(manager.modifierFlagIsSet(for: 0x3C, flags: withShift))
    }

    func testControlKeycodes() {
        let withControl = CGEventFlags.maskControl
        let empty = CGEventFlags()

        XCTAssertTrue(manager.modifierFlagIsSet(for: 0x3B, flags: withControl))
        XCTAssertFalse(manager.modifierFlagIsSet(for: 0x3B, flags: empty))
        XCTAssertTrue(manager.modifierFlagIsSet(for: 0x3E, flags: withControl))
    }

    func testFnKeycode() {
        let withFn = CGEventFlags.maskSecondaryFn
        let empty = CGEventFlags()

        XCTAssertTrue(manager.modifierFlagIsSet(for: 0x3F, flags: withFn))
        XCTAssertFalse(manager.modifierFlagIsSet(for: 0x3F, flags: empty))
    }

    func testUnknownKeycodeReturnsFalse() {
        let allFlags: CGEventFlags = [.maskCommand, .maskAlternate, .maskShift, .maskControl, .maskSecondaryFn]
        XCTAssertFalse(manager.modifierFlagIsSet(for: 0xFF, flags: allFlags))
    }

    func testWrongFlagForKeycode() {
        // Shift keycode but command flag
        XCTAssertFalse(manager.modifierFlagIsSet(for: 0x38, flags: .maskCommand))
        // Command keycode but shift flag
        XCTAssertFalse(manager.modifierFlagIsSet(for: 0x37, flags: .maskShift))
    }
}

// MARK: - Custom keycode UserDefaults tests

final class CustomKeycodeStorageTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: "customHotkeyKeycode")
        UserDefaults.standard.removeObject(forKey: "customHotkeyIsModifier")
        UserDefaults.standard.removeObject(forKey: "customHotkeyName")
    }

    func testSavedCustomKeycodeDefaultsToNil() {
        UserDefaults.standard.removeObject(forKey: "customHotkeyKeycode")
        XCTAssertNil(HotkeyOption.savedCustomKeycode)
    }

    func testSavedCustomKeycodeRoundTrips() {
        HotkeyOption.savedCustomKeycode = 0x37
        XCTAssertEqual(HotkeyOption.savedCustomKeycode, 0x37)

        HotkeyOption.savedCustomKeycode = 0x00
        XCTAssertEqual(HotkeyOption.savedCustomKeycode, 0x00)
    }

    func testSavedCustomKeycodeSetNilClearsStorage() {
        HotkeyOption.savedCustomKeycode = 0x37
        XCTAssertNotNil(HotkeyOption.savedCustomKeycode)

        HotkeyOption.savedCustomKeycode = nil
        XCTAssertNil(HotkeyOption.savedCustomKeycode)
    }

    func testSavedCustomKeyIsModifierRoundTrips() {
        HotkeyOption.savedCustomKeyIsModifier = true
        XCTAssertTrue(HotkeyOption.savedCustomKeyIsModifier)

        HotkeyOption.savedCustomKeyIsModifier = false
        XCTAssertFalse(HotkeyOption.savedCustomKeyIsModifier)
    }

    func testSavedCustomKeyNameRoundTrips() {
        HotkeyOption.savedCustomKeyName = "Left Command"
        XCTAssertEqual(HotkeyOption.savedCustomKeyName, "Left Command")
    }

    func testSavedCustomKeyNameDefaultsToEmpty() {
        UserDefaults.standard.removeObject(forKey: "customHotkeyName")
        XCTAssertEqual(HotkeyOption.savedCustomKeyName, "")
    }

    func testCustomKeyNameShowsInHotkeyKeyName() {
        HotkeyOption.savedCustomKeyName = "Right Shift"
        XCTAssertEqual(HotkeyOption.custom.keyName, "Right Shift")
    }

    func testCustomKeyNameFallbackWhenEmpty() {
        HotkeyOption.savedCustomKeyName = ""
        XCTAssertEqual(HotkeyOption.custom.keyName, "Custom Key")
    }
}
