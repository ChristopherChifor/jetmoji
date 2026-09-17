import Foundation
import Carbon.HIToolbox

@MainActor
final class HotkeyCenter {
    static let shared = HotkeyCenter()

    private var handler: EventHandlerRef?
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var paused = false
    var onTrigger: ((Int) -> Void)?

    private let signature: OSType = 0x4A544D4A // "JTMJ"

    func start() {
        if handler == nil {
            var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(
                GetApplicationEventTarget(),
                jetmojiCarbonHandler,
                1,
                &type,
                UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                &handler
            )
            if status != noErr {
                NSLog("Jetmoji: could not install hotkey handler (%d)", status)
            }
        }
        reregister()
    }

    func stop() {
        unregisterAll()
        if let handler {
            RemoveEventHandler(handler)
            self.handler = nil
        }
    }

    func pause() {
        paused = true
        unregisterAll()
    }

    func resume() {
        paused = false
        reregister()
    }

    func reregister() {
        unregisterAll()
        guard !paused else { return }
        let store = JetmojiStore.shared
        var failures: [String] = []
        for slot in store.slots where slot.enabled {
            guard let shortcut = slot.resolvedShortcut else { continue }
            var ref: EventHotKeyRef?
            let identifier = EventHotKeyID(signature: signature, id: UInt32(slot.id + 1))
            let status = RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.carbonModifiers,
                identifier,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr, let ref {
                refs[UInt32(slot.id)] = ref
            } else {
                failures.append("Pad \(slot.id) (\(shortcut.displayString))")
            }
        }
        store.hotkeyError = failures.isEmpty ? nil : "Could not register: \(failures.joined(separator: ", ")). Try a different shortcut."
    }

    func handleCarbon(id: UInt32) {
        let slotID = Int(id) - 1
        guard (0..<10).contains(slotID) else { return }
        onTrigger?(slotID)
    }

    private func unregisterAll() {
        for (_, ref) in refs {
            UnregisterEventHotKey(ref)
        }
        refs.removeAll()
    }
}

private func jetmojiCarbonHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    var identifier = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &identifier
    )
    if status != noErr { return OSStatus(eventNotHandledErr) }
    guard identifier.signature == 0x4A544D4A else { return OSStatus(eventNotHandledErr) }
    Task { @MainActor in
        HotkeyCenter.shared.handleCarbon(id: identifier.id)
    }
    return noErr
}
