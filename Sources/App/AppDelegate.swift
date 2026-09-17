import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = JetmojiStore.shared
    var statusItem: StatusItemController?
    private var settings: SettingsWindowController?
    private var observers: [NSObjectProtocol] = []
    private var accessTimer: Timer?
    private var pasteTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        LoginItem.syncFromConfig(store.config.openAtLogin)

        let status = StatusItemController(store: store)
        status.onOpenSettings = { [weak self] in self?.showSettings() }
        status.onQuit = { NSApp.terminate(nil) }
        statusItem = status

        HotkeyCenter.shared.onTrigger = { [weak self] id in
            self?.pasteSlot(id: id, fromHotkey: true)
        }
        HotkeyCenter.shared.start()
        store.refreshPasteAccess()

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.store.refreshPasteAccess()
            }
        }
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        accessTimer = timer

        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.store.refreshPasteAccess()
                }
            }
        )

        observers.append(
            DistributedNotificationCenter.default().addObserver(
                forName: JetmojiVersion.notificationPaste,
                object: nil,
                queue: .main
            ) { note in
                let object = note.object as? String
                Task { @MainActor in
                    guard let delegate = NSApp.delegate as? AppDelegate,
                          let object, let id = Int(object) else { return }
                    delegate.pasteSlot(id: id, fromHotkey: true)
                }
            }
        )
        observers.append(
            DistributedNotificationCenter.default().addObserver(
                forName: JetmojiVersion.notificationReload,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    guard let delegate = NSApp.delegate as? AppDelegate else { return }
                    delegate.store.reloadFromDisk()
                    HotkeyCenter.shared.reregister()
                    delegate.statusItem?.reload()
                }
            }
        )

        if !store.canPaste {
            // First launch: show the popover so the permission path is obvious.
            status.showPopover()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pasteTask?.cancel()
        accessTimer?.invalidate()
        HotkeyCenter.shared.stop()
        observers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    func showSettings() {
        if settings == nil {
            settings = SettingsWindowController(store: store)
            settings?.onChange = {
                HotkeyCenter.shared.reregister()
            }
        }
        settings?.show()
    }

    func pasteSlot(id: Int, fromHotkey: Bool) {
        guard let slot = store.slot(id: id), slot.enabled else { return }
        store.markCopied(slotID: id)
        if fromHotkey {
            statusItem?.closePopover()
            let emoji = slot.emoji
            pasteTask?.cancel()
            pasteTask = Task { @MainActor in
                let pasted = await PasteService.copyAndPaste(emoji)
                guard !Task.isCancelled else { return }
                statusItem?.flash(emoji: emoji)
                if pasted {
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                }
            }
        } else {
            PasteService.copy(slot.emoji)
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        statusItem?.reload()
    }
}
