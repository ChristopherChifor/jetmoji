import AppKit
@preconcurrency import ApplicationServices
import Carbon.HIToolbox

enum PasteService {
    /// NX_DEVICELCMDKEYMASK — required so some apps treat synthesized ⌘V as a real Command press.
    private static let leftCommandDeviceBit = CGEventFlags(rawValue: 0x000008)

    static var canPostEvents: Bool {
        AXIsProcessTrusted() || CGPreflightPostEventAccess()
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
    static func relaunchApp() {
        let path = Bundle.main.bundlePath
        let launcher = Process()
        launcher.executableURL = URL(fileURLWithPath: "/bin/sh")
        launcher.arguments = ["-c", "sleep 0.45; exec /usr/bin/open -n \"$1\"", "--", path]
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

    /// Copy, give the previous app focus back, then synthesize ⌘V into that app.
    @MainActor
    static func copyAndPaste(_ emoji: String) async -> Bool {
        copy(emoji)
        await yieldToFrontApp()
        await waitUntilModifiersReleased()
        if Task.isCancelled { return false }
        guard canPostEvents else {
            requestAccess()
            return false
        }
        return pasteViaCommandV()
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
            let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            if let front, front != JetmojiVersion.bundleID {
                break
            }
            try? await Task.sleep(nanoseconds: 12_000_000)
        }
    }

    private static func waitUntilModifiersReleased() async {
        let deadline = Date().addingTimeInterval(1.2)
        while Date() < deadline {
            if Task.isCancelled { return }
            if !hidModifiersHeld { break }
            try? await Task.sleep(nanoseconds: 12_000_000)
        }
        try? await Task.sleep(nanoseconds: 40_000_000)
    }

    private static var hidModifiersHeld: Bool {
        let flags = CGEventSource.flagsState(.hidSystemState)
        return !flags.isDisjoint(with: [.maskCommand, .maskShift, .maskAlternate, .maskControl])
    }

    private static func pasteViaCommandV() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }
        source.localEventsSuppressionInterval = 0.05
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        liftModifierKeys(source: source)

        let flags: CGEventFlags = [.maskCommand, leftCommandDeviceBit]
        let keyV = CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        else { return false }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
        return true
    }

    private static func liftModifierKeys(source: CGEventSource) {
        let keys: [CGKeyCode] = [
            CGKeyCode(kVK_Command),
            CGKeyCode(kVK_RightCommand),
            CGKeyCode(kVK_Option),
            CGKeyCode(kVK_RightOption),
            CGKeyCode(kVK_Shift),
            CGKeyCode(kVK_RightShift),
            CGKeyCode(kVK_Control),
            CGKeyCode(kVK_RightControl),
        ]
        for key in keys {
            guard let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else { continue }
            up.flags = []
            up.post(tap: .cgSessionEventTap)
        }
    }
}
