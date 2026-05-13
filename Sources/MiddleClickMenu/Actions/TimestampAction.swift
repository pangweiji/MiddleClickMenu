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
