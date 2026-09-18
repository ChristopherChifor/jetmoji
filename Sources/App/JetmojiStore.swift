import AppKit
import Combine
import Foundation
import ServiceManagement

@MainActor
final class JetmojiStore: ObservableObject {
    static let shared = JetmojiStore()

    @Published private(set) var config: JetmojiConfig
    @Published var lastUsedSlotID: Int?
    @Published var lastCopiedAt: Date?
    @Published var hotkeyError: String?
    @Published var recordingSlotID: Int?
    @Published var canPaste = false

    let fileURL: URL
    private var skipSave = false

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? (try? JetmojiPaths.configURL()) ?? FileManager.default.temporaryDirectory.appendingPathComponent("jetmoji-config.json")
        self.config = Self.load(from: self.fileURL)
        self.config.normalize()
        self.canPaste = PasteService.canPostEvents
    }

    func refreshPasteAccess() {
        canPaste = PasteService.canPostEvents
    }

    var slots: [EmojiSlot] { config.slots }

    var collidingIDs: Set<Int> { Set(config.collidingShortcutIDs()) }

    func slot(id: Int) -> EmojiSlot? {
        config.slots.first { $0.id == id }
    }

    func updateSlot(id: Int, mutate: (inout EmojiSlot) -> Void) {
        guard let index = config.slots.firstIndex(where: { $0.id == id }) else { return }
        mutate(&config.slots[index])
        config.slots[index].emoji = SlotText.normalizedEmoji(config.slots[index].emoji) ?? JetmojiConfig.defaultEmojis[id]
        persist()
    }

    func setEmoji(_ emoji: String, for id: Int) {
        updateSlot(id: id) { $0.emoji = emoji }
    }

    func setShortcut(_ shortcut: Shortcut?, for id: Int) {
        updateSlot(id: id) { $0.shortcut = shortcut }
    }

    func setEnabled(_ enabled: Bool, for id: Int) {
        updateSlot(id: id) { $0.enabled = enabled }
    }

    func restoreDefaults() {
        let login = config.openAtLogin
        config = .defaults()
        config.openAtLogin = login
        persist()
    }

    func setOpenAtLogin(_ enabled: Bool) {
        config.openAtLogin = enabled
        persist()
        LoginItem.setEnabled(enabled)
    }

    func markCopied(slotID: Int) {
        lastUsedSlotID = slotID
        lastCopiedAt = Date()
        updateSlot(id: slotID) { $0.useCount += 1 }
    }

    func reloadFromDisk() {
        skipSave = true
        config = Self.load(from: fileURL)
        config.normalize()
        skipSave = false
        objectWillChange.send()
    }

    func persist() {
        guard !skipSave else { return }
        do {
            try Self.save(config, to: fileURL)
        } catch {
            hotkeyError = "Could not save Jetmoji settings: \(error.localizedDescription)"
        }
    }

    nonisolated static func load(from url: URL) -> JetmojiConfig {
        guard let data = try? Data(contentsOf: url) else { return .defaults() }
        do {
            var decoded = try JSONDecoder().decode(JetmojiConfig.self, from: data)
            decoded.normalize()
            return decoded
        } catch {
            return .defaults()
        }
    }

    nonisolated static func save(_ config: JetmojiConfig, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

enum LoginItem {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Jetmoji login item error: \(error.localizedDescription)")
        }
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func syncFromConfig(_ enabled: Bool) {
        if enabled && !isEnabled {
            setEnabled(true)
        }
    }
}
