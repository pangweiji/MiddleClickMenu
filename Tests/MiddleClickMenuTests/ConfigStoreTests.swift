import Foundation
@testable import MiddleClickMenuLib

enum ConfigStoreTests {
    static func runAll() {
        testDefaultConfig()
        testSaveAndLoadConfig()
        testDefaultActions()
        testSaveAndLoadActions()
    }

    static func testDefaultConfig() {
        test("Default config has expected values") {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let store = ConfigStore(directory: tempDir)
            expect(store.config.menuStyle == .list, "menuStyle should be .list")
            expect(store.config.launchAtLogin == false, "launchAtLogin should be false")
            expect(store.config.blacklistApps.isEmpty, "blacklistApps should be empty")
            expect(store.config.toastDuration == 2.0, "toastDuration should be 2.0")
        }
    }

    static func testSaveAndLoadConfig() {
        test("Save and load config persists changes") {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let store = ConfigStore(directory: tempDir)
            var config = store.config
            config.menuStyle = .pie
            config.launchAtLogin = true
            config.blacklistApps = ["com.blender.Blender"]
            store.config = config
            store.save()

            let newStore = ConfigStore(directory: tempDir)
            expect(newStore.config.menuStyle == .pie, "menuStyle should be .pie")
            expect(newStore.config.launchAtLogin == true, "launchAtLogin should be true")
            expect(newStore.config.blacklistApps == ["com.blender.Blender"], "blacklistApps should match")
        }
    }

    static func testDefaultActions() {
        test("Default actions contain timestamp-convert") {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let store = ConfigStore(directory: tempDir)
            expect(store.actionConfigs.count == 1, "should have 1 default action")
            expect(store.actionConfigs[0].id == "timestamp-convert", "id should be timestamp-convert")
            expect(store.actionConfigs[0].type == .builtin, "type should be .builtin")
            expect(store.actionConfigs[0].enabled == true, "should be enabled")
        }
    }

    static func testSaveAndLoadActions() {
        test("Save and load actions persists new entries") {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let store = ConfigStore(directory: tempDir)
            var actions = store.actionConfigs
            actions.append(ActionConfig(
                id: "google-search",
                type: .shell,
                name: "Google 搜索",
                icon: "magnifyingglass",
                command: "open \"https://www.google.com/search?q=$INPUT\"",
                requiresText: true,
                enabled: true,
                order: 1
            ))
            store.actionConfigs = actions
            store.save()

            let newStore = ConfigStore(directory: tempDir)
            expect(newStore.actionConfigs.count == 2, "should have 2 actions")
            expect(newStore.actionConfigs[1].id == "google-search", "second action id should be google-search")
            expect(newStore.actionConfigs[1].command == "open \"https://www.google.com/search?q=$INPUT\"", "command should match")
        }
    }
}
