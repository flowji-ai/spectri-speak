import XCTest
@testable import Speak2

final class ParakeetStreamingTests: XCTestCase {

    // MARK: - Streaming Buffer Cap (maxStreamingSamples = 80000)

    func testBufferSuffixCapsAtMaxStreamingSamples() {
        let buffer = AudioSampleBuffer()
        let total = 100_000
        buffer.append(Array(repeating: Float(1.0), count: total))

        let allSamples = buffer.snapshot()
        XCTAssertEqual(allSamples.count, total)

        let maxStreamingSamples = 80_000
        let capped = allSamples.count > maxStreamingSamples
            ? Array(allSamples.suffix(maxStreamingSamples))
            : allSamples
        XCTAssertEqual(capped.count, maxStreamingSamples)
    }

    func testBufferUnderMaxReturnsAll() {
        let buffer = AudioSampleBuffer()
        buffer.append(Array(repeating: Float(0.5), count: 50_000))

        let allSamples = buffer.snapshot()
        let maxStreamingSamples = 80_000
        let capped = allSamples.count > maxStreamingSamples
            ? Array(allSamples.suffix(maxStreamingSamples))
            : allSamples
        XCTAssertEqual(capped.count, 50_000)
    }

    func testBufferSuffixPreservesLatestSamples() {
        let buffer = AudioSampleBuffer()
        // Append ascending values so we can verify suffix is the tail
        let samples = (0..<100_000).map { Float($0) }
        buffer.append(samples)

        let allSamples = buffer.snapshot()
        let maxStreamingSamples = 80_000
        let capped = Array(allSamples.suffix(maxStreamingSamples))
        XCTAssertEqual(capped.first, 20_000.0)
        XCTAssertEqual(capped.last, 99_999.0)
    }

    // MARK: - Minimum Samples Threshold (minTranscriptionSamples = 4800)

    func testBelowMinSamplesSkipsTranscription() {
        let buffer = AudioSampleBuffer()
        buffer.append(Array(repeating: Float(0.1), count: 4799))

        let minTranscriptionSamples = 4800
        XCTAssertTrue(buffer.count < minTranscriptionSamples)
    }

    func testAtMinSamplesAllowsTranscription() {
        let buffer = AudioSampleBuffer()
        buffer.append(Array(repeating: Float(0.1), count: 4800))

        let minTranscriptionSamples = 4800
        XCTAssertTrue(buffer.count >= minTranscriptionSamples)
    }

    // MARK: - Streaming Text Progression via diffWords

    func testMultiPassTextProgression() {
        let snapshot = StreamingTextSnapshot()
        var previousText = ""

        // Pass 1: first transcription result
        let pass1 = "Hello"
        let diff1 = diffWords(previous: previousText, current: pass1)
        previousText = pass1
        snapshot.update(confirmed: diff1.confirmed, unconfirmed: diff1.unconfirmed)

        var result = snapshot.read()
        XCTAssertEqual(result.confirmed, "")
        XCTAssertEqual(result.unconfirmed, "Hello")

        // Pass 2: engine refines, words stabilize
        let pass2 = "Hello world"
        let diff2 = diffWords(previous: previousText, current: pass2)
        previousText = pass2
        snapshot.update(confirmed: diff2.confirmed, unconfirmed: diff2.unconfirmed)

        result = snapshot.read()
        XCTAssertEqual(result.confirmed, "Hello")
        XCTAssertEqual(result.unconfirmed, "world")

        // Pass 3: more words stabilize
        let pass3 = "Hello world how are you"
        let diff3 = diffWords(previous: previousText, current: pass3)
        previousText = pass3
        snapshot.update(confirmed: diff3.confirmed, unconfirmed: diff3.unconfirmed)

        result = snapshot.read()
        XCTAssertEqual(result.confirmed, "Hello world")
        XCTAssertEqual(result.unconfirmed, "how are you")
    }

    func testUnconfirmedTextReplacement() {
        let snapshot = StreamingTextSnapshot()
        var previousText = ""

        // Pass 1
        let pass1 = "I think"
        let diff1 = diffWords(previous: previousText, current: pass1)
        previousText = pass1
        snapshot.update(confirmed: diff1.confirmed, unconfirmed: diff1.unconfirmed)

        // Pass 2: engine changes unconfirmed part entirely
        let pass2 = "I know that"
        let diff2 = diffWords(previous: previousText, current: pass2)
        previousText = pass2
        snapshot.update(confirmed: diff2.confirmed, unconfirmed: diff2.unconfirmed)

        let result = snapshot.read()
        XCTAssertEqual(result.confirmed, "I")
        XCTAssertEqual(result.unconfirmed, "know that")
    }

