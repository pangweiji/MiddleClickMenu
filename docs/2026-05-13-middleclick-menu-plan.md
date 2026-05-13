# MiddleClick Menu 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 macOS 菜单栏应用，通过鼠标中键在光标位置弹出快捷菜单，对选中文本执行操作（首个功能：时间戳转换）。

**Architecture:** Swift Package 管理的 macOS App，使用 CGEvent Tap 全局拦截鼠标中键，Accessibility API 获取选中文本，SwiftUI 渲染两种菜单形式（列表/环形），JSON 文件持久化配置。五个核心模块：EventEngine、TextProvider、MenuPresenter、ActionRunner、ConfigStore。

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, CoreGraphics (CGEvent), Accessibility API, macOS 13.0+

---

## 文件结构

```
MiddleClickMenu/
├── MiddleClickMenu/
│   ├── App/
│   │   ├── MiddleClickMenuApp.swift       — SwiftUI App 入口，LSUIElement 配置
│   │   └── AppDelegate.swift              — 初始化 EventEngine，权限检查，菜单栏图标
│   ├── Core/
│   │   ├── EventEngine.swift              — CGEvent Tap 全局鼠标中键拦截
│   │   ├── TextProvider.swift             — AX API 读取选中文本
│   │   └── ActionRunner.swift             — 动作调度与执行
│   ├── Actions/
│   │   ├── MenuAction.swift               — MenuAction 协议 + ActionResult 枚举
│   │   ├── TimestampAction.swift          — 内置：时间戳转换
│   │   ├── ShellAction.swift              — Shell 命令执行
│   │   └── AppleScriptAction.swift        — AppleScript 执行
│   ├── Menu/
│   │   ├── MenuPresenter.swift            — NSPanel 管理，坐标计算，显示/隐藏
│   │   ├── ListMenuView.swift             — SwiftUI 列表菜单
│   │   ├── PieMenuView.swift              — SwiftUI 环形菜单
│   │   └── ToastView.swift                — 结果气泡
│   ├── Settings/
│   │   ├── SettingsView.swift             — 设置主窗口（左右分栏）
│   │   ├── ActionEditorView.swift         — 菜单项编辑表单
│   │   └── BlacklistView.swift            — 黑名单应用管理
│   ├── Storage/
│   │   └── ConfigStore.swift              — JSON 配置读写 + Codable 模型
│   └── Resources/
│       └── Assets.xcassets                — 应用图标
├── MiddleClickMenuTests/
│   ├── TimestampActionTests.swift         — 时间戳转换单元测试
│   ├── ConfigStoreTests.swift             — 配置存储单元测试
│   ├── ShellActionTests.swift             — Shell 动作单元测试
│   └── ActionRunnerTests.swift            — 动作调度单元测试
├── docs/
│   ├── 2026-05-13-middleclick-menu-design.md
│   └── 2026-05-13-middleclick-menu-plan.md
└── README.md
```

---

## Task 1: Xcode 项目脚手架

**Files:**
- Create: `MiddleClickMenu/MiddleClickMenu/App/MiddleClickMenuApp.swift`
- Create: `MiddleClickMenu/MiddleClickMenu/App/AppDelegate.swift`
- Create: `MiddleClickMenu/MiddleClickMenu/Actions/MenuAction.swift`

由于此项目需要 Xcode 工程文件（.xcodeproj），我们使用 Swift Package Manager 创建可执行项目，然后配置为 macOS App。实际上更高效的方式是使用 `xcodebuild` 或手动创建 Package.swift。这里采用 **Swift Package + 可执行目标** 的方式，用命令行即可构建运行，不依赖 Xcode GUI。

- [ ] **Step 1: 初始化 Swift Package**

```bash
cd /Users/ji/MiddleClickMenu
swift package init --type executable --name MiddleClickMenu
```

- [ ] **Step 2: 配置 Package.swift**

将 `Package.swift` 替换为以下内容，声明 macOS 13.0 最低版本和 App 目标：

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MiddleClickMenu",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MiddleClickMenu",
            path: "Sources/MiddleClickMenu",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Sources/MiddleClickMenu/Resources/Info.plist"])
            ]
        ),
        .testTarget(
            name: "MiddleClickMenuTests",
            dependencies: ["MiddleClickMenu"],
            path: "Tests/MiddleClickMenuTests"
        )
    ]
)
```

- [ ] **Step 3: 创建目录结构**

```bash
mkdir -p Sources/MiddleClickMenu/{App,Core,Actions,Menu,Settings,Storage,Resources}
mkdir -p Tests/MiddleClickMenuTests
```

- [ ] **Step 4: 创建 Info.plist**

创建 `Sources/MiddleClickMenu/Resources/Info.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>MiddleClick Menu</string>
    <key>CFBundleIdentifier</key>
    <string>com.middleclickmenu.app</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>MiddleClick Menu 需要辅助功能权限来拦截鼠标中键事件和读取选中文本。</string>
</dict>
</plist>
```

- [ ] **Step 5: 创建 MenuAction 协议**

创建 `Sources/MiddleClickMenu/Actions/MenuAction.swift`：

```swift
import Foundation

enum ActionResult: Equatable {
    case text(String)
    case silent
    case error(String)
}

enum ActionType: String, Codable {
    case builtin
    case shell
    case appleScript
    case shortcut
}

protocol MenuAction {
    var id: String { get }
    var name: String { get }
    var icon: String { get }
    var requiresText: Bool { get }
    func run(input: String?) async -> ActionResult
}
```

- [ ] **Step 6: 创建 App 入口**

创建 `Sources/MiddleClickMenu/App/MiddleClickMenuApp.swift`：

```swift
import SwiftUI

@main
struct MiddleClickMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

