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
