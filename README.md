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
swift run MiddleClickMenu
```

Release 构建：

```bash
swift build -c release
```

## 运行测试

```bash
swift run MiddleClickMenuTests
```

## 使用方法

1. 启动后在菜单栏出现鼠标图标
2. 授予辅助功能权限
3. 在任意应用中选中文本（如一段时间戳）
4. 按下鼠标中键 → 弹出菜单
5. 选择动作 → 查看结果（自动复制到剪贴板）

## 配置

配置文件位于 `~/Library/Application Support/MiddleClickMenu/`：

- `config.json` — 全局设置（菜单模式、黑名单、Toast 时长等）
- `actions.json` — 菜单项配置

## 自定义动作示例

在设置界面中添加 Shell 命令动作，命令中使用 `$INPUT` 引用选中文本：

```bash
# Google 搜索选中文本
open "https://www.google.com/search?q=$INPUT"

# 统计字数
echo "$INPUT" | wc -w | tr -d ' '

# Base64 编码
echo -n "$INPUT" | base64
```
