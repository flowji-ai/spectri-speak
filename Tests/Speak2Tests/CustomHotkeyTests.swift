import XCTest
import CoreGraphics
import AppKit
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

// MARK: - CustomHotkeyCombo tests

final class CustomHotkeyComboTests: XCTestCase {

    func testJSONRoundTrip() throws {
        let combo = CustomHotkeyCombo(
            triggerKeycode: 0x28,
            triggerIsModifier: false,
            requiredModifierFlags: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue,
            displayName: "Cmd + Shift + K"
        )

        let data = try JSONEncoder().encode(combo)
        let decoded = try JSONDecoder().decode(CustomHotkeyCombo.self, from: data)

        XCTAssertEqual(decoded.id, combo.id)
        XCTAssertEqual(decoded.triggerKeycode, 0x28)
        XCTAssertFalse(decoded.triggerIsModifier)
        XCTAssertEqual(decoded.requiredModifierFlags, combo.requiredModifierFlags)
        XCTAssertEqual(decoded.displayName, "Cmd + Shift + K")
    }

    func testJSONRoundTripModifierOnly() throws {
        let combo = CustomHotkeyCombo(
            triggerKeycode: 0x3D,
            triggerIsModifier: true,
            requiredModifierFlags: 0,
            displayName: "Right Option"
        )

        let data = try JSONEncoder().encode(combo)
        let decoded = try JSONDecoder().decode(CustomHotkeyCombo.self, from: data)

        XCTAssertEqual(decoded, combo)
        XCTAssertTrue(decoded.triggerIsModifier)
        XCTAssertEqual(decoded.requiredModifierFlags, 0)
    }

    func testJSONArrayRoundTrip() throws {
        let combos = [
            CustomHotkeyCombo(triggerKeycode: 0x28, triggerIsModifier: false,
                              requiredModifierFlags: CGEventFlags.maskCommand.rawValue,
                              displayName: "Cmd + K"),
            CustomHotkeyCombo(triggerKeycode: 0x3D, triggerIsModifier: true,
                              requiredModifierFlags: 0, displayName: "Right Option"),
        ]

        let data = try JSONEncoder().encode(combos)
        let decoded = try JSONDecoder().decode([CustomHotkeyCombo].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].displayName, "Cmd + K")
        XCTAssertEqual(decoded[1].displayName, "Right Option")
    }

    func testEquality() {
        let id = UUID()
        let a = CustomHotkeyCombo(id: id, triggerKeycode: 0x28, triggerIsModifier: false,
                                  requiredModifierFlags: 0, displayName: "K")
        let b = CustomHotkeyCombo(id: id, triggerKeycode: 0x28, triggerIsModifier: false,
                                  requiredModifierFlags: 0, displayName: "K")
        let c = CustomHotkeyCombo(triggerKeycode: 0x28, triggerIsModifier: false,
                                  requiredModifierFlags: 0, displayName: "K")

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c) // Different UUID
    }

    func testHashable() {
        let combo = CustomHotkeyCombo(triggerKeycode: 0x28, triggerIsModifier: false,
                                      requiredModifierFlags: 0, displayName: "K")
        var set = Set<CustomHotkeyCombo>()
        set.insert(combo)
        set.insert(combo) // Duplicate
        XCTAssertEqual(set.count, 1)
    }
}

// MARK: - Custom combo UserDefaults storage tests

