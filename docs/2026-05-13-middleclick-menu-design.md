# MiddleClick Menu — macOS 鼠标中键菜单工具 设计文档

**日期**：2026-05-13
**状态**：已确认，待实施

---

## 1. 概述

MiddleClick Menu 是一款 macOS 菜单栏常驻应用，用户在任意应用中按下鼠标中键即可在光标位置弹出快捷菜单，对选中文本执行快捷操作。支持环形菜单和列表菜单两种形式，支持内置动作和用户自定义动作（Shell / AppleScript / 快捷指令）。

**目标平台**：macOS 13.0+ (Ventura)，Apple Silicon
**风格定位**：小而美，简约快速
**技术栈**：Swift + SwiftUI + AppKit 混合，零第三方依赖

---

## 2. 核心架构

```
┌─────────────────────────────────────┐
│          MenuBarApp (入口)           │
│  SwiftUI App + NSApplicationDelegate │
├──────────┬──────────┬───────────────┤
│ EventEngine │ MenuPresenter │ ActionRunner │
│ (CGEvent Tap) │ (菜单窗口管理)  │ (执行菜单动作) │
├──────────┴──────────┴───────────────┤
│          TextProvider                │
│  (Accessibility API 获取选中文本)     │
├─────────────────────────────────────┤
│          ConfigStore                 │
│  (菜单项配置持久化, JSON 文件)        │
└─────────────────────────────────────┘
```

### 模块职责

| 模块 | 职责 | 关键技术 |
|------|------|---------|
| **EventEngine** | 全局拦截鼠标中键按下/释放，吞掉事件，通知 MenuPresenter | `CGEvent Tap`, 独立线程 RunLoop |
| **TextProvider** | 获取当前前台应用的选中文本 | `AXUIElement`, Accessibility API |
| **MenuPresenter** | 在鼠标位置创建并显示菜单窗口（Pie / List 两种模式） | SwiftUI + NSPanel |
| **ActionRunner** | 接收选中的菜单项 + 文本，执行对应动作 | 内置动作 + Process/NSAppleScript |
| **ConfigStore** | 持久化菜单项配置、偏好设置 | JSON 文件 |

### 运行时数据流

```
用户选中文本 → 按下鼠标中键
    → EventEngine 拦截并吞掉事件（返回 nil）
    → TextProvider 通过 AX API 读取选中文本
    → MenuPresenter 在光标位置弹出菜单
    → 用户选择菜单项
    → ActionRunner 执行动作（传入选中文本）
    → 显示结果 Toast / 写入剪贴板
```

---

## 3. EventEngine — 鼠标中键拦截

### 技术方案：CGEvent Tap

- 应用启动时创建 `CGEvent Tap`，类型为 `cgSessionEventTap`，监听 `otherMouseDown`（中键按下）
- 拦截到中键事件后返回 `nil` 吞掉事件，阻止传递给前台应用
- 记录按下时的鼠标坐标（`CGEvent.location`），作为菜单弹出位置
- 事件在后台线程 RunLoop 中接收，通过 `@MainActor` 回调到主线程触发菜单

### 权限处理

- 首次启动检测 `AXIsProcessTrusted()`
- 未授权时弹出引导弹窗，引导用户到「系统设置 → 隐私与安全性 → 辅助功能」授权
- 未授权状态下应用可运行，但中键功能不可用，菜单栏图标显示禁用状态

### 防冲突

- 菜单弹出后点击外部区域 → 菜单消失，不执行动作
- 提供「黑名单应用」设置，在指定应用中禁用中键拦截（如 Blender 等依赖中键的应用）

---

## 4. TextProvider — 选中文本获取

### 获取流程

1. `NSWorkspace.shared.frontmostApplication` 获取前台应用 PID
2. `AXUIElementCreateApplication(pid)` 创建 AX 引用
3. 沿 AX 层级获取 `kAXFocusedUIElementAttribute`（焦点元素）
4. 读取 `kAXSelectedTextAttribute` 获取选中文本
5. 选中文本为空时传入 `nil`

### 容错

- 不支持 AX 的应用（某些终端、Electron 应用）→ 菜单照常弹出，依赖文本的菜单项显示为灰色不可用

---

## 5. MenuPresenter — 菜单呈现

### 通用行为

- 使用 `NSPanel`（`nonactivatingPanel`），不抢夺前台焦点
- 弹出位置 = 鼠标中键按下时的屏幕坐标
- 按 Esc 或点击外部关闭
- 弹出/消失动画：缩放 + 透明度，~150ms

### 列表菜单（List Menu）

- 紧凑圆角列表，毛玻璃背景（`.ultraThinMaterial`）
- 每项：图标（SF Symbol）+ 名称，hover 高亮
- 支持分组分隔线
- 超过 8 项时滚动显示

