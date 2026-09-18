import AppKit
@preconcurrency import ApplicationServices
import Carbon.HIToolbox

enum PasteService {
    /// NX_DEVICELCMDKEYMASK — some apps ignore ⌘V unless a side of Command is marked.
    private static let leftCommandDeviceBit = CGEventFlags(rawValue: 0x000008)

    static var canPostEvents: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccess() -> Bool {
        let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(prompt)
        if !CGPreflightPostEventAccess() {
            _ = CGRequestPostEventAccess()
        }
        return canPostEvents
    }

    static func openAccessibilitySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
        ]
        for raw in urls {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
    }

    @MainActor
    static func relaunchApp(bundlePath: String = Bundle.main.bundlePath) {
        let launcher = Process()
        launcher.executableURL = URL(fileURLWithPath: "/bin/sh")
        launcher.arguments = ["-c", "sleep 0.45; exec /usr/bin/open -n \"$1\"", "--", bundlePath]
        try? launcher.run()
        NSApp.terminate(nil)
    }

    @MainActor
    static func copy(_ emoji: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(emoji, forType: .string)
        pasteboard.setString(emoji, forType: .init("public.utf8-plain-text"))
    }

    /// Copy, then insert into the app that was focused when the hotkey fired.
    /// Insertion happens immediately — it does not wait for ⌥/⌘ to be released.
    @MainActor
    static func copyAndPaste(_ emoji: String) async -> Bool {
        copy(emoji)
        let targetPID = frontmostForeignPID()
        if NSApp.isActive {
            await yieldToFrontApp()
            if Task.isCancelled { return false }
        }
        guard canPostEvents else {
            requestAccess()
            return false
        }

        if insertViaAccessibility(emoji) {
            return true
        }
        if insertViaUnicode(emoji) {
            return true
        }

        await waitUntilModifiersReleased()
        if Task.isCancelled { return false }
        return pasteViaCommandV(pid: targetPID ?? frontmostForeignPID())
    }

    @MainActor
    static func yieldToFrontApp() async {
        for window in NSApp.windows where window.isVisible && window.styleMask.contains(.titled) {
            window.orderOut(nil)
        }
        if NSApp.isActive {
            NSApp.hide(nil)
        }
        let deadline = Date().addingTimeInterval(0.4)
        while Date() < deadline {
            if Task.isCancelled { return }
            if frontmostForeignPID() != nil { break }
            try? await Task.sleep(nanoseconds: 12_000_000)
        }
    }

    private static func frontmostForeignPID() -> pid_t? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        if pid == ProcessInfo.processInfo.processIdentifier { return nil }
        if app.bundleIdentifier == JetmojiVersion.bundleID { return nil }
        return pid
    }

    private static func waitUntilModifiersReleased() async {
        let deadline = Date().addingTimeInterval(1.2)
        while Date() < deadline {
            if Task.isCancelled { return }
            if !hidModifiersHeld { break }
            try? await Task.sleep(nanoseconds: 8_000_000)
        }
        try? await Task.sleep(nanoseconds: 25_000_000)
    }

    private static var hidModifiersHeld: Bool {
        let flags = CGEventSource.flagsState(.hidSystemState)
        return !flags.isDisjoint(with: [.maskCommand, .maskShift, .maskAlternate, .maskControl])
    }

    private static func insertViaAccessibility(_ string: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success, let focusedRef else { return false }
        let element = focusedRef as! AXUIElement

        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable) == .success,
              settable.boolValue
        else { return false }

        return AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            string as CFTypeRef
        ) == .success
    }

    private static func insertViaUnicode(_ string: String) -> Bool {
        let units = Array(string.utf16)
        guard !units.isEmpty else { return false }
        guard let source = CGEventSource(stateID: .privateState) else { return false }
        source.localEventsSuppressionInterval = 0

        func post(down: Bool) -> Bool {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else { return false }
            event.flags = []
            units.withUnsafeBufferPointer { buffer in
                event.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            }
            event.post(tap: .cghidEventTap)
            return true
        }
        return post(down: true) && post(down: false)
    }

    private static func pasteViaCommandV(pid: pid_t?) -> Bool {
        guard let source = CGEventSource(stateID: .privateState) else { return false }
        source.localEventsSuppressionInterval = 0
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let flags: CGEventFlags = [.maskCommand, leftCommandDeviceBit]
        let cmd = CGKeyCode(kVK_Command)
        let keyV = CGKeyCode(kVK_ANSI_V)

        func post(_ key: CGKeyCode, down: Bool, flags: CGEventFlags) -> Bool {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { return false }
            event.flags = flags
            deliver(event, pid: pid)
            return true
        }

        return post(cmd, down: true, flags: flags)
            && post(keyV, down: true, flags: flags)
            && post(keyV, down: false, flags: flags)
            && post(cmd, down: false, flags: [])
    }

    private static func deliver(_ event: CGEvent, pid: pid_t?) {
        if let pid {
            event.postToPid(pid)
        } else {
            event.post(tap: .cghidEventTap)
        }
    }
}