final class CustomComboStorageTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: "customHotkeyCombos")
        UserDefaults.standard.removeObject(forKey: "activeCustomComboId")
    }

    func testSavedCustomCombosDefaultsToEmpty() {
        UserDefaults.standard.removeObject(forKey: "customHotkeyCombos")
        XCTAssertEqual(HotkeyOption.savedCustomCombos.count, 0)
    }

    func testSavedCustomCombosRoundTrips() {
        let combos = [
            CustomHotkeyCombo(triggerKeycode: 0x28, triggerIsModifier: false,
                              requiredModifierFlags: CGEventFlags.maskCommand.rawValue,
                              displayName: "Cmd + K"),
        ]
        HotkeyOption.savedCustomCombos = combos
        let loaded = HotkeyOption.savedCustomCombos
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, combos[0].id)
        XCTAssertEqual(loaded[0].displayName, "Cmd + K")
    }

    func testSavedActiveCustomComboIdDefaultsToNil() {
        UserDefaults.standard.removeObject(forKey: "activeCustomComboId")
        XCTAssertNil(HotkeyOption.savedActiveCustomComboId)
    }

    func testSavedActiveCustomComboIdRoundTrips() {
        let id = UUID()
        HotkeyOption.savedActiveCustomComboId = id
        XCTAssertEqual(HotkeyOption.savedActiveCustomComboId, id)
    }

    func testSavedActiveCustomComboIdSetNilClears() {
        HotkeyOption.savedActiveCustomComboId = UUID()
        HotkeyOption.savedActiveCustomComboId = nil
        XCTAssertNil(HotkeyOption.savedActiveCustomComboId)
    }

    func testActiveCustomComboResolvesFromList() {
        let combo = CustomHotkeyCombo(triggerKeycode: 0x3D, triggerIsModifier: true,
                                      requiredModifierFlags: 0, displayName: "Right Option")
        HotkeyOption.savedCustomCombos = [combo]
        HotkeyOption.savedActiveCustomComboId = combo.id
        XCTAssertEqual(HotkeyOption.activeCustomCombo, combo)
    }

    func testActiveCustomComboReturnsNilWhenIdNotInList() {
        HotkeyOption.savedCustomCombos = []
        HotkeyOption.savedActiveCustomComboId = UUID()
        XCTAssertNil(HotkeyOption.activeCustomCombo)
    }

    func testCustomKeyNameShowsActiveComboDisplayName() {
        let combo = CustomHotkeyCombo(triggerKeycode: 0x28, triggerIsModifier: false,
                                      requiredModifierFlags: CGEventFlags.maskCommand.rawValue,
                                      displayName: "Cmd + K")
        HotkeyOption.savedCustomCombos = [combo]
        HotkeyOption.savedActiveCustomComboId = combo.id
        XCTAssertEqual(HotkeyOption.custom.keyName, "Cmd + K")
    }

    func testCustomKeyNameFallbackWhenNoActiveCombo() {
        HotkeyOption.savedCustomCombos = []
        HotkeyOption.savedActiveCustomComboId = nil
        XCTAssertEqual(HotkeyOption.custom.keyName, "Custom Key")
    }
}

// MARK: - Display name building tests

final class BuildDisplayNameTests: XCTestCase {

    func testKeyOnly() {
        let flags = NSEvent.ModifierFlags()
        XCTAssertEqual(buildDisplayName(modifierFlags: flags, triggerKeycode: 0x28), "K")
    }

    func testCmdKey() {
        let flags = NSEvent.ModifierFlags.command
        XCTAssertEqual(buildDisplayName(modifierFlags: flags, triggerKeycode: 0x28), "Cmd + K")
    }

    func testCmdShiftKey() {
        let flags: NSEvent.ModifierFlags = [.command, .shift]
        XCTAssertEqual(buildDisplayName(modifierFlags: flags, triggerKeycode: 0x28), "Shift + Cmd + K")
    }

    func testAllModifiers() {
        let flags: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        XCTAssertEqual(buildDisplayName(modifierFlags: flags, triggerKeycode: 0x31), "Ctrl + Option + Shift + Cmd + Space")
    }

    func testCtrlOptionSpace() {
        let flags: NSEvent.ModifierFlags = [.control, .option]
        XCTAssertEqual(buildDisplayName(modifierFlags: flags, triggerKeycode: 0x31), "Ctrl + Option + Space")
    }
}

// MARK: - Extract CGEventFlags tests

final class ExtractCGEventModifierFlagsTests: XCTestCase {

    func testNoModifiers() {
        let result = extractCGEventModifierFlags(from: NSEvent.ModifierFlags())
        XCTAssertEqual(result, 0)
    }

    func testCommand() {
        let result = extractCGEventModifierFlags(from: .command)
        XCTAssertEqual(result, CGEventFlags.maskCommand.rawValue)
    }

    func testMultipleModifiers() {
        let flags: NSEvent.ModifierFlags = [.command, .shift]
        let result = extractCGEventModifierFlags(from: flags)
        let expected = CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue
        XCTAssertEqual(result, expected)
    }

    func testAllFourModifiers() {
        let flags: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
        let result = extractCGEventModifierFlags(from: flags)
        let expected = CGEventFlags.maskControl.rawValue | CGEventFlags.maskAlternate.rawValue
            | CGEventFlags.maskShift.rawValue | CGEventFlags.maskCommand.rawValue
        XCTAssertEqual(result, expected)
    }
}
