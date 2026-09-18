import Foundation

struct EmojiSlot: Identifiable, Equatable, Sendable {
    var id: Int
    var emoji: String
    var enabled: Bool
    var shortcut: Shortcut?
    var useCount: Int = 0

    var resolvedShortcut: Shortcut? {
        guard let shortcut, !shortcut.isEmpty else { return nil }
        return shortcut
    }
}

extension EmojiSlot: Codable {
    enum CodingKeys: String, CodingKey {
        case id, emoji, enabled, shortcut, useCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        emoji = try container.decode(String.self, forKey: .emoji)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        shortcut = try container.decodeIfPresent(Shortcut.self, forKey: .shortcut)
        useCount = try container.decodeIfPresent(Int.self, forKey: .useCount) ?? 0
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
        firstGrapheme(raw)
    }

    /// Keep a newly typed or pasted emoji instead of the one already in the field.
    static func emojiFromEdit(previous: String, draft: String) -> String? {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed == previous { return previous }

        if !previous.isEmpty, trimmed.hasPrefix(previous) {
            return firstGrapheme(String(trimmed.dropFirst(previous.count)))
        }
        if !previous.isEmpty, trimmed.hasSuffix(previous) {
            return firstGrapheme(String(trimmed.dropLast(previous.count)))
        }
        return emojiFromPaste(trimmed) ?? firstGrapheme(trimmed)
    }

    static func emojiFromPaste(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let graphemes = trimmed.map(String.init)
        if graphemes.count == 1 { return graphemes[0] }
        return graphemes.first(where: isEmojiGrapheme)
    }

    static func firstGrapheme(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return nil }
        return String(first)
    }

    static func isEmojiGrapheme(_ grapheme: String) -> Bool {
        guard let character = grapheme.first, grapheme.count == 1 else { return false }
        let scalars = character.unicodeScalars
        return scalars.contains { $0.properties.isEmojiPresentation }
            || (scalars.contains { $0.properties.isEmoji } && scalars.count > 1)
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
