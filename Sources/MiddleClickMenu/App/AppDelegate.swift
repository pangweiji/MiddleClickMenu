import AppKit
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var configStore: ConfigStore!
    private var eventEngine: EventEngine!
    private var textProvider: TextProvider!
    private var menuPresenter: MenuPresenter!
    private var actionRunner: ActionRunner!
    private var lastClickLocation: CGPoint = .zero
    private var settingsWindow: NSWindow?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        configStore = ConfigStore()
        textProvider = TextProvider()
        menuPresenter = MenuPresenter(configStore: configStore)
        actionRunner = ActionRunner(configStore: configStore)

        setupMenuBarIcon()
        startEventEngine()
    }

    private func startEventEngine() {
        guard TextProvider.checkAccessibilityPermission() else {
            TextProvider.requestAccessibilityPermission()
            updateStatusIcon(enabled: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.startEventEngine()
            }
            return
        }

        updateStatusIcon(enabled: true)
        eventEngine = EventEngine(configStore: configStore)
        eventEngine.start { [weak self] mouseLocation in
            Task { @MainActor in
                self?.handleMiddleClick(at: mouseLocation)
            }
        }
    }

    @MainActor private func handleMiddleClick(at location: CGPoint) {
        lastClickLocation = location
        let selectedText = textProvider.getSelectedText()
        let actions = actionRunner.availableActions(selectedText: selectedText)

        menuPresenter.showMenu(
            at: location,
            actions: actions,
            selectedText: selectedText,
            isActionEnabled: { [weak self] action in
                self?.actionRunner.isActionEnabled(action, selectedText: selectedText) ?? false
            },
            onSelect: { [weak self] action in
                self?.executeAction(action, input: selectedText)
            }
        )
    }

    private func executeAction(_ action: any MenuAction, input: String?) {
        Task {
            let result = await actionRunner.execute(action, input: input)
            await MainActor.run {
                switch result {
                case .text(let text):
                    menuPresenter.showToast(text, isError: false, near: lastClickLocation)
                case .error(let message):
                    menuPresenter.showToast(message, isError: true, near: lastClickLocation)
                case .silent:
                    break
                }
            }
        }
    }

    private func setupMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "computermouse", accessibilityDescription: "MiddleClick Menu")
        }
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        let menu = NSMenu()

        let styleItem = NSMenuItem(title: "菜单模式", action: nil, keyEquivalent: "")
        let styleSubmenu = NSMenu()
        let listItem = NSMenuItem(title: "列表", action: #selector(setListStyle), keyEquivalent: "")
        listItem.target = self
        listItem.state = configStore.config.menuStyle == .list ? .on : .off
        let pieItem = NSMenuItem(title: "环形", action: #selector(setPieStyle), keyEquivalent: "")
        pieItem.target = self
        pieItem.state = configStore.config.menuStyle == .pie ? .on : .off
        styleSubmenu.addItem(listItem)
        styleSubmenu.addItem(pieItem)
        styleItem.submenu = styleSubmenu
        menu.addItem(styleItem)

        menu.addItem(NSMenuItem.separator())

        let manageItem = NSMenuItem(title: "管理菜单项...", action: #selector(openSettings), keyEquivalent: ",")
        manageItem.target = self
        menu.addItem(manageItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "关于 MiddleClick Menu", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func setListStyle() {
        configStore.config.menuStyle = .list
        configStore.save()
        rebuildStatusMenu()
    }

    @objc private func setPieStyle() {
        configStore.config.menuStyle = .pie
        configStore.save()
        rebuildStatusMenu()
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let viewModel = SettingsViewModel(configStore: configStore)
        let settingsView = SettingsView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: settingsView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MiddleClick Menu 设置"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.delegate = self
        NSApp.activate(ignoringOtherApps: true)
        self.settingsWindow = window
    }

    private func updateStatusIcon(enabled: Bool) {
        if let button = statusItem?.button {
            let symbolName = enabled ? "computermouse" : "computermouse.fill"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "MiddleClick Menu")
            button.appearsDisabled = !enabled
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === settingsWindow {
            actionRunner.reloadActions()
            settingsWindow = nil
        }
    }
}
