import Foundation

/**
 * 菜单样式枚举
 *
 * 详细说明：
 * - 定义菜单的展示方式：列表或饼状
 *
 * @Author Cursor AI
 * @Date 2026-05-13
 */
enum MenuStyle: String, Codable, Sendable {
    case list
    case pie
}

/**
 * 应用全局配置
 *
 * 详细说明：
 * - 存储应用级别的设置项
 * - 支持 JSON 序列化持久化
 *
 * @Author Cursor AI
 * @Date 2026-05-13
 */
struct AppConfig: Codable, Equatable, Sendable {
    var menuStyle: MenuStyle = .list
    var launchAtLogin: Bool = false
    var blacklistApps: [String] = []
    var toastDuration: Double = 2.0
}

/**
 * 动作配置项
 *
 * 详细说明：
 * - 描述单个菜单动作的完整配置
 * - 支持内建、Shell、AppleScript、快捷指令等类型
 *
 * @Author Cursor AI
 * @Date 2026-05-13
 */
struct ActionConfig: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var type: ActionType
    var name: String?
    var icon: String?
    var command: String?
    var requiresText: Bool?
    var enabled: Bool
    var order: Int
}

/**
 * 配置存储管理器
 *
 * 详细说明：
 * - 负责读写 config.json 和 actions.json
 * - 提供默认配置和默认动作
 * - 支持自定义存储目录（便于测试）
 *
 * @Author Cursor AI
 * @Date 2026-05-13
 */
class ConfigStore {
    private let directory: URL
    private let configFile: URL
    private let actionsFile: URL

    var config: AppConfig
    var actionConfigs: [ActionConfig]

    /**
     * 初始化配置存储
     *
     * 业务逻辑：
     * 1. 确定存储目录（传入或默认 Application Support）
     * 2. 创建目录（如不存在）
     * 3. 尝试从文件加载已有配置，失败则使用默认值
     *
     * @Author Cursor AI
     *
     * @param directory 自定义存储目录，nil 时使用默认路径
     */
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

    /**
     * 持久化当前配置到磁盘
     *
     * @Author Cursor AI
     */
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