创建 `Sources/MiddleClickMenu/App/AppDelegate.swift`：

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarIcon()
    }

    private func setupMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "MiddleClick Menu")
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "关于 MiddleClick Menu", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
}
```

- [ ] **Step 7: 构建验证**

```bash
cd /Users/ji/MiddleClickMenu
swift build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git init
git add Package.swift Sources/ Tests/ docs/
git commit -m "feat: 初始化项目脚手架，App 入口和菜单栏图标"
```

---

## Task 2: ConfigStore — 配置存储

**Files:**
- Create: `Sources/MiddleClickMenu/Storage/ConfigStore.swift`
- Create: `Tests/MiddleClickMenuTests/ConfigStoreTests.swift`

- [ ] **Step 1: 编写 ConfigStore 失败测试**

创建 `Tests/MiddleClickMenuTests/ConfigStoreTests.swift`：

```swift
import XCTest
@testable import MiddleClickMenu

final class ConfigStoreTests: XCTestCase {
    var store: ConfigStore!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = ConfigStore(directory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testDefaultConfig() {
        let config = store.config
        XCTAssertEqual(config.menuStyle, .list)
        XCTAssertFalse(config.launchAtLogin)
        XCTAssertTrue(config.blacklistApps.isEmpty)
        XCTAssertEqual(config.toastDuration, 2.0)
    }

    func testSaveAndLoadConfig() {
        var config = store.config
        config.menuStyle = .pie
        config.launchAtLogin = true
        config.blacklistApps = ["com.blender.Blender"]
        store.config = config
        store.save()

        let newStore = ConfigStore(directory: tempDir)
        XCTAssertEqual(newStore.config.menuStyle, .pie)
        XCTAssertTrue(newStore.config.launchAtLogin)
        XCTAssertEqual(newStore.config.blacklistApps, ["com.blender.Blender"])
    }

    func testDefaultActions() {
        let actions = store.actionConfigs
        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions[0].id, "timestamp-convert")
        XCTAssertEqual(actions[0].type, .builtin)
        XCTAssertTrue(actions[0].enabled)
    }

