import SwiftUI
import AppKit

class MenuPresenter {
    private var menuPanel: NSPanel?
    private var toastPanel: NSPanel?
    private var clickMonitor: Any?
    private var keyMonitor: Any?
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
        dismissMenu()

        print("[MenuPresenter] 显示菜单 at \(screenPoint), \(actions.count) 个动作")

        let menuView: AnyView
        switch configStore.config.menuStyle {
        case .list:
            menuView = AnyView(ListMenuView(
                actions: actions,
                selectedText: selectedText,
                isActionEnabled: isActionEnabled,
                onSelect: { [weak self] action in
                    self?.dismissMenu()
                    onSelect(action)
                }
            ))
        case .pie:
            menuView = AnyView(PieMenuView(
                actions: actions,
                selectedText: selectedText,
                isActionEnabled: isActionEnabled,
                onSelect: { [weak self] action in
                    self?.dismissMenu()
                    onSelect(action)
                }
            ))
        }

        let hostingView = NSHostingView(rootView: menuView)
        hostingView.setFrameSize(hostingView.fittingSize)

        let panelSize = hostingView.fittingSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.contentView = hostingView
        panel.isMovable = false
        panel.hidesOnDeactivate = false

        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main {
            let flippedY = screen.frame.maxY - screenPoint.y
            var origin = NSPoint(x: screenPoint.x, y: flippedY)
            if origin.x + panelSize.width > screen.frame.maxX {
                origin.x = screen.frame.maxX - panelSize.width
            }
            if flippedY - panelSize.height < screen.frame.minY {
                origin.y = screen.frame.minY + panelSize.height
            }
            panel.setFrameTopLeftPoint(origin)
        }

        self.menuPanel = panel

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1.0
        }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.dismissMenu()
        }

        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.dismissMenu()
            }
        }

        print("[MenuPresenter] 菜单已显示")
    }

    @MainActor
    func dismissMenu() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        guard let panel = menuPanel else { return }
        menuPanel = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    @MainActor
    func showToast(_ message: String, isError: Bool, near screenPoint: CGPoint) {
        let toastView = ToastView(message: message, isError: isError)
        let hostingView = NSHostingView(rootView: toastView)
        hostingView.setFrameSize(hostingView.fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.contentView = hostingView
        panel.hidesOnDeactivate = false

        if let screen = NSScreen.main {
            let flippedY = screen.frame.maxY - screenPoint.y + 20
            panel.setFrameTopLeftPoint(NSPoint(x: screenPoint.x, y: flippedY))
        }

        toastPanel?.orderOut(nil)
        self.toastPanel = panel

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1.0
        }

        let duration = configStore.config.toastDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
                if self?.toastPanel === panel {
                    self?.toastPanel = nil
                }
            })
        }
    }
}
