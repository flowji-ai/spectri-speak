import XCTest
@testable import Speak2

final class TranscriptionArtifactTests: XCTestCase {

    func testStripsSquareBracketedArtifacts() {
        XCTAssertEqual(stripTranscriptionArtifacts("[Silence]"), "")
        XCTAssertEqual(stripTranscriptionArtifacts("[BLANK_AUDIO]"), "")
        XCTAssertEqual(stripTranscriptionArtifacts("Hello [Silence] world"), "Hello world")
    }

    func testStripsParenthesizedArtifacts() {
        XCTAssertEqual(stripTranscriptionArtifacts("(Music)"), "")
        XCTAssertEqual(stripTranscriptionArtifacts("Hello (Music) world"), "Hello world")
    }

    func testStripsMultipleArtifacts() {
        XCTAssertEqual(
            stripTranscriptionArtifacts("[Silence] Hello [BLANK_AUDIO] world (Music)"),
            "Hello world"
        )
    }

    func testCollapsesDoubleSpaces() {
        XCTAssertEqual(stripTranscriptionArtifacts("Hello  world"), "Hello world")
        XCTAssertEqual(stripTranscriptionArtifacts("Hello   world"), "Hello world")
    }

    func testTrimsWhitespace() {
        XCTAssertEqual(stripTranscriptionArtifacts("  Hello world  "), "Hello world")
        XCTAssertEqual(stripTranscriptionArtifacts(" [Silence] Hello"), "Hello")
    }

    func testPassesThroughCleanText() {
        XCTAssertEqual(stripTranscriptionArtifacts("Hello world"), "Hello world")
        XCTAssertEqual(stripTranscriptionArtifacts(""), "")
    }

    func testHandlesOnlyArtifacts() {
        XCTAssertEqual(stripTranscriptionArtifacts("[Silence] [BLANK_AUDIO] (Music)"), "")
    }
}
