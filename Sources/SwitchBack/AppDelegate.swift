import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotkeyManager: HotkeyManager?
    private var hotkeyRecorder: HotkeyRecorderWindowController?
    private var accessibilityTimer: Timer?
    private var waitingForAccessibility = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()

        hotkeyManager = HotkeyManager()
        if AXIsProcessTrusted() {
            hotkeyManager?.install()
        } else {
            checkAccessibility()
            startAccessibilityPolling()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil)
    }

    private func startAccessibilityPolling() {
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if AXIsProcessTrusted() {
                    self.accessibilityTimer?.invalidate()
                    self.accessibilityTimer = nil
                    self.hotkeyManager?.install()
                }
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "SwitchBack")
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "SwitchBack", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        let changeHotkeyItem = NSMenuItem(title: "Change Hotkey...", action: #selector(changeHotkey), keyEquivalent: "")
        menu.addItem(changeHotkeyItem)

        let (kc, mods) = HotkeyStore.load()
        let hotkeyItem = NSMenuItem(title: "Hotkey: \(HotkeyStore.displayString(keyCode: kc, modifiers: mods))", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        hotkeyItem.tag = 101
        menu.addItem(hotkeyItem)

        let accessibilityItem = NSMenuItem(title: accessibilityStatusTitle(),
                                           action: #selector(openAccessibilitySettings),
                                           keyEquivalent: "")
        accessibilityItem.target = self
        accessibilityItem.tag = 100
        menu.addItem(accessibilityItem)

        let loginItem = NSMenuItem(title: "Launch on Login", action: #selector(toggleLaunchOnLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = LoginItemManager.shared.isEnabled ? .on : .off
        loginItem.tag = 102
        menu.addItem(loginItem)

        let switchLangItem = NSMenuItem(
            title: "Switch Input Language on Conversion",
            action: #selector(toggleSwitchInputLang),
            keyEquivalent: ""
        )
        switchLangItem.target = self
        switchLangItem.state = UserDefaults.standard.bool(forKey: "switchInputLanguageOnConversion") ? .on : .off
        switchLangItem.tag = 103
        menu.addItem(switchLangItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu

        // Update accessibility status when menu opens
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuWillOpen),
            name: NSMenu.didBeginTrackingNotification,
            object: menu
        )
    }

    @objc private func menuWillOpen() {
        if let item = statusItem?.menu?.item(withTag: 100) {
            item.title = accessibilityStatusTitle()
            item.isEnabled = !AXIsProcessTrusted()
        }
        if let item = statusItem?.menu?.item(withTag: 101) {
            let (kc, mods) = HotkeyStore.load()
            item.title = "Hotkey: \(HotkeyStore.displayString(keyCode: kc, modifiers: mods))"
        }
        if let item = statusItem?.menu?.item(withTag: 102) {
            item.state = LoginItemManager.shared.isEnabled ? .on : .off
        }
        if let item = statusItem?.menu?.item(withTag: 103) {
            item.state = UserDefaults.standard.bool(forKey: "switchInputLanguageOnConversion") ? .on : .off
        }
    }

    @objc private func toggleSwitchInputLang() {
        let newValue = !UserDefaults.standard.bool(forKey: "switchInputLanguageOnConversion")
        UserDefaults.standard.set(newValue, forKey: "switchInputLanguageOnConversion")
        statusItem?.menu?.item(withTag: 103)?.state = newValue ? .on : .off
    }

    @objc private func toggleLaunchOnLogin() {
        let newValue = !LoginItemManager.shared.isEnabled
        LoginItemManager.shared.setEnabled(newValue)
        if let item = statusItem?.menu?.item(withTag: 102) {
            item.state = newValue ? .on : .off
        }
    }

    @objc private func changeHotkey() {
        if hotkeyRecorder == nil {
            hotkeyRecorder = HotkeyRecorderWindowController()
            hotkeyRecorder?.hotkeyManager = hotkeyManager
            hotkeyRecorder?.onSave = { [weak self] in
                guard let self else { return }
                if let item = self.statusItem?.menu?.item(withTag: 101) {
                    let (kc, mods) = HotkeyStore.load()
                    item.title = "Hotkey: \(HotkeyStore.displayString(keyCode: kc, modifiers: mods))"
                }
                self.hotkeyRecorder = nil
            }
        }
        hotkeyRecorder?.showWindow(nil)
    }

    private func accessibilityStatusTitle() -> String {
        AXIsProcessTrusted() ? "Accessibility: Granted ✓" : "Accessibility: Not Granted ✗"
    }

    private func checkAccessibility() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        waitingForAccessibility = true
    }

    @objc private func appDidTerminate(_ notif: Notification) {
        guard waitingForAccessibility else { return }
        guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication,
              app.bundleIdentifier == "com.apple.systempreferences" else { return }

        if AXIsProcessTrusted() {
            waitingForAccessibility = false
            accessibilityTimer?.invalidate()
            accessibilityTimer = nil
            hotkeyManager?.install()
        } else {
            relaunchApp()
        }
    }

    private func relaunchApp() {
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    @objc private func openAccessibilitySettings() {
        guard !AXIsProcessTrusted() else { return }
        checkAccessibility()
    }
}
