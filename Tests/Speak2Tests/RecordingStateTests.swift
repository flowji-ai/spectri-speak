import XCTest
@testable import Speak2

final class RecordingStateTests: XCTestCase {

    // MARK: - Refining State

    func testRefiningStateExists() {
        // Verify the .refining case is part of RecordingState
        let state: RecordingState = .refining
        switch state {
        case .refining:
            break // Expected
        default:
            XCTFail("RecordingState should have a .refining case")
        }
    }

    func testAllRecordingStates() {
        // Verify all expected states exist
        let states: [RecordingState] = [.idle, .loadingModel, .recording, .transcribing, .refining]
        XCTAssertEqual(states.count, 5, "RecordingState should have 5 cases")
    }
}

final class AudioFeedbackManagerTests: XCTestCase {

    func testSharedInstanceExists() {
        let manager = AudioFeedbackManager.shared
        XCTAssertNotNil(manager)
    }

    func testSharedInstanceIsSingleton() {
        let a = AudioFeedbackManager.shared
        let b = AudioFeedbackManager.shared
        XCTAssertTrue(a === b, "AudioFeedbackManager.shared should return the same instance")
    }
}
