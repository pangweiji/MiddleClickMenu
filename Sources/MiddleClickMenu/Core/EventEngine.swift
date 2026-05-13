import CoreGraphics
import AppKit

class EventEngine {
    typealias MiddleClickHandler = (_ mouseLocation: CGPoint) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var onMiddleClick: MiddleClickHandler?
    private let configStore: ConfigStore

    init(configStore: ConfigStore) {
        self.configStore = configStore
    }

    func start(handler: @escaping MiddleClickHandler) {
        self.onMiddleClick = handler
        setupEventTap()
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func setupEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.otherMouseDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon = refcon else {
                return Unmanaged.passUnretained(event)
            }
            let engine = Unmanaged<EventEngine>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = engine.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .otherMouseDown else {
                return Unmanaged.passUnretained(event)
            }

            let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
            guard buttonNumber == 2 else {
                return Unmanaged.passUnretained(event)
            }

            print("[EventEngine] 中键点击检测到")

            let location = event.location
            DispatchQueue.main.async {
                print("[EventEngine] 分发到主线程")
                engine.onMiddleClick?(location)
            }

            return nil
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        ) else {
            print("[EventEngine] 无法创建 CGEvent Tap，请检查辅助功能权限")
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[EventEngine] 事件 Tap 已启动")
    }

    func isCurrentAppBlacklisted() -> Bool {
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        return configStore.config.blacklistApps.contains(bundleId)
    }
}
