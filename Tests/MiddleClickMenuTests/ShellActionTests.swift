import Foundation
@testable import MiddleClickMenuLib

func shellRunAsync<T>(_ block: @escaping @Sendable () async -> T) -> T {
    let semaphore = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var result: T!
    Task {
        result = await block()
        semaphore.signal()
    }
    semaphore.wait()
    return result
}

enum ShellActionTests {
    static func runAll() {
        print("ShellActionTests")
        testEchoCommand()
        testInputSubstitution()
        testFailingCommand()
        testEmptyOutput()
    }

    static func testEchoCommand() {
        test("echo command returns .text") {
            let action = ShellAction(
                id: "test-echo", name: "Echo", icon: "terminal",
                requiresText: false, command: "echo hello"
            )
            let result = shellRunAsync { await action.run(input: nil) }
            expect(result == .text("hello"), "should return .text(\"hello\"), got \(result)")
        }
    }

    static func testInputSubstitution() {
        test("$INPUT substitution works") {
            let action = ShellAction(
                id: "test-input", name: "Upper", icon: "terminal",
                requiresText: true, command: "echo $INPUT"
            )
            let result = shellRunAsync { await action.run(input: "world") }
            expect(result == .text("world"), "should substitute $INPUT, got \(result)")
        }
    }

    static func testFailingCommand() {
        test("failing command returns .error") {
            let action = ShellAction(
                id: "test-fail", name: "Fail", icon: "terminal",
                requiresText: false, command: "exit 1"
            )
            let result = shellRunAsync { await action.run(input: nil) }
            if case .error = result {
                expect(true, "should be error")
            } else {
                expect(false, "should return .error, got \(result)")
            }
        }
    }

    static func testEmptyOutput() {
        test("empty output returns .silent") {
            let action = ShellAction(
                id: "test-silent", name: "Silent", icon: "terminal",
                requiresText: false, command: "true"
            )
            let result = shellRunAsync { await action.run(input: nil) }
            expect(result == .silent, "should return .silent, got \(result)")
        }
    }
}
