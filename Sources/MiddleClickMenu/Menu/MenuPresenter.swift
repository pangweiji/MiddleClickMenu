import AppKit

class MenuPresenter {
    private var toastWindow: NSWindow?
    private let configStore: ConfigStore

    init(configStore: ConfigStore) {
        self.configStore = configStore
    }

    @MainActor
    func showMenu(
        at screenPoint: CGPoint,
        actions: [any MenuAction],
        selectedText: String?,
        isActionEnabled: @escaping (any MenuAction) -> Bool,
        onSelect: @escaping (any MenuAction) -> Void
    ) {
        print("[MenuPresenter] 构建原生菜单...")

        let menu = NSMenu()
        menu.autoenablesItems = false

        for action in actions {
            let item = NSMenuItem(title: action.name, action: nil, keyEquivalent: "")
            item.image = NSImage(systemSymbolName: action.icon, accessibilityDescription: action.name)
            item.image?.size = NSSize(width: 16, height: 16)

            let enabled = isActionEnabled(action)
            item.isEnabled = enabled

            if enabled {
                let handler = MenuItemHandler(action: action, onSelect: onSelect)
                item.target = handler
                item.action = #selector(MenuItemHandler.handleSelect)
                item.representedObject = handler
            }

            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(title: "设置...", action: nil, keyEquivalent: "")
        settingsItem.isEnabled = false
        menu.addItem(settingsItem)

        guard let screen = NSScreen.screens.first(where: {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        }) ?? NSScreen.main else {
            print("[MenuPresenter] 无法获取屏幕")
            return
        }

        let flippedY = screen.frame.maxY - screenPoint.y
        let menuLocation = NSPoint(x: screenPoint.x, y: flippedY)

        print("[MenuPresenter] 弹出菜单 at \(menuLocation)")
        menu.popUp(positioning: nil, at: menuLocation, in: nil)
    }

    @MainActor
    func dismissMenu() {}

    @MainActor
    func showToast(_ message: String, isError: Bool, near screenPoint: CGPoint) {
        print("[Toast] \(isError ? "错误" : "结果"): \(message)")

        toastWindow?.orderOut(nil)

        let label = NSTextField(labelWithString: message)
        label.font = NSFont.systemFont(ofSize: 13)
        label.textColor = isError ? .systemRed : .labelColor
        label.sizeToFit()

        let icon = NSImageView(image: NSImage(
            systemSymbolName: isError ? "xmark.circle.fill" : "checkmark.circle.fill",
            accessibilityDescription: nil
        )!)
        icon.frame = NSRect(x: 12, y: 0, width: 20, height: 20)
        icon.contentTintColor = isError ? .systemRed : .systemGreen

        let padding: CGFloat = 12
        let spacing: CGFloat = 8
        let contentWidth = icon.frame.width + spacing + label.frame.width
        let windowWidth = contentWidth + padding * 2
        let windowHeight: CGFloat = 36

        label.frame.origin = NSPoint(x: padding + icon.frame.width + spacing, y: (windowHeight - label.frame.height) / 2)
        icon.frame.origin.y = (windowHeight - icon.frame.height) / 2

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        contentView.layer?.cornerRadius = 8
        contentView.addSubview(icon)
        contentView.addSubview(label)

        guard let screen = NSScreen.main else { return }

        let flippedY = screen.frame.maxY - screenPoint.y + 24
        let windowFrame = NSRect(x: screenPoint.x, y: flippedY - windowHeight, width: windowWidth, height: windowHeight)

        let window = NSWindow(contentRect: windowFrame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.contentView = contentView
        window.hasShadow = true

        self.toastWindow = window
        window.orderFrontRegardless()

        let duration = configStore.config.toastDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.orderOut(nil)
                if self?.toastWindow === window {
                    self?.toastWindow = nil
                }
            })
        }
    }
}

private class MenuItemHandler: NSObject {
    let action: any MenuAction
    let onSelect: (any MenuAction) -> Void

    init(action: any MenuAction, onSelect: @escaping (any MenuAction) -> Void) {
        self.action = action
        self.onSelect = onSelect
    }

    @objc func handleSelect() {
        onSelect(action)
    }
}