### 环形菜单（Pie Menu）

- 以鼠标位置为圆心，扇形分布
- 鼠标滑向方向高亮，单击（左键）确认选择
- 每扇区：图标 + 简短标签
- 最多 8 个扇区，超出可设子菜单

### 结果展示（Toast）

- 鼠标附近浮现结果气泡
- 2 秒后自动消失
- 结果自动写入剪贴板

---

## 6. ActionRunner — 动作系统

### 动作协议

```swift
protocol MenuAction {
    var id: String { get }
    var name: String { get }
    var icon: String { get }           // SF Symbol 名称
    var requiresText: Bool { get }     // 是否需要选中文本
    func run(input: String?) async -> ActionResult
}

enum ActionResult {
    case text(String)       // 显示结果 + 复制到剪贴板
    case silent             // 静默执行
    case error(String)      // 显示错误
}
```

### 第一版支持的动作类型

| 类型 | 说明 |
|------|------|
| **内置动作** | 编译在应用内，如时间戳转换 |
| **Shell 命令** | 用户配置 shell 命令，`$INPUT` 为选中文本占位符 |
| **AppleScript** | 用户编写 AppleScript 片段 |
| **快捷指令** | 通过 `shortcuts run` 命令行调用系统 Shortcuts |

### 内置功能：时间戳转换

- 接收选中文本，尝试解析为时间戳
- 支持：Unix 秒级（10 位）、Unix 毫秒（13 位）
- 转换为本地时区 `yyyy-MM-dd HH:mm:ss`
- 无法识别时返回 `ActionResult.error("无法识别的时间戳")`
- 成功结果自动复制到剪贴板

---

## 7. 设置与配置

### 菜单栏下拉菜单

- 菜单模式切换（环形 / 列表）
- 管理菜单项（打开设置窗口）
- 黑名单应用
- 开机启动开关
- 关于 / 退出

### 设置窗口

- 左侧：菜单项列表，支持拖拽排序
- 右侧：选中项的编辑区，根据动作类型显示不同配置
- 内置动作只能启用/禁用
- 用户动作可编辑、删除、测试运行

### 配置存储

**路径**：`~/Library/Application Support/MiddleClickMenu/`

**config.json** — 全局设置：

```json
{
  "menuStyle": "pie",
  "launchAtLogin": true,
  "blacklistApps": ["com.blender.Blender"],
  "toastDuration": 2.0
}
```

**actions.json** — 菜单项配置：

```json
[
  {
    "id": "timestamp-convert",
    "type": "builtin",
    "enabled": true,
    "order": 0
  },
  {
    "id": "google-search",
    "type": "shell",
    "name": "Google 搜索",
    "icon": "magnifyingglass",
    "command": "open \"https://www.google.com/search?q=$INPUT\"",
    "requiresText": true,
    "enabled": true,
    "order": 1
  }
]
```

---

## 8. 项目结构

```
MiddleClickMenu/
├── MiddleClickMenu.xcodeproj
├── MiddleClickMenu/
│   ├── App/
│   │   ├── MiddleClickMenuApp.swift
│   │   └── AppDelegate.swift
│   ├── Core/
│   │   ├── EventEngine.swift
│   │   ├── TextProvider.swift
│   │   └── ActionRunner.swift
│   ├── Actions/
│   │   ├── MenuAction.swift
│   │   ├── TimestampAction.swift
│   │   ├── ShellAction.swift
│   │   └── AppleScriptAction.swift
│   ├── Menu/
│   │   ├── MenuPresenter.swift
│   │   ├── PieMenuView.swift
│   │   ├── ListMenuView.swift
│   │   └── ToastView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── ActionEditorView.swift
│   │   └── BlacklistView.swift
│   ├── Storage/
│   │   └── ConfigStore.swift
│   └── Resources/
│       └── Assets.xcassets
└── README.md
```

---

## 9. 技术约束

| 约束 | 说明 |
|------|------|
| 最低系统版本 | macOS 13.0 (Ventura) |
| 签名 | Developer ID，不走 App Store |
| Info.plist | `LSUIElement = true`（隐藏 Dock 图标） |
| 权限 | 辅助功能（Accessibility），无沙盒 |
| Swift 版本 | Swift 5.9+，async/await |
| 依赖 | 零第三方依赖，纯系统框架 |

---

## 10. 第一版不做的事情

- 不做跨平台
- 不做自动更新（后续可加 Sparkle）
- 不做国际化（先做中文，结构预留）
- 不做插件文件系统加载（第二版）
- 不做快捷键自定义触发（只用鼠标中键）
