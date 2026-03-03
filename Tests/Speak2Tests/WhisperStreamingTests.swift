import XCTest
@testable import Speak2

final class WhisperStreamingTests: XCTestCase {

    // MARK: - AudioSampleBuffer Tests

    func testAppendAndSnapshot() {
        let buffer = AudioSampleBuffer()
        buffer.append([1.0, 2.0, 3.0])
        let snap = buffer.snapshot()
        XCTAssertEqual(snap, [1.0, 2.0, 3.0])
    }

    func testCount() {
        let buffer = AudioSampleBuffer()
        buffer.append([1.0, 2.0, 3.0, 4.0, 5.0])
        XCTAssertEqual(buffer.count, 5)
    }

    func testReset() {
        let buffer = AudioSampleBuffer()
        buffer.append([1.0, 2.0, 3.0])
        buffer.reset()
        XCTAssertEqual(buffer.count, 0)
        XCTAssertEqual(buffer.snapshot(), [])
    }

    func testMultipleAppends() {
        let buffer = AudioSampleBuffer()
        buffer.append([1.0, 2.0])
        buffer.append([3.0, 4.0])
        buffer.append([5.0])
        XCTAssertEqual(buffer.snapshot(), [1.0, 2.0, 3.0, 4.0, 5.0])
    }

    func testSnapshotIsACopy() {
        let buffer = AudioSampleBuffer()
        buffer.append([1.0, 2.0, 3.0])
        var snap = buffer.snapshot()
        snap[0] = 99.0
        // Original buffer should be unaffected
        XCTAssertEqual(buffer.snapshot(), [1.0, 2.0, 3.0])
    }

    // MARK: - StreamingTextSnapshot Tests

    func testUpdateAndRead() {
        let snapshot = StreamingTextSnapshot()
        snapshot.update(confirmed: "Hello", unconfirmed: "world")
        let result = snapshot.read()
        XCTAssertEqual(result.confirmed, "Hello")
        XCTAssertEqual(result.unconfirmed, "world")
    }

    func testStreamingTextSnapshotReset() {
        let snapshot = StreamingTextSnapshot()
        snapshot.update(confirmed: "Hello", unconfirmed: "world")
        snapshot.reset()
        let result = snapshot.read()
        XCTAssertEqual(result.confirmed, "")
        XCTAssertEqual(result.unconfirmed, "")
    }

    func testInitialState() {
        let snapshot = StreamingTextSnapshot()
        let result = snapshot.read()
        XCTAssertEqual(result.confirmed, "")
        XCTAssertEqual(result.unconfirmed, "")
    }

    // MARK: - diffWords Tests

    func testEmptyPrevious() {
        let result = WhisperTranscriber.diffWords(previous: "", current: "Hello world")
        XCTAssertEqual(result.confirmed, "")
        XCTAssertEqual(result.unconfirmed, "Hello world")
    }

    func testIdenticalText() {
        let result = WhisperTranscriber.diffWords(previous: "Hello world", current: "Hello world")
        XCTAssertEqual(result.confirmed, "Hello world")
        XCTAssertEqual(result.unconfirmed, "")
    }

    func testCommonPrefix() {
        let result = WhisperTranscriber.diffWords(previous: "Hello world", current: "Hello there")
        XCTAssertEqual(result.confirmed, "Hello")
        XCTAssertEqual(result.unconfirmed, "there")
    }

    func testCompletelyDifferent() {
        let result = WhisperTranscriber.diffWords(previous: "Hello", current: "Goodbye")
        XCTAssertEqual(result.confirmed, "")
        XCTAssertEqual(result.unconfirmed, "Goodbye")
    }

    func testCaseInsensitive() {
        let result = WhisperTranscriber.diffWords(previous: "hello World", current: "Hello WORLD")
        XCTAssertEqual(result.confirmed, "Hello WORLD")
        XCTAssertEqual(result.unconfirmed, "")
    }

    func testPunctuationTolerance() {
        let result = WhisperTranscriber.diffWords(previous: "Alright", current: "Alright, I am")
        XCTAssertEqual(result.confirmed, "Alright,")
        XCTAssertEqual(result.unconfirmed, "I am")
    }

    func testTrailingPunctuationVariation() {
        let result = WhisperTranscriber.diffWords(previous: "Hello world.", current: "Hello world, how")
        XCTAssertEqual(result.confirmed, "Hello world,")
        XCTAssertEqual(result.unconfirmed, "how")
    }

    func testEmptyCurrent() {
        let result = WhisperTranscriber.diffWords(previous: "Hello", current: "")
        XCTAssertEqual(result.confirmed, "")
        XCTAssertEqual(result.unconfirmed, "")
    }

    func testBothEmpty() {
        let result = WhisperTranscriber.diffWords(previous: "", current: "")
        XCTAssertEqual(result.confirmed, "")
        XCTAssertEqual(result.unconfirmed, "")
    }

    func testLongerPrevious() {
        let result = WhisperTranscriber.diffWords(previous: "Hello world how are you", current: "Hello world")
        XCTAssertEqual(result.confirmed, "Hello world")
        XCTAssertEqual(result.unconfirmed, "")
    }

    // MARK: - normalizeForComparison Tests

    func testBasicNormalization() {
        XCTAssertEqual(WhisperTranscriber.normalizeForComparison("Hello"), "hello")
    }

    func testPunctuationStripping() {
        XCTAssertEqual(WhisperTranscriber.normalizeForComparison("Hello,"), "hello")
        XCTAssertEqual(WhisperTranscriber.normalizeForComparison("world."), "world")
        XCTAssertEqual(WhisperTranscriber.normalizeForComparison("test?!"), "test")
    }

    func testNoPunctuation() {
        XCTAssertEqual(WhisperTranscriber.normalizeForComparison("hello"), "hello")
    }

    func testOnlyPunctuation() {
        XCTAssertEqual(WhisperTranscriber.normalizeForComparison("..."), "")
    }
}
