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
