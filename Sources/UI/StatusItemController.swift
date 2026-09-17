import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let store: JetmojiStore
    private let item: NSStatusItem
    private let popover = NSPopover()
    private var hosting: NSHostingController<PopoverView>?
    private var flashWork: DispatchWorkItem?
    private let menu = NSMenu()

    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    init(store: JetmojiStore) {
        self.store = store
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = item.button {
            button.image = Self.statusImage()
            button.imagePosition = .imageOnly
            button.toolTip = "Jetmoji"
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let root = PopoverView(
            store: store,
            onCopy: { [weak self] id in
                guard let delegate = NSApp.delegate as? AppDelegate else { return }
                delegate.pasteSlot(id: id, fromHotkey: false)
                self?.reload()
            },
            onSettings: { [weak self] in
                self?.closePopover()
                self?.onOpenSettings?()
            },
            onQuit: { [weak self] in self?.onQuit?() }
        )
        let controller = NSHostingController(rootView: root)
        controller.sizingOptions = [.preferredContentSize]
        hosting = controller
        popover.contentSize = NSSize(width: 340, height: 430)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = controller

        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Jetmoji", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
    }

    func reload() {
        if let hosting {
            hosting.rootView = PopoverView(
                store: store,
                onCopy: { [weak self] id in
                    guard let delegate = NSApp.delegate as? AppDelegate else { return }
                    delegate.pasteSlot(id: id, fromHotkey: false)
                    self?.reload()
                },
                onSettings: { [weak self] in
                    self?.closePopover()
                    self?.onOpenSettings?()
                },
                onQuit: { [weak self] in self?.onQuit?() }
            )
        }
    }

    func showPopover() {
        guard let button = item.button else { return }
        reload()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closePopover() {
        popover.performClose(nil)
    }

    func flash(emoji: String) {
        flashWork?.cancel()
        guard let button = item.button else { return }
        button.image = nil
        button.title = emoji
        button.imagePosition = .noImage
        let work = DispatchWorkItem { [weak self] in
            guard let self, let button = self.item.button else { return }
            button.title = ""
            button.image = Self.statusImage()
            button.imagePosition = .imageOnly
        }
        flashWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: work)
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            item.menu = menu
            item.button?.performClick(nil)
            item.menu = nil
            return
        }
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func quit() {
        onQuit?()
    }

    private static func statusImage() -> NSImage {
        if let url = Bundle.main.url(forResource: "StatusItem", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 3, y: 5))
            path.line(to: NSPoint(x: 15, y: 9))
            path.line(to: NSPoint(x: 3, y: 13))
            path.line(to: NSPoint(x: 6, y: 9))
            path.close()
            NSColor.black.setFill()
            path.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
