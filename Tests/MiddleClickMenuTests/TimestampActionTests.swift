import Foundation
@testable import MiddleClickMenuLib

func runAsync<T>(_ block: @escaping @Sendable () async -> T) -> T {
    let semaphore = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var result: T!
    Task {
        result = await block()
        semaphore.signal()
    }
    semaphore.wait()
    return result
}

enum TimestampActionTests {
    static func runAll() {
        print("TimestampActionTests")
        testProperties()
        testUnixSeconds()
        testUnixMilliseconds()
        testInputWithWhitespace()
        testInvalidInput()
        testNilInput()
        testEmptyInput()
    }

    static func testProperties() {
        test("properties are correct") {
            let action = TimestampAction()
            expect(action.id == "timestamp-convert", "id should be timestamp-convert")
            expect(action.icon == "clock", "icon should be clock")
            expect(action.requiresText == true, "requiresText should be true")
        }
    }

    static func testUnixSeconds() {
        test("converts 10-digit unix seconds") {
            let action = TimestampAction()
            let result = runAsync { await action.run(input: "1700000000") }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = .current
            let expected = formatter.string(from: Date(timeIntervalSince1970: 1700000000))
            expect(result == .text(expected), "should convert unix seconds, got \(result)")
        }
    }

    static func testUnixMilliseconds() {
        test("converts 13-digit unix milliseconds") {
            let action = TimestampAction()
            let result = runAsync { await action.run(input: "1700000000000") }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = .current
            let expected = formatter.string(from: Date(timeIntervalSince1970: 1700000000))
            expect(result == .text(expected), "should convert unix milliseconds, got \(result)")
        }
    }

    static func testInputWithWhitespace() {
        test("handles input with whitespace") {
            let action = TimestampAction()
            let result = runAsync { await action.run(input: "  1700000000  ") }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = .current
            let expected = formatter.string(from: Date(timeIntervalSince1970: 1700000000))
            expect(result == .text(expected), "should trim whitespace and convert, got \(result)")
        }
    }

    static func testInvalidInput() {
        test("returns error for invalid input") {
            let action = TimestampAction()
            let result = runAsync { await action.run(input: "not-a-number") }
            expect(result == .error("无法识别的时间戳"), "should return error for invalid input, got \(result)")
        }
    }

    static func testNilInput() {
        test("returns error for nil input") {
            let action = TimestampAction()
            let result = runAsync { await action.run(input: nil) }
            expect(result == .error("没有选中文本"), "should return error for nil input, got \(result)")
        }
    }

    static func testEmptyInput() {
        test("returns error for empty input") {
            let action = TimestampAction()
            let result = runAsync { await action.run(input: "") }
            expect(result == .error("没有选中文本"), "should return error for empty input, got \(result)")
        }
    }
}