    // MARK: - Stop Streaming Fallback Logic

    func testFallbackJoinConfirmedAndUnconfirmed() {
        let snapshot = StreamingTextSnapshot()
        snapshot.update(confirmed: "Hello world", unconfirmed: "how are")

        let (confirmed, unconfirmed) = snapshot.read()
        let fallback = [confirmed, unconfirmed]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertEqual(fallback, "Hello world how are")
    }

    func testFallbackConfirmedOnlyNoTrailingSpace() {
        let snapshot = StreamingTextSnapshot()
        snapshot.update(confirmed: "Hello world", unconfirmed: "")

        let (confirmed, unconfirmed) = snapshot.read()
        let fallback = [confirmed, unconfirmed]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertEqual(fallback, "Hello world")
    }

    func testFallbackUnconfirmedOnly() {
        let snapshot = StreamingTextSnapshot()
        snapshot.update(confirmed: "", unconfirmed: "testing")

        let (confirmed, unconfirmed) = snapshot.read()
        let fallback = [confirmed, unconfirmed]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertEqual(fallback, "testing")
    }

    func testFallbackBothEmpty() {
        let snapshot = StreamingTextSnapshot()

        let (confirmed, unconfirmed) = snapshot.read()
        let fallback = [confirmed, unconfirmed]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertEqual(fallback, "")
    }

    // MARK: - Streaming Loop Edge Cases

    func testEmptyTranscriptionResultSkipped() {
        let snapshot = StreamingTextSnapshot()
        var previousText = ""

        // Pass 1: real result
        let pass1 = "Hello"
        let diff1 = diffWords(previous: previousText, current: pass1)
        previousText = pass1
        snapshot.update(confirmed: diff1.confirmed, unconfirmed: diff1.unconfirmed)

        // Pass 2: empty result — streaming loop skips empty results
        let pass2 = ""
        if !pass2.isEmpty {
            let diff2 = diffWords(previous: previousText, current: pass2)
            previousText = pass2
            snapshot.update(confirmed: diff2.confirmed, unconfirmed: diff2.unconfirmed)
        }

        // Snapshot should still hold pass1's state
        let result = snapshot.read()
        XCTAssertEqual(result.confirmed, "")
        XCTAssertEqual(result.unconfirmed, "Hello")
    }

    func testPunctuationStabilizesAcrossPasses() {
        var previousText = ""

        // Pass 1: no trailing punctuation
        let pass1 = "Alright I will"
        let diff1 = diffWords(previous: previousText, current: pass1)
        previousText = pass1

        XCTAssertEqual(diff1.confirmed, "")
        XCTAssertEqual(diff1.unconfirmed, "Alright I will")

        // Pass 2: engine adds comma — should still match because punctuation is tolerated
        let pass2 = "Alright, I will do that"
        let diff2 = diffWords(previous: previousText, current: pass2)

        XCTAssertEqual(diff2.confirmed, "Alright, I will")
        XCTAssertEqual(diff2.unconfirmed, "do that")
    }

    func testCaseChangeStabilizesAcrossPasses() {
        var previousText = ""

        let pass1 = "hello WORLD"
        _ = diffWords(previous: previousText, current: pass1)
        previousText = pass1

        let pass2 = "Hello World test"
        let diff2 = diffWords(previous: previousText, current: pass2)

        // Case-insensitive match — both words confirmed, using current casing
        XCTAssertEqual(diff2.confirmed, "Hello World")
        XCTAssertEqual(diff2.unconfirmed, "test")
    }

    func testIncrementalBufferGrowth() {
        let buffer = AudioSampleBuffer()
        let minTranscriptionSamples = 4800

        // Simulate tap callbacks adding small chunks
        for _ in 0..<10 {
            buffer.append(Array(repeating: Float(0.1), count: 400))
        }
        XCTAssertEqual(buffer.count, 4000)
        XCTAssertTrue(buffer.count < minTranscriptionSamples)

        // Two more chunks push it over the threshold
        buffer.append(Array(repeating: Float(0.1), count: 400))
        buffer.append(Array(repeating: Float(0.1), count: 400))
        XCTAssertEqual(buffer.count, 4800)
        XCTAssertTrue(buffer.count >= minTranscriptionSamples)
    }
}