    func testSaveAndLoadActions() {
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
        XCTAssertEqual(newStore.actionConfigs.count, 2)
        XCTAssertEqual(newStore.actionConfigs[1].id, "google-search")
        XCTAssertEqual(newStore.actionConfigs[1].command, "open \"https://www.google.com/search?q=$INPUT\"")
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
swift test --filter ConfigStoreTests 2>&1 | head -20
```

Expected: 编译失败，`ConfigStore` 未定义

- [ ] **Step 3: 实现 ConfigStore**

创建 `Sources/MiddleClickMenu/Storage/ConfigStore.swift`：

```swift
import Foundation

enum MenuStyle: String, Codable {
    case list
    case pie
}

struct AppConfig: Codable, Equatable {
    var menuStyle: MenuStyle = .list
    var launchAtLogin: Bool = false
    var blacklistApps: [String] = []
    var toastDuration: Double = 2.0
}

struct ActionConfig: Codable, Equatable, Identifiable {
    var id: String
    var type: ActionType
    var name: String?
    var icon: String?
    var command: String?
    var requiresText: Bool?
    var enabled: Bool
    var order: Int
}

class ConfigStore {
    private let directory: URL
    private let configFile: URL
    private let actionsFile: URL

    var config: AppConfig
    var actionConfigs: [ActionConfig]

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MiddleClickMenu")
        self.directory = dir
        self.configFile = dir.appendingPathComponent("config.json")
        self.actionsFile = dir.appendingPathComponent("actions.json")

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        if let data = try? Data(contentsOf: configFile),
           let loaded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            self.config = loaded
        } else {
            self.config = AppConfig()
        }

        if let data = try? Data(contentsOf: actionsFile),
           let loaded = try? JSONDecoder().decode([ActionConfig].self, from: data) {
            self.actionConfigs = loaded
        } else {
            self.actionConfigs = [
                ActionConfig(id: "timestamp-convert", type: .builtin, name: "时间戳转换", icon: "clock", enabled: true, order: 0)
            ]
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let data = try? encoder.encode(config) {
            try? data.write(to: configFile)
        }
        if let data = try? encoder.encode(actionConfigs) {
            try? data.write(to: actionsFile)
        }
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
swift test --filter ConfigStoreTests
```

Expected: All tests passed

- [ ] **Step 5: Commit**

```bash
git add Sources/MiddleClickMenu/Storage/ Tests/
git commit -m "feat: 实现 ConfigStore 配置存储，支持 config.json 和 actions.json"
```

---

## Task 3: TimestampAction — 时间戳转换

**Files:**
- Create: `Sources/MiddleClickMenu/Actions/TimestampAction.swift`
- Create: `Tests/MiddleClickMenuTests/TimestampActionTests.swift`

- [ ] **Step 1: 编写时间戳转换失败测试**

创建 `Tests/MiddleClickMenuTests/TimestampActionTests.swift`：

```swift
import XCTest
@testable import MiddleClickMenu

final class TimestampActionTests: XCTestCase {
    let action = TimestampAction()

    func testProperties() {
        XCTAssertEqual(action.id, "timestamp-convert")
        XCTAssertEqual(action.icon, "clock")
        XCTAssertTrue(action.requiresText)
    }

    func testUnixSeconds() async {
        let result = await action.run(input: "1747126680")
        guard case .text(let output) = result else {
            XCTFail("Expected .text result"); return
        }
        XCTAssertTrue(output.contains("2025-05-13"))
        XCTAssertTrue(output.contains("17:38:00") || output.contains(":38:00"))
    }

    func testUnixMilliseconds() async {
        let result = await action.run(input: "1747126680000")
        guard case .text(let output) = result else {
            XCTFail("Expected .text result"); return
        }
        XCTAssertTrue(output.contains("2025-05-13"))
    }

    func testWithWhitespace() async {
        let result = await action.run(input: "  1747126680  ")
        guard case .text = result else {
            XCTFail("Expected .text result"); return
        }
    }

    func testInvalidInput() async {
        let result = await action.run(input: "not-a-timestamp")
        guard case .error = result else {
            XCTFail("Expected .error result"); return
        }
    }

    func testNilInput() async {
        let result = await action.run(input: nil)
        guard case .error = result else {
            XCTFail("Expected .error result"); return
        }
    }

    func testEmptyInput() async {
        let result = await action.run(input: "")
        guard case .error = result else {
            XCTFail("Expected .error result"); return
        }
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
swift test --filter TimestampActionTests 2>&1 | head -10
```

Expected: 编译失败，`TimestampAction` 未定义

- [ ] **Step 3: 实现 TimestampAction**

创建 `Sources/MiddleClickMenu/Actions/TimestampAction.swift`：

```swift
import Foundation

struct TimestampAction: MenuAction {
    let id = "timestamp-convert"
    let name = "时间戳转换"
    let icon = "clock"
    let requiresText = true

    func run(input: String?) async -> ActionResult {
        guard let text = input?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return .error("没有选中文本")
        }

        guard let number = Double(text) else {
            return .error("无法识别的时间戳")
        }

        let timeInterval: TimeInterval
        if text.count == 13 {
            timeInterval = number / 1000.0
        } else if text.count == 10 {
            timeInterval = number
        } else if number > 1_000_000_000_000 {
            timeInterval = number / 1000.0
        } else if number > 1_000_000_000 {
            timeInterval = number
        } else {
            return .error("无法识别的时间戳")
        }

        let date = Date(timeIntervalSince1970: timeInterval)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current

        return .text(formatter.string(from: date))
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
swift test --filter TimestampActionTests
```

Expected: All tests passed

- [ ] **Step 5: Commit**

```bash
git add Sources/MiddleClickMenu/Actions/TimestampAction.swift Tests/MiddleClickMenuTests/TimestampActionTests.swift
git commit -m "feat: 实现时间戳转换内置动作，支持秒级和毫秒级 Unix 时间戳"
```

---

## Task 4: ShellAction + AppleScriptAction — 用户自定义动作

**Files:**
- Create: `Sources/MiddleClickMenu/Actions/ShellAction.swift`
- Create: `Sources/MiddleClickMenu/Actions/AppleScriptAction.swift`
- Create: `Tests/MiddleClickMenuTests/ShellActionTests.swift`

- [ ] **Step 1: 编写 ShellAction 失败测试**

创建 `Tests/MiddleClickMenuTests/ShellActionTests.swift`：

```swift
import XCTest
@testable import MiddleClickMenu

final class ShellActionTests: XCTestCase {
    func testEchoCommand() async {
        let action = ShellAction(
            id: "test-echo",
            name: "Echo",
            icon: "terminal",
            requiresText: false,
            command: "echo hello"
        )
        let result = await action.run(input: nil)
        XCTAssertEqual(result, .text("hello"))
    }

    func testInputSubstitution() async {
        let action = ShellAction(
            id: "test-input",
            name: "Echo Input",
            icon: "terminal",
            requiresText: true,
            command: "echo $INPUT"
        )
        let result = await action.run(input: "world")
        XCTAssertEqual(result, .text("world"))
    }

    func testFailingCommand() async {
        let action = ShellAction(
            id: "test-fail",
            name: "Fail",
            icon: "terminal",
            requiresText: false,
            command: "exit 1"
        )
        let result = await action.run(input: nil)
        guard case .error = result else {
            XCTFail("Expected .error result"); return
        }
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
swift test --filter ShellActionTests 2>&1 | head -10
```

Expected: 编译失败

- [ ] **Step 3: 实现 ShellAction**

创建 `Sources/MiddleClickMenu/Actions/ShellAction.swift`：

```swift
import Foundation

struct ShellAction: MenuAction {
    let id: String
    let name: String
    let icon: String
    let requiresText: Bool
    let command: String

    func run(input: String?) async -> ActionResult {
        let expandedCommand = command.replacingOccurrences(of: "$INPUT", with: input ?? "")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", expandedCommand]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if process.terminationStatus == 0 {
                return output.isEmpty ? .silent : .text(output)
            } else {
                return .error("命令执行失败 (code \(process.terminationStatus)): \(output)")
            }
        } catch {
            return .error("无法执行命令: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
swift test --filter ShellActionTests
```

Expected: All tests passed

- [ ] **Step 5: 实现 AppleScriptAction**

创建 `Sources/MiddleClickMenu/Actions/AppleScriptAction.swift`：

```swift
import Foundation

struct AppleScriptAction: MenuAction {
    let id: String
    let name: String
    let icon: String
    let requiresText: Bool
    let script: String

    func run(input: String?) async -> ActionResult {
        let expandedScript = script.replacingOccurrences(of: "$INPUT", with: input ?? "")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", expandedScript]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if process.terminationStatus == 0 {
                return output.isEmpty ? .silent : .text(output)
            } else {
                return .error("AppleScript 执行失败: \(output)")
            }
        } catch {
            return .error("无法执行 AppleScript: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 6: Commit**

```bash
git add Sources/MiddleClickMenu/Actions/ Tests/MiddleClickMenuTests/ShellActionTests.swift
git commit -m "feat: 实现 ShellAction 和 AppleScriptAction 用户自定义动作"
```

---

## Task 5: ActionRunner — 动作调度

**Files:**
- Create: `Sources/MiddleClickMenu/Core/ActionRunner.swift`
- Create: `Tests/MiddleClickMenuTests/ActionRunnerTests.swift`

- [ ] **Step 1: 编写 ActionRunner 失败测试**

创建 `Tests/MiddleClickMenuTests/ActionRunnerTests.swift`：

```swift
import XCTest
@testable import MiddleClickMenu

final class ActionRunnerTests: XCTestCase {
    func testLoadBuiltinActions() {
        let store = ConfigStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let runner = ActionRunner(configStore: store)
        let actions = runner.availableActions(selectedText: nil)
        XCTAssertFalse(actions.isEmpty)
        XCTAssertTrue(actions.contains(where: { $0.id == "timestamp-convert" }))
    }

    func testTextRequiredActionsDisabledWhenNoText() {
        let store = ConfigStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let runner = ActionRunner(configStore: store)
        let actions = runner.availableActions(selectedText: nil)
        let timestamp = actions.first(where: { $0.id == "timestamp-convert" })
        XCTAssertNotNil(timestamp)
        let enabled = runner.isActionEnabled(timestamp!, selectedText: nil)
        XCTAssertFalse(enabled)
    }

    func testTextRequiredActionsEnabledWithText() {
        let store = ConfigStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let runner = ActionRunner(configStore: store)
        let actions = runner.availableActions(selectedText: "1747126680")
        let timestamp = actions.first(where: { $0.id == "timestamp-convert" })
        XCTAssertNotNil(timestamp)
        let enabled = runner.isActionEnabled(timestamp!, selectedText: "1747126680")
        XCTAssertTrue(enabled)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
swift test --filter ActionRunnerTests 2>&1 | head -10
```

Expected: 编译失败

- [ ] **Step 3: 实现 ActionRunner**

创建 `Sources/MiddleClickMenu/Core/ActionRunner.swift`：

```swift
import Foundation
import AppKit

class ActionRunner {
    private let configStore: ConfigStore
    private var actions: [MenuAction] = []

    init(configStore: ConfigStore) {
        self.configStore = configStore
        reloadActions()
    }

    func reloadActions() {
        actions = configStore.actionConfigs
            .filter(\.enabled)
            .sorted(by: { $0.order < $1.order })
            .compactMap { config -> MenuAction? in
                switch config.type {
                case .builtin:
                    return builtinAction(for: config.id)
                case .shell:
                    guard let command = config.command else { return nil }
                    return ShellAction(
                        id: config.id,
                        name: config.name ?? config.id,
                        icon: config.icon ?? "terminal",
                        requiresText: config.requiresText ?? false,
                        command: command
                    )
                case .appleScript:
                    guard let command = config.command else { return nil }
                    return AppleScriptAction(
                        id: config.id,
                        name: config.name ?? config.id,
                        icon: config.icon ?? "applescript",
                        requiresText: config.requiresText ?? false,
                        script: command
                    )
                case .shortcut:
                    guard let command = config.command else { return nil }
                    return ShellAction(
                        id: config.id,
                        name: config.name ?? config.id,
                        icon: config.icon ?? "bolt",
                        requiresText: config.requiresText ?? false,
                        command: "shortcuts run \"\(command)\" <<< \"$INPUT\""
                    )
                }
            }
    }

    func availableActions(selectedText: String?) -> [MenuAction] {
        return actions
    }

    func isActionEnabled(_ action: MenuAction, selectedText: String?) -> Bool {
        if action.requiresText && (selectedText == nil || selectedText!.isEmpty) {
            return false
        }
        return true
    }

    func execute(_ action: MenuAction, input: String?) async -> ActionResult {
        let result = await action.run(input: input)
        if case .text(let text) = result {
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        }
        return result
    }

    private func builtinAction(for id: String) -> MenuAction? {
        switch id {
        case "timestamp-convert": return TimestampAction()
        default: return nil
        }
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
swift test --filter ActionRunnerTests
```

Expected: All tests passed

- [ ] **Step 5: Commit**

```bash
git add Sources/MiddleClickMenu/Core/ActionRunner.swift Tests/MiddleClickMenuTests/ActionRunnerTests.swift
git commit -m "feat: 实现 ActionRunner 动作调度，支持内置/Shell/AppleScript/快捷指令"
```

---

## Task 6: TextProvider — Accessibility 读取选中文本

**Files:**
- Create: `Sources/MiddleClickMenu/Core/TextProvider.swift`

此模块依赖 Accessibility API，无法在普通单元测试中自动化测试（需要辅助功能权限 + 前台应用），手动验证。

- [ ] **Step 1: 实现 TextProvider**

创建 `Sources/MiddleClickMenu/Core/TextProvider.swift`：

```swift
import AppKit
import ApplicationServices

class TextProvider {
    func getSelectedText() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var focusedElement: CFTypeRef?

        let focusResult = AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success, let element = focusedElement else {
            return nil
        }

        var selectedText: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        guard textResult == .success, let text = selectedText as? String, !text.isEmpty else {
            return nil
        }

        return text
    }

    static func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
```

- [ ] **Step 2: 构建验证**

```bash
swift build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Sources/MiddleClickMenu/Core/TextProvider.swift
git commit -m "feat: 实现 TextProvider，通过 Accessibility API 读取选中文本"
```

---

## Task 7: EventEngine — CGEvent Tap 鼠标中键拦截

**Files:**
- Create: `Sources/MiddleClickMenu/Core/EventEngine.swift`

系统级事件拦截，无法单元测试，手动验证。

- [ ] **Step 1: 实现 EventEngine**

创建 `Sources/MiddleClickMenu/Core/EventEngine.swift`：

```swift
import CoreGraphics
import AppKit

class EventEngine {
    typealias MiddleClickHandler = (_ mouseLocation: CGPoint) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapThread: Thread?
    private var onMiddleClick: MiddleClickHandler?
    private let configStore: ConfigStore

    init(configStore: ConfigStore) {
        self.configStore = configStore
    }

    func start(handler: @escaping MiddleClickHandler) {
        self.onMiddleClick = handler

        tapThread = Thread {
            self.setupEventTap()
            CFRunLoopRun()
        }
        tapThread?.name = "EventEngine.TapThread"
        tapThread?.start()
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource, let tap = eventTap {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.otherMouseDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let engine = Unmanaged<EventEngine>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = engine.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passRetained(event)
            }

            guard type == .otherMouseDown else {
                return Unmanaged.passRetained(event)
            }

            let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
            guard buttonNumber == 2 else {
                return Unmanaged.passRetained(event)
            }

            if engine.isCurrentAppBlacklisted() {
                return Unmanaged.passRetained(event)
            }

            let location = event.location
            DispatchQueue.main.async {
                engine.onMiddleClick?(location)
            }

            return nil
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: selfPtr
        ) else {
            print("[EventEngine] 无法创建 CGEvent Tap，请检查辅助功能权限")
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func isCurrentAppBlacklisted() -> Bool {
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        return configStore.config.blacklistApps.contains(bundleId)
    }
}
```

- [ ] **Step 2: 构建验证**

```bash
swift build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Sources/MiddleClickMenu/Core/EventEngine.swift
git commit -m "feat: 实现 EventEngine，CGEvent Tap 拦截鼠标中键并支持黑名单"
```

---

## Task 8: MenuPresenter + ListMenuView — 列表菜单

**Files:**
- Create: `Sources/MiddleClickMenu/Menu/MenuPresenter.swift`
- Create: `Sources/MiddleClickMenu/Menu/ListMenuView.swift`
- Create: `Sources/MiddleClickMenu/Menu/ToastView.swift`

- [ ] **Step 1: 实现 ToastView**

创建 `Sources/MiddleClickMenu/Menu/ToastView.swift`：

```swift
import SwiftUI

struct ToastView: View {
    let message: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? .red : .green)
                .font(.system(size: 16))
            Text(message)
                .font(.system(size: 13))
                .lineLimit(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }
}
```

- [ ] **Step 2: 实现 ListMenuView**

创建 `Sources/MiddleClickMenu/Menu/ListMenuView.swift`：

```swift
import SwiftUI

struct ListMenuView: View {
    let actions: [MenuAction]
    let selectedText: String?
    let isActionEnabled: (MenuAction) -> Bool
    let onSelect: (MenuAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                if index > 0 {
                    Divider().padding(.horizontal, 8)
                }
                Button {
                    onSelect(action)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: action.icon)
                            .font(.system(size: 14))
                            .frame(width: 20)
                        Text(action.name)
                            .font(.system(size: 13))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isActionEnabled(action))
                .opacity(isActionEnabled(action) ? 1.0 : 0.4)
            }
        }
        .padding(.vertical, 6)
        .frame(minWidth: 180)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }
}
```

- [ ] **Step 3: 实现 MenuPresenter**

创建 `Sources/MiddleClickMenu/Menu/MenuPresenter.swift`：

```swift
import SwiftUI
import AppKit

class MenuPresenter {
    private var menuPanel: NSPanel?
    private var toastPanel: NSPanel?
    private let configStore: ConfigStore

    init(configStore: ConfigStore) {
        self.configStore = configStore
    }

    @MainActor
    func showMenu(
        at screenPoint: CGPoint,
        actions: [MenuAction],
        selectedText: String?,
        isActionEnabled: @escaping (MenuAction) -> Bool,
        onSelect: @escaping (MenuAction) -> Void
    ) {
        dismissMenu()

        let menuView: AnyView
        switch configStore.config.menuStyle {
        case .list:
            menuView = AnyView(ListMenuView(
                actions: actions,
                selectedText: selectedText,
                isActionEnabled: isActionEnabled,
                onSelect: { [weak self] action in
                    self?.dismissMenu()
                    onSelect(action)
                }
            ))
        case .pie:
            menuView = AnyView(PieMenuView(
                actions: actions,
                selectedText: selectedText,
                isActionEnabled: isActionEnabled,
                onSelect: { [weak self] action in
                    self?.dismissMenu()
                    onSelect(action)
                }
            ))
        }

        let hostingView = NSHostingView(rootView: menuView)
        hostingView.setFrameSize(hostingView.fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.contentView = hostingView
        panel.isMovable = false

        let flippedY = NSScreen.main!.frame.height - screenPoint.y
        panel.setFrameTopLeftPoint(NSPoint(x: screenPoint.x, y: flippedY))

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1.0
        }

        self.menuPanel = panel

        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let panel = self?.menuPanel, !panel.frame.contains(NSEvent.mouseLocation) {
                self?.dismissMenu()
            }
            return event
        }
    }

    @MainActor
    func dismissMenu() {
        guard let panel = menuPanel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
        menuPanel = nil
    }

    @MainActor
    func showToast(_ message: String, isError: Bool, near screenPoint: CGPoint) {
        let toastView = ToastView(message: message, isError: isError)
        let hostingView = NSHostingView(rootView: toastView)
        hostingView.setFrameSize(hostingView.fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.contentView = hostingView

        let flippedY = NSScreen.main!.frame.height - screenPoint.y + 20
        panel.setFrameTopLeftPoint(NSPoint(x: screenPoint.x, y: flippedY))

        toastPanel?.orderOut(nil)
        self.toastPanel = panel

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1.0
        }

        let duration = configStore.config.toastDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
                if self?.toastPanel === panel {
                    self?.toastPanel = nil
                }
            })
        }
    }
}
```

- [ ] **Step 4: 构建验证**

```bash
swift build 2>&1 | tail -5
```

Expected: 会因为 `PieMenuView` 不存在而失败——这是预期的，下一个 Task 实现。先创建一个占位文件让编译通过。

创建 `Sources/MiddleClickMenu/Menu/PieMenuView.swift`（占位）：

```swift
import SwiftUI

struct PieMenuView: View {
    let actions: [MenuAction]
    let selectedText: String?
    let isActionEnabled: (MenuAction) -> Bool
    let onSelect: (MenuAction) -> Void

    var body: some View {
        Text("Pie Menu - TODO")
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
```

- [ ] **Step 5: 构建验证**

```bash
swift build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add Sources/MiddleClickMenu/Menu/
git commit -m "feat: 实现 MenuPresenter、ListMenuView、ToastView，以及 PieMenuView 占位"
```

---

## Task 9: PieMenuView — 环形菜单

**Files:**
- Modify: `Sources/MiddleClickMenu/Menu/PieMenuView.swift`

- [ ] **Step 1: 实现完整的 PieMenuView**

替换 `Sources/MiddleClickMenu/Menu/PieMenuView.swift`：

```swift
import SwiftUI

struct PieMenuView: View {
    let actions: [MenuAction]
    let selectedText: String?
    let isActionEnabled: (MenuAction) -> Bool
    let onSelect: (MenuAction) -> Void

    @State private var hoveredIndex: Int? = nil

    private let radius: CGFloat = 90
    private let itemSize: CGFloat = 60
    private let canvasSize: CGFloat = 260

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 30, height: 30)

            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                let angle = angleForIndex(index, total: actions.count)
                let enabled = isActionEnabled(action)
                let isHovered = hoveredIndex == index

                Button {
                    if enabled { onSelect(action) }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: action.icon)
                            .font(.system(size: 18))
                        Text(action.name)
                            .font(.system(size: 10))
                            .lineLimit(1)
                    }
                    .frame(width: itemSize, height: itemSize)
                    .background(
                        Circle()
                            .fill(isHovered ? Color.accentColor.opacity(0.3) : Color.clear)
                    )
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    .opacity(enabled ? 1.0 : 0.4)
                }
                .buttonStyle(.plain)
                .offset(
                    x: radius * cos(angle),
                    y: radius * sin(angle)
                )
                .onHover { isHovering in
                    hoveredIndex = isHovering ? index : nil
                }
            }
        }
        .frame(width: canvasSize, height: canvasSize)
    }

    private func angleForIndex(_ index: Int, total: Int) -> CGFloat {
        let startAngle = -CGFloat.pi / 2
        let step = (2 * CGFloat.pi) / CGFloat(total)
        return startAngle + step * CGFloat(index)
    }
}
```

- [ ] **Step 2: 构建验证**

```bash
swift build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Sources/MiddleClickMenu/Menu/PieMenuView.swift
git commit -m "feat: 实现 PieMenuView 环形菜单，支持 hover 高亮和扇形布局"
```

---

## Task 10: 主流程串联 — AppDelegate 集成

**Files:**
- Modify: `Sources/MiddleClickMenu/App/AppDelegate.swift`

- [ ] **Step 1: 集成所有模块到 AppDelegate**

替换 `Sources/MiddleClickMenu/App/AppDelegate.swift`：

```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var configStore: ConfigStore!
    private var eventEngine: EventEngine!
    private var textProvider: TextProvider!
    private var menuPresenter: MenuPresenter!
    private var actionRunner: ActionRunner!
    private var lastClickLocation: CGPoint = .zero

    func applicationDidFinishLaunching(_ notification: Notification) {
        configStore = ConfigStore()
        textProvider = TextProvider()
        menuPresenter = MenuPresenter(configStore: configStore)
        actionRunner = ActionRunner(configStore: configStore)

        setupMenuBarIcon()
        startEventEngine()
    }

    private func startEventEngine() {
        guard TextProvider.checkAccessibilityPermission() else {
            TextProvider.requestAccessibilityPermission()
            updateStatusIcon(enabled: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.startEventEngine()
            }
            return
        }

        updateStatusIcon(enabled: true)
        eventEngine = EventEngine(configStore: configStore)
        eventEngine.start { [weak self] mouseLocation in
            self?.handleMiddleClick(at: mouseLocation)
        }
    }

    private func handleMiddleClick(at location: CGPoint) {
        lastClickLocation = location
        let selectedText = textProvider.getSelectedText()
        let actions = actionRunner.availableActions(selectedText: selectedText)

        menuPresenter.showMenu(
            at: location,
            actions: actions,
            selectedText: selectedText,
            isActionEnabled: { [weak self] action in
                self?.actionRunner.isActionEnabled(action, selectedText: selectedText) ?? false
            },
            onSelect: { [weak self] action in
                self?.executeAction(action, input: selectedText)
            }
        )
    }

    private func executeAction(_ action: MenuAction, input: String?) {
        Task {
            let result = await actionRunner.execute(action, input: input)
            await MainActor.run {
                switch result {
                case .text(let text):
                    menuPresenter.showToast(text, isError: false, near: lastClickLocation)
                case .error(let message):
                    menuPresenter.showToast(message, isError: true, near: lastClickLocation)
                case .silent:
                    break
                }
            }
        }
    }

    private func setupMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "MiddleClick Menu")
        }
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        let menu = NSMenu()

        let styleItem = NSMenuItem(title: "菜单模式", action: nil, keyEquivalent: "")
        let styleSubmenu = NSMenu()
        let listItem = NSMenuItem(title: "列表", action: #selector(setListStyle), keyEquivalent: "")
        listItem.target = self
        listItem.state = configStore.config.menuStyle == .list ? .on : .off
        let pieItem = NSMenuItem(title: "环形", action: #selector(setPieStyle), keyEquivalent: "")
        pieItem.target = self
        pieItem.state = configStore.config.menuStyle == .pie ? .on : .off
        styleSubmenu.addItem(listItem)
        styleSubmenu.addItem(pieItem)
        styleItem.submenu = styleSubmenu
        menu.addItem(styleItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "关于 MiddleClick Menu", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func setListStyle() {
        configStore.config.menuStyle = .list
        configStore.save()
        rebuildStatusMenu()
    }

    @objc private func setPieStyle() {
        configStore.config.menuStyle = .pie
        configStore.save()
        rebuildStatusMenu()
    }

    private func updateStatusIcon(enabled: Bool) {
        if let button = statusItem?.button {
            let symbolName = enabled ? "computermouse" : "computermouse.fill"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "MiddleClick Menu")
            button.appearsDisabled = !enabled
        }
    }
}
```

- [ ] **Step 2: 构建验证**

```bash
swift build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: 运行应用手动验证**

```bash
swift run &
```

验证项：
1. 菜单栏出现鼠标图标
2. 弹出辅助功能权限请求（首次）
3. 授权后，鼠标中键点击弹出列表菜单
4. 选中一段时间戳文本，中键 → 选择「时间戳转换」→ 显示转换结果 Toast

- [ ] **Step 4: Commit**

```bash
git add Sources/MiddleClickMenu/App/AppDelegate.swift
git commit -m "feat: 集成所有模块到 AppDelegate，完成主流程串联"
```

---

## Task 11: 设置界面

**Files:**
- Create: `Sources/MiddleClickMenu/Settings/SettingsView.swift`
- Create: `Sources/MiddleClickMenu/Settings/ActionEditorView.swift`
- Create: `Sources/MiddleClickMenu/Settings/BlacklistView.swift`

- [ ] **Step 1: 实现 ActionEditorView**

创建 `Sources/MiddleClickMenu/Settings/ActionEditorView.swift`：

```swift
import SwiftUI

struct ActionEditorView: View {
    @Binding var action: ActionConfig
    let isBuiltin: Bool
    var onTest: (() -> Void)?

    var body: some View {
        Form {
            if isBuiltin {
                LabeledContent("类型", value: "内置")
                LabeledContent("名称", value: action.name ?? action.id)
                Toggle("启用", isOn: $action.enabled)
            } else {
                TextField("名称", text: Binding(
                    get: { action.name ?? "" },
                    set: { action.name = $0 }
                ))

                Picker("类型", selection: $action.type) {
                    Text("Shell 命令").tag(ActionType.shell)
                    Text("AppleScript").tag(ActionType.appleScript)
                    Text("快捷指令").tag(ActionType.shortcut)
                }

                TextField("图标 (SF Symbol)", text: Binding(
                    get: { action.icon ?? "star" },
                    set: { action.icon = $0 }
                ))

                if action.type == .shortcut {
                    TextField("快捷指令名称", text: Binding(
                        get: { action.command ?? "" },
                        set: { action.command = $0 }
                    ))
                } else {
                    TextField("命令 / 脚本", text: Binding(
                        get: { action.command ?? "" },
                        set: { action.command = $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }

                Toggle("需要选中文本", isOn: Binding(
                    get: { action.requiresText ?? false },
                    set: { action.requiresText = $0 }
                ))

                Toggle("启用", isOn: $action.enabled)

                if let onTest = onTest {
                    Button("测试运行") { onTest() }
                }
            }
        }
        .padding()
    }
}
```

- [ ] **Step 2: 实现 BlacklistView**

创建 `Sources/MiddleClickMenu/Settings/BlacklistView.swift`：

```swift
import SwiftUI

struct BlacklistView: View {
    @Binding var blacklistApps: [String]
    @State private var newBundleId: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("黑名单应用")
                .font(.headline)
            Text("在以下应用中禁用鼠标中键拦截")
                .font(.caption)
                .foregroundColor(.secondary)

            List {
                ForEach(blacklistApps, id: \.self) { bundleId in
                    HStack {
                        Text(bundleId)
                            .font(.system(size: 12, design: .monospaced))
                        Spacer()
                    }
                }
                .onDelete { indexSet in
                    blacklistApps.remove(atOffsets: indexSet)
                }
            }
            .frame(minHeight: 100)

            HStack {
                TextField("Bundle ID (如 com.blender.Blender)", text: $newBundleId)
                    .textFieldStyle(.roundedBorder)
                Button("添加") {
                    let trimmed = newBundleId.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, !blacklistApps.contains(trimmed) else { return }
                    blacklistApps.append(trimmed)
                    newBundleId = ""
                }
                .disabled(newBundleId.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
    }
}
```

- [ ] **Step 3: 实现 SettingsView**

创建 `Sources/MiddleClickMenu/Settings/SettingsView.swift`：

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        HSplitView {
            VStack {
                List(selection: $viewModel.selectedActionId) {
                    ForEach(viewModel.actions) { action in
                        HStack {
                            Image(systemName: action.icon ?? "star")
                                .frame(width: 20)
                            Text(action.name ?? action.id)
                            Spacer()
                            if !action.enabled {
                                Text("已禁用")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(action.id)
                    }
                    .onMove { from, to in
                        viewModel.moveAction(from: from, to: to)
                    }
                }
                .frame(minWidth: 180)

                HStack {
                    Button("+") { viewModel.addAction() }
                    Button("-") { viewModel.removeSelectedAction() }
                        .disabled(viewModel.selectedActionId == nil || viewModel.isSelectedBuiltin)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            VStack {
                if let index = viewModel.selectedIndex {
                    ActionEditorView(
                        action: $viewModel.actions[index],
                        isBuiltin: viewModel.actions[index].type == .builtin,
                        onTest: viewModel.actions[index].type != .builtin ? {
                            viewModel.testAction(at: index)
                        } : nil
                    )
                } else {
                    Text("选择一个菜单项进行编辑")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 300)
        }
        .frame(width: 560, height: 380)
    }
}

class SettingsViewModel: ObservableObject {
    @Published var actions: [ActionConfig]
    @Published var selectedActionId: String?
    private let configStore: ConfigStore

    var selectedIndex: Int? {
        actions.firstIndex(where: { $0.id == selectedActionId })
    }

    var isSelectedBuiltin: Bool {
        guard let index = selectedIndex else { return false }
        return actions[index].type == .builtin
    }

    init(configStore: ConfigStore) {
        self.configStore = configStore
        self.actions = configStore.actionConfigs
    }

    func save() {
        for i in actions.indices {
            actions[i].order = i
        }
        configStore.actionConfigs = actions
        configStore.save()
    }

    func addAction() {
        let newAction = ActionConfig(
            id: UUID().uuidString,
            type: .shell,
            name: "新建动作",
            icon: "star",
            command: "echo $INPUT",
            requiresText: false,
            enabled: true,
            order: actions.count
        )
        actions.append(newAction)
        selectedActionId = newAction.id
        save()
    }

    func removeSelectedAction() {
        guard let index = selectedIndex, actions[index].type != .builtin else { return }
        actions.remove(at: index)
        selectedActionId = nil
        save()
    }

    func moveAction(from source: IndexSet, to destination: Int) {
        actions.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func testAction(at index: Int) {
        let config = actions[index]
        let action: MenuAction?
        switch config.type {
        case .shell:
            action = ShellAction(id: config.id, name: config.name ?? "", icon: config.icon ?? "star", requiresText: config.requiresText ?? false, command: config.command ?? "")
        case .appleScript:
            action = AppleScriptAction(id: config.id, name: config.name ?? "", icon: config.icon ?? "star", requiresText: config.requiresText ?? false, script: config.command ?? "")
        default:
            action = nil
        }
        guard let action = action else { return }
        Task {
            let result = await action.run(input: "test_input")
            await MainActor.run {
                let alert = NSAlert()
                switch result {
                case .text(let text):
                    alert.messageText = "执行成功"
                    alert.informativeText = text
                case .silent:
                    alert.messageText = "执行成功"
                    alert.informativeText = "（无输出）"
                case .error(let msg):
                    alert.messageText = "执行失败"
                    alert.informativeText = msg
                    alert.alertStyle = .warning
                }
                alert.runModal()
            }
        }
    }
}
```

- [ ] **Step 4: 构建验证**

```bash
swift build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Sources/MiddleClickMenu/Settings/
git commit -m "feat: 实现设置界面，支持菜单项管理、编辑、排序和黑名单配置"
```

---

## Task 12: AppDelegate 集成设置窗口入口

**Files:**
- Modify: `Sources/MiddleClickMenu/App/AppDelegate.swift`

- [ ] **Step 1: 添加设置窗口打开入口**

在 `AppDelegate.swift` 中添加设置窗口属性和菜单项：

在 `class AppDelegate` 的属性区域添加：

```swift
private var settingsWindow: NSWindow?
```

在 `rebuildStatusMenu()` 方法中，在 `menu.addItem(NSMenuItem.separator())` 之前插入：

```swift
let manageItem = NSMenuItem(title: "管理菜单项...", action: #selector(openSettings), keyEquivalent: ",")
manageItem.target = self
menu.addItem(manageItem)
```

添加方法：

```swift
@objc private func openSettings() {
    if let window = settingsWindow {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return
    }
    let viewModel = SettingsViewModel(configStore: configStore)
    let settingsView = SettingsView(viewModel: viewModel)
    let hostingView = NSHostingView(rootView: settingsView)
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.title = "MiddleClick Menu 设置"
    window.contentView = hostingView
    window.center()
    window.makeKeyAndOrderFront(nil)
    window.delegate = self
    NSApp.activate(ignoringOtherApps: true)
    self.settingsWindow = window
}
```

让 `AppDelegate` 实现 `NSWindowDelegate`：

```swift
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow {
            actionRunner.reloadActions()
            settingsWindow = nil
        }
    }
}
```

在文件顶部添加 `import SwiftUI`。

- [ ] **Step 2: 构建验证**

```bash
swift build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Sources/MiddleClickMenu/App/AppDelegate.swift
git commit -m "feat: 菜单栏集成设置窗口入口，关闭时自动重载动作配置"
```

---

## Task 13: README 与最终验证

**Files:**
- Create: `README.md`

- [ ] **Step 1: 编写 README**

创建 `/Users/ji/MiddleClickMenu/README.md`：

```markdown
# MiddleClick Menu

macOS 鼠标中键快捷菜单工具。在任意应用中按下鼠标中键，即可在光标位置弹出快捷菜单，对选中文本执行操作。

## 功能

- 鼠标中键全局拦截，弹出快捷菜单
- 两种菜单模式：列表菜单 / 环形菜单（Pie Menu）
- 读取当前选中文本，传递给菜单动作
- 内置动作：时间戳转换（Unix 秒/毫秒 → 年月日时分秒）
- 自定义动作：Shell 命令、AppleScript、macOS 快捷指令
- 黑名单应用：在指定应用中禁用中键拦截
- 纯菜单栏应用，无 Dock 图标

## 系统要求

- macOS 13.0 (Ventura) 或更高版本
- Apple Silicon
- 辅助功能权限（首次启动时自动引导授权）

## 构建与运行

```bash
swift build
swift run
```

## 使用方法

1. 启动后在菜单栏出现鼠标图标
2. 授予辅助功能权限
3. 在任意应用中选中文本（如一段时间戳）
4. 按下鼠标中键 → 弹出菜单
5. 选择动作 → 查看结果（自动复制到剪贴板）

## 配置

配置文件位于 `~/Library/Application Support/MiddleClickMenu/`：

- `config.json` — 全局设置（菜单模式、黑名单、开机启动等）
- `actions.json` — 菜单项配置
```

- [ ] **Step 2: 运行全部测试**

```bash
swift test
```

Expected: All tests passed

- [ ] **Step 3: 构建 Release 版本**

```bash
swift build -c release
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: 添加 README，项目基本说明和使用方法"
```

---

## 自检结果

**1. Spec 覆盖检查：**

| Spec 章节 | 对应 Task |
|-----------|----------|
| 概述 / 架构 | Task 1 (脚手架) |
| EventEngine | Task 7 |
| TextProvider | Task 6 |
| MenuPresenter | Task 8, 9 |
| ActionRunner | Task 5 |
| 动作系统 (协议 + 内置 + Shell + AS) | Task 1, 3, 4 |
| 设置与配置 | Task 2, 11, 12 |
| 项目结构 | Task 1 |
| 技术约束 (LSUIElement, macOS 13 等) | Task 1 (Info.plist, Package.swift) |

全部覆盖，无遗漏。

**2. Placeholder 扫描：** 无 TBD / TODO（PieMenuView 占位在 Task 9 中被完整实现替换）。

**3. 类型一致性：** `MenuAction` 协议、`ActionResult` 枚举、`ActionConfig` 结构体、`ConfigStore` 类在所有 Task 中保持一致。
