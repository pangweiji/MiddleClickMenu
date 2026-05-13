import CoreGraphics
import AppKit

class EventEngine {
    typealias MiddleClickHandler = (_ mouseLocation: CGPoint) -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapThread: Thread?
    private var onMiddleClick: MiddleClickHandler?
    private let configStore: ConfigStore

    init(configStore: ConfigStore) {
        self.configStore = configStore
    }

    func start(handler: @escaping MiddleClickHandler) {
        self.onMiddleClick = handler

        tapThread = Thread {
            self.setupEventTap()
            CFRunLoopRun()
        }
        tapThread?.name = "EventEngine.TapThread"
        tapThread?.start()
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource, let tap = eventTap {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.otherMouseDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let engine = Unmanaged<EventEngine>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = engine.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passRetained(event)
            }

            guard type == .otherMouseDown else {
                return Unmanaged.passRetained(event)
            }

            let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
            guard buttonNumber == 2 else {
                return Unmanaged.passRetained(event)
            }

            let location = event.location
            DispatchQueue.main.async {
                if !engine.isCurrentAppBlacklisted() {
                    engine.onMiddleClick?(location)
                }
            }

            return nil
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: selfPtr
        ) else {
            print("[EventEngine] 无法创建 CGEvent Tap，请检查辅助功能权限")
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func isCurrentAppBlacklisted() -> Bool {
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        return configStore.config.blacklistApps.contains(bundleId)
    }
}
