import AppKit
import CoreText
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let store: JetmojiStore
    private let item: NSStatusItem
    private let popover = NSPopover()
    private var hosting: NSHostingController<PopoverView>?
    private var flashWork: DispatchWorkItem?
    private var clickMonitor: Any?
    private var localMonitor: Any?
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
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        startDismissMonitors()
    }

    func closePopover() {
        stopDismissMonitors()
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        stopDismissMonitors()
    }

    func popoverDidShow(_ notification: Notification) {
        popover.contentViewController?.view.window?.makeKey()
        startDismissMonitors()
    }

    private func startDismissMonitors() {
        stopDismissMonitors()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePopover()
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                self.closePopover()
                return nil
            }
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                if self.shouldDismissFromLocalClick(event) {
                    self.closePopover()
                }
            }
            return event
        }
    }

    private func shouldDismissFromLocalClick(_ event: NSEvent) -> Bool {
        guard popover.isShown else { return false }
        if event.window == item.button?.window { return false }
        if event.window == popover.contentViewController?.view.window { return false }
        return true
    }

    private func stopDismissMonitors() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
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
        let image = NSImage(size: NSSize(width: 18, height: 18))
        if let one = templateRep(pixels: 18) {
            one.size = NSSize(width: 18, height: 18)
            image.addRepresentation(one)
        }
        if let two = templateRep(pixels: 36) {
            two.size = NSSize(width: 18, height: 18)
            image.addRepresentation(two)
        }
        image.isTemplate = true
        return image
    }

    private static func templateRep(pixels: Int) -> NSBitmapImageRep? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        rep.size = NSSize(width: pixels, height: pixels)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        drawGlyph(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        convertToTemplate(rep)
        return rep
    }

    private static func drawGlyph(in rect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let font = CTFontCreateWithName("Apple Color Emoji" as CFString, rect.width * 0.92, nil)
        let attributed = NSAttributedString(string: "😂", attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed)
        ctx.textPosition = .zero
        let ink = CTLineGetImageBounds(line, ctx)
        ctx.textPosition = CGPoint(x: rect.midX - ink.midX, y: rect.midY - ink.midY)
        CTLineDraw(line, ctx)
    }

    private static func convertToTemplate(_ rep: NSBitmapImageRep) {
        guard let data = rep.bitmapData else { return }
        let spp = max(rep.samplesPerPixel, 4)
        let bpr = rep.bytesPerRow
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                let i = y * bpr + x * spp
                let a = Double(data[i + 3]) / 255
                if a < 0.02 {
                    data[i] = 0
                    data[i + 1] = 0
                    data[i + 2] = 0
                    data[i + 3] = 0
                    continue
                }
                let r = min(1, Double(data[i]) / 255 / a)
                let g = min(1, Double(data[i + 1]) / 255 / a)
                let b = min(1, Double(data[i + 2]) / 255 / a)
                let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
                let coverage = a * (0.16 + 0.84 * (1 - luma))
                data[i] = 0
                data[i + 1] = 0
                data[i + 2] = 0
                data[i + 3] = UInt8(clamping: Int((coverage * 255).rounded()))
            }
        }
    }
}
