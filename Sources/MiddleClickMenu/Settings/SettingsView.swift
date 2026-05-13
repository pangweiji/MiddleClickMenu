import SwiftUI
import AppKit

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
        let action: (any MenuAction)?
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
