import SwiftUI
import AppKit

class MenuPresenter {
    private var menuPanel: NSPanel?
    private var toastPanel: NSPanel?
    private var clickMonitor: Any?
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
        panel.isMovable = false

        let flippedY = NSScreen.main!.frame.height - screenPoint.y
        panel.setFrameTopLeftPoint(NSPoint(x: screenPoint.x, y: flippedY))

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1.0
        }

        self.menuPanel = panel

        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let panel = self?.menuPanel, !panel.frame.contains(NSEvent.mouseLocation) {
                self?.dismissMenu()
            }
            return event
        }
    }

    @MainActor
    func dismissMenu() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        guard let panel = menuPanel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
        menuPanel = nil
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

        let flippedY = NSScreen.main!.frame.height - screenPoint.y + 20
        panel.setFrameTopLeftPoint(NSPoint(x: screenPoint.x, y: flippedY))

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
