import AppKit
import Carbon

@MainActor
enum ClipboardHelper {

    private static var pendingRestore: DispatchWorkItem?

    static func performConversion() {
        // Cancel any pending restore from a previous conversion
        pendingRestore?.cancel()
        pendingRestore = nil
        guard AXIsProcessTrusted() else {
            showAccessibilityAlert()
            return
        }

        let pasteboard = NSPasteboard.general

        // Save current clipboard
        let savedItems: [(types: [NSPasteboard.PasteboardType], data: [(NSPasteboard.PasteboardType, Data)])] = (pasteboard.pasteboardItems ?? []).map { item in
            let data = item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            }
            return (types: item.types, data: data)
        }
        let savedChangeCount = pasteboard.changeCount

        // Simulate Cmd+C to copy selected text
        simulateKey(keyCode: UInt16(kVK_ANSI_C), flags: .maskCommand)

        // Wait for clipboard to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard pasteboard.changeCount != savedChangeCount else {
                // Nothing was selected — nothing to do
                return
            }

            guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
                return
            }

            let converted = TextConverter.convert(text)

            // Write converted text to clipboard
            pasteboard.clearContents()
            pasteboard.setString(converted, forType: .string)

            // Simulate Cmd+V to paste
            simulateKey(keyCode: UInt16(kVK_ANSI_V), flags: .maskCommand)

            if UserDefaults.standard.bool(forKey: "switchInputLanguageOnConversion") {
                let wasHebrew = TextConverter.isHebrew(text)
                switchInputSource(toHebrew: !wasHebrew)
            }

            // Restore original clipboard after paste settles
            let restoreWork = DispatchWorkItem {
                pasteboard.clearContents()
                if savedItems.isEmpty {
                    Self.pendingRestore = nil
                    return
                }
                for savedItem in savedItems {
                    let newItem = NSPasteboardItem()
                    for (type, data) in savedItem.data {
                        newItem.setData(data, forType: type)
                    }
                    pasteboard.writeObjects([newItem])
                }
                Self.pendingRestore = nil
            }
            Self.pendingRestore = restoreWork
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: restoreWork)
        }
    }

    private static func switchInputSource(toHebrew: Bool) {
        let targetLang = toHebrew ? "he" : "en"
        guard let sources = TISCreateInputSourceList(nil, false)?
            .takeRetainedValue() as? [TISInputSource] else { return }
        for source in sources {
            guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages)
            else { continue }
            let langs = Unmanaged<CFArray>.fromOpaque(ptr).takeUnretainedValue() as [AnyObject]
            if let first = langs.first as? String, first.hasPrefix(targetLang) {
                TISSelectInputSource(source)
                return
            }
        }
    }

    private static func simulateKey(keyCode: UInt16, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private static func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "SwitchBack needs Accessibility access. Please enable it in System Settings → Privacy & Security → Accessibility."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
        }
    }
}
