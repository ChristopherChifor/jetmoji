import Foundation

struct EmojiSlot: Identifiable, Codable, Equatable, Sendable {
    var id: Int
    var emoji: String
    var enabled: Bool
    var shortcut: Shortcut?

    var resolvedShortcut: Shortcut? {
        guard let shortcut, !shortcut.isEmpty else { return nil }
        return shortcut
    }
}

struct JetmojiConfig: Codable, Equatable, Sendable {
    var version: Int
    var openAtLogin: Bool
    var slots: [EmojiSlot]

    static let currentVersion = 1

    static let defaultEmojis = ["😂", "❤️", "🔥", "👍", "🙏", "✨", "💀", "😭", "🎉", "👀"]

    static func defaults() -> JetmojiConfig {
        let slots = (0..<10).map { index in
            EmojiSlot(
                id: index,
                emoji: defaultEmojis[index],
                enabled: true,
                shortcut: Shortcut.defaultShortcut(forSlot: index)
            )
        }
        return JetmojiConfig(version: currentVersion, openAtLogin: true, slots: slots)
    }

    mutating func normalize() {
        version = Self.currentVersion
        let byID = Dictionary(uniqueKeysWithValues: slots.map { ($0.id, $0) })
        slots = (0..<10).map { index in
            var slot = byID[index] ?? EmojiSlot(
                id: index,
                emoji: Self.defaultEmojis[index],
                enabled: true,
                shortcut: Shortcut.defaultShortcut(forSlot: index)
            )
            slot.id = index
            slot.emoji = SlotText.normalizedEmoji(slot.emoji) ?? Self.defaultEmojis[index]
            return slot
        }
    }

    func collidingShortcutIDs() -> [Int] {
        var seen: [Shortcut: Int] = [:]
        var collisions: Set<Int> = []
        for slot in slots where slot.enabled {
            guard let shortcut = slot.resolvedShortcut else { continue }
            if let existing = seen[shortcut] {
                collisions.insert(existing)
                collisions.insert(slot.id)
            } else {
                seen[shortcut] = slot.id
            }
        }
        return collisions.sorted()
    }
}

enum SlotText {
    static func normalizedEmoji(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return nil }
        return String(first)
    }
}

enum JetmojiPaths {
    static func supportDirectory() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent("Jetmoji", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func configURL() throws -> URL {
        try supportDirectory().appendingPathComponent("config.json")
    }
}
