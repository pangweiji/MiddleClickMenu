import Foundation
@testable import MiddleClickMenuLib

final class TestContext: @unchecked Sendable {
    var passed = 0
    var failed = 0

    func expect(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
        if condition {
            passed += 1
        } else {
            failed += 1
            print("  FAIL: \(message) (\(file):\(line))")
        }
    }

    func test(_ name: String, _ body: () throws -> Void) {
        print("▶ \(name)")
        do {
            try body()
        } catch {
            failed += 1
            print("  FAIL: threw \(error)")
        }
    }
}

nonisolated(unsafe) let ctx = TestContext()

func expect(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    ctx.expect(condition, message, file: file, line: line)
}

func test(_ name: String, _ body: () throws -> Void) {
    ctx.test(name, body)
}

@main
struct TestRunner {
    static func main() {
        print("Running MiddleClickMenu Tests...\n")

        ConfigStoreTests.runAll()
        TimestampActionTests.runAll()
        ShellActionTests.runAll()
        ActionRunnerTests.runAll()

        print("\n\(ctx.passed + ctx.failed) tests, \(ctx.passed) passed, \(ctx.failed) failed")
        if ctx.failed > 0 { exit(1) }
    }
}
