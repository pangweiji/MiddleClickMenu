import Foundation
import AppKit

/**
 * 动作调度器
 *
 * 详细说明：
 * - 根据 ConfigStore 中的动作配置加载并管理所有可用动作
 * - 支持内置、Shell、AppleScript、快捷指令四种动作类型
 * - 执行结果为文本时自动写入系统剪贴板
 *
 * @Author Cursor AI
 * @Date 2026-05-13
 */
class ActionRunner {
    private let configStore: ConfigStore
    private var actions: [MenuAction] = []

    /**
     * 初始化动作调度器
     *
     * @Author Cursor AI
     *
     * @param configStore 配置存储实例
     */
    init(configStore: ConfigStore) {
        self.configStore = configStore
        reloadActions()
    }

    /**
     * 从配置重新加载动作列表
     *
     * 业务逻辑：
     * 1. 过滤已启用的动作配置
     * 2. 按 order 排序
     * 3. 根据类型实例化对应的 MenuAction
     *
     * @Author Cursor AI
     */
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

    /**
     * 获取所有可用动作
     *
     * @Author Cursor AI
     *
     * @param selectedText 当前选中的文本
     * @return [MenuAction] 可用动作列表
     */
    func availableActions(selectedText: String?) -> [MenuAction] {
        return actions
    }

    /**
     * 判断动作是否可执行
     *
     * @Author Cursor AI
     *
     * @param action 待检查的动作
     * @param selectedText 当前选中的文本
     * @return Bool 是否可执行
     */
    func isActionEnabled(_ action: MenuAction, selectedText: String?) -> Bool {
        if action.requiresText && (selectedText == nil || selectedText!.isEmpty) {
            return false
        }
        return true
    }

    /**
     * 执行指定动作
     *
     * 业务逻辑：
     * 1. 调用动作的 run 方法获取结果
     * 2. 若结果为文本，自动写入系统剪贴板
     *
     * @Author Cursor AI
     *
     * @param action 要执行的动作
     * @param input 输入文本
     * @return ActionResult 执行结果
     */
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

    /**
     * 根据 ID 获取内置动作实例
     *
     * @Author Cursor AI
     *
     * @param id 内置动作标识符
     * @return MenuAction? 对应的动作实例
     */
    private func builtinAction(for id: String) -> MenuAction? {
        switch id {
        case "timestamp-convert": return TimestampAction()
        default: return nil
        }
    }
}
