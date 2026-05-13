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
