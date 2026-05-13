import Foundation
@testable import MiddleClickMenuLib

enum ActionRunnerTests {
    static func runAll() {
        testLoadBuiltinActions()
        testIsActionEnabledRequiresTextNil()
        testIsActionEnabledRequiresTextProvided()
    }

    static func testLoadBuiltinActions() {
        test("ActionRunner loads builtin actions from default config") {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let store = ConfigStore(directory: tempDir)
            let runner = ActionRunner(configStore: store)
            let actions = runner.availableActions(selectedText: nil)

            expect(actions.count == 1, "should have 1 action")
            expect(actions[0].id == "timestamp-convert", "action id should be timestamp-convert")
        }
    }

    static func testIsActionEnabledRequiresTextNil() {
        test("isActionEnabled returns false when requiresText but no text") {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let store = ConfigStore(directory: tempDir)
            let runner = ActionRunner(configStore: store)
            let actions = runner.availableActions(selectedText: nil)

            let timestampAction = actions[0]
            expect(timestampAction.requiresText == true, "timestamp action should require text")
            expect(runner.isActionEnabled(timestampAction, selectedText: nil) == false, "should be disabled when selectedText is nil")
            expect(runner.isActionEnabled(timestampAction, selectedText: "") == false, "should be disabled when selectedText is empty")
        }
    }

    static func testIsActionEnabledRequiresTextProvided() {
        test("isActionEnabled returns true when requiresText and text provided") {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let store = ConfigStore(directory: tempDir)
            let runner = ActionRunner(configStore: store)
            let actions = runner.availableActions(selectedText: "1700000000")

            let timestampAction = actions[0]
            expect(runner.isActionEnabled(timestampAction, selectedText: "1700000000") == true, "should be enabled when text is provided")
        }
    }
}
