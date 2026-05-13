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
