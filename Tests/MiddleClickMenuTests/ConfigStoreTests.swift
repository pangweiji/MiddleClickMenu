import Testing
import Foundation
@testable import MiddleClickMenu

@Suite("ConfigStore Tests")
struct ConfigStoreTests {
    let tempDir: URL
    let store: ConfigStore

    init() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = ConfigStore(directory: tempDir)
    }

    @Test("Default config has expected values")
    func defaultConfig() {
        let config = store.config
        #expect(config.menuStyle == .list)
        #expect(config.launchAtLogin == false)
        #expect(config.blacklistApps.isEmpty)
        #expect(config.toastDuration == 2.0)
    }

    @Test("Save and load config persists changes")
    func saveAndLoadConfig() throws {
        var config = store.config
        config.menuStyle = .pie
        config.launchAtLogin = true
        config.blacklistApps = ["com.blender.Blender"]
        store.config = config
        store.save()

        let newStore = ConfigStore(directory: tempDir)
        #expect(newStore.config.menuStyle == .pie)
        #expect(newStore.config.launchAtLogin == true)
        #expect(newStore.config.blacklistApps == ["com.blender.Blender"])

        try FileManager.default.removeItem(at: tempDir)
    }

    @Test("Default actions contain timestamp-convert")
    func defaultActions() {
        let actions = store.actionConfigs
        #expect(actions.count == 1)
        #expect(actions[0].id == "timestamp-convert")
        #expect(actions[0].type == .builtin)
        #expect(actions[0].enabled == true)
    }

    @Test("Save and load actions persists new entries")
    func saveAndLoadActions() throws {
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
        #expect(newStore.actionConfigs.count == 2)
        #expect(newStore.actionConfigs[1].id == "google-search")
        #expect(newStore.actionConfigs[1].command == "open \"https://www.google.com/search?q=$INPUT\"")

        try FileManager.default.removeItem(at: tempDir)
    }
}
