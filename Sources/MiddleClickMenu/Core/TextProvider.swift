import AppKit
import ApplicationServices

class TextProvider {
    func getSelectedText() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        AXUIElementSetMessagingTimeout(axApp, 0.5)

        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success, let element = focusedElement else {
            return nil
        }

        let axElement = element as! AXUIElement
        AXUIElementSetMessagingTimeout(axElement, 0.5)

        var selectedText: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        guard textResult == .success, let text = selectedText as? String, !text.isEmpty else {
            return nil
        }

        return text
    }

    func getSelectedTextAsync(completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let text = self.getSelectedText()
            DispatchQueue.main.async {
                completion(text)
            }
        }
    }

    static func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
