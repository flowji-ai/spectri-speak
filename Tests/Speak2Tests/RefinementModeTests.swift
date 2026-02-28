import XCTest
@testable import Speak2

final class RefinementModeTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: "refinementMode")
        UserDefaults.standard.removeObject(forKey: "ollamaEnabled")
    }

    // MARK: - Round-trip Persistence

    func testRefinementModeSavedRoundTrips() {
        for mode in RefinementMode.allCases {
            RefinementMode.saved = mode
            XCTAssertEqual(RefinementMode.saved, mode, "Round-trip failed for \(mode.rawValue)")
        }
    }

    func testRefinementModeDefaultsToOff() {
        UserDefaults.standard.removeObject(forKey: "refinementMode")
        UserDefaults.standard.removeObject(forKey: "ollamaEnabled")
        XCTAssertEqual(RefinementMode.saved, .off)
    }

    // MARK: - Migration from ollamaEnabled

    func testMigrationFromOllamaEnabled() {
        UserDefaults.standard.removeObject(forKey: "refinementMode")
        UserDefaults.standard.set(true, forKey: "ollamaEnabled")

        XCTAssertEqual(RefinementMode.saved, .external)
        // Verify the new key was written
        XCTAssertEqual(UserDefaults.standard.string(forKey: "refinementMode"), "external")
    }

    func testNoMigrationWhenOllamaDisabled() {
        UserDefaults.standard.removeObject(forKey: "refinementMode")
        UserDefaults.standard.set(false, forKey: "ollamaEnabled")

        XCTAssertEqual(RefinementMode.saved, .off)
    }

    func testNoMigrationWhenRefinementModeAlreadySet() {
        RefinementMode.saved = .builtIn
        UserDefaults.standard.set(true, forKey: "ollamaEnabled")

        // Should use the explicit setting, not migrate
        XCTAssertEqual(RefinementMode.saved, .builtIn)
    }

    // MARK: - Display Names

    func testAllModesHaveNonEmptyDisplayNames() {
        for mode in RefinementMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty, "\(mode.rawValue) should have a display name")
        }
    }

    func testAllCasesCount() {
        XCTAssertEqual(RefinementMode.allCases.count, 3)
    }

    // MARK: - MLXRefinerError

    func testMLXRefinerErrorDescription() {
        let error = MLXRefinerError.modelNotLoaded
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("model"), "Error should mention model")
    }

    // MARK: - MLXRefiner Initial State

    func testMLXRefinerStartsUnloaded() async {
        let refiner = MLXRefiner()
        let loaded = await refiner.isModelLoaded
        XCTAssertFalse(loaded)
    }

    func testMLXRefinerRefineThrowsWhenNotLoaded() async {
        let refiner = MLXRefiner()
        do {
            _ = try await refiner.refine(text: "test")
            XCTFail("Expected refine to throw when model not loaded")
        } catch {
            XCTAssertEqual(error as? MLXRefinerError, .modelNotLoaded)
        }
    }
}
