import Carbon.HIToolbox
import Foundation

struct SelfTests {
    enum Failure: Error, CustomStringConvertible {
        case message(String)
        var description: String {
            switch self {
            case .message(let text): return text
            }
        }
    }

    static func run() throws {
        try testDefaultsHaveTenPads()
        try testNormalizeFillsGaps()
        try testEmojiNormalization()
        try testShortcutRoundTrip()
        try testCollisionDetection()
        try testConfigRoundTrip()
        try testUseCountRoundTrip()
        try testLegacyConfigDefaultsUseCount()
        try testUpdaterUsesSiteInstall()
    }

    private static func testDefaultsHaveTenPads() throws {
        let config = JetmojiConfig.defaults()
        try expect(config.slots.count == 10, "defaults should have 10 pads")
        try expect(config.slots.map(\.id) == Array(0..<10), "pads should be 0...9")
        try expect(config.slots[0].emoji == "😂", "pad 0 should default to laughing")
        try expect(config.slots.allSatisfy { $0.resolvedShortcut != nil }, "every default pad should have a shortcut")
    }

    private static func testNormalizeFillsGaps() throws {
        var config = JetmojiConfig(version: 0, openAtLogin: false, slots: [
            EmojiSlot(id: 3, emoji: "🚀", enabled: true, shortcut: nil),
        ])
        config.normalize()
        try expect(config.slots.count == 10, "normalize should expand to 10 pads")
        try expect(config.slots[3].emoji == "🚀", "existing pad should be kept")
        try expect(config.slots[0].emoji == "😂", "missing pads should use defaults")
    }

    private static func testEmojiNormalization() throws {
        try expect(SlotText.normalizedEmoji("  😂🔥") == "😂", "should keep the first grapheme")
        try expect(SlotText.normalizedEmoji("   ") == nil, "blank should be nil")
        try expect(SlotText.normalizedEmoji("🇺🇸x") == "🇺🇸", "flag emoji is one grapheme")
        try expect(SlotText.emojiFromEdit(previous: "😂", draft: "😂🔥") == "🔥", "paste after the current emoji should keep the new one")
        try expect(SlotText.emojiFromEdit(previous: "😂", draft: "🔥") == "🔥", "replacing the field should keep the pasted emoji")
        try expect(SlotText.emojiFromEdit(previous: "😂", draft: "🚀😂") == "🚀", "typing before the current emoji should keep the new one")
        try expect(SlotText.emojiFromPaste("copy this 🚀 please") == "🚀", "clipboard text should yield the emoji")
        try expect(SlotText.emojiFromPaste("https://example.com") == nil, "plain text should not become a pad")
        try expect(SlotText.emojiFromPaste("  ❤️  ") == "❤️", "a lone heart should paste")
        try expect(SlotText.emojiFromPaste("🇺🇸") == "🇺🇸", "a flag should paste as one emoji")
    }

    private static func testShortcutRoundTrip() throws {
        let original = Shortcut.defaultShortcut(forSlot: 0)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Shortcut.self, from: data)
        try expect(decoded == original, "shortcut should round-trip")
        try expect(original.displayString.contains("⌘"), "default shortcut should include command")
        try expect(original.displayString.contains("⌥"), "default shortcut should include option")
        try expect(original.displayString.contains("0"), "slot 0 should use the 0 key")
    }

    private static func testCollisionDetection() throws {
        var config = JetmojiConfig.defaults()
        config.slots[1].shortcut = config.slots[0].shortcut
        let collisions = config.collidingShortcutIDs()
        try expect(collisions.contains(0) && collisions.contains(1), "duplicate shortcuts should collide")
    }

    private static func testConfigRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("jetmoji-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        var config = JetmojiConfig.defaults()
        config.slots[2].emoji = "🚀"
        config.slots[2].shortcut = Shortcut(keyCode: 0, carbonModifiers: UInt32(cmdKey | shiftKey))
        try JetmojiStore.save(config, to: url)
        let loaded = JetmojiStore.load(from: url)
        try expect(loaded.slots[2].emoji == "🚀", "saved emoji should reload")
        try expect(loaded.slots[2].shortcut?.keyCode == 0, "saved shortcut should reload")
    }

    private static func testUseCountRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("jetmoji-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        var config = JetmojiConfig.defaults()
        config.slots[0].useCount = 12
        config.slots[4].useCount = 1
        try JetmojiStore.save(config, to: url)
        let loaded = JetmojiStore.load(from: url)
        try expect(loaded.slots[0].useCount == 12, "saved use count should reload")
        try expect(loaded.slots[4].useCount == 1, "single use should reload")
        try expect(loaded.slots[1].useCount == 0, "untouched pads should stay at 0")
    }

    private static func testLegacyConfigDefaultsUseCount() throws {
        let json = """
        {"openAtLogin":true,"slots":[{"emoji":"😂","enabled":true,"id":0,"shortcut":{"carbonModifiers":2048,"keyCode":29}}],"version":1}
        """
        var decoded = try JSONDecoder().decode(JetmojiConfig.self, from: Data(json.utf8))
        decoded.normalize()
        try expect(decoded.slots[0].useCount == 0, "legacy pads should start at 0 uses")
        try expect(decoded.slots[0].emoji == "😂", "legacy emoji should still load")
        try expect(decoded.slots.count == 10, "legacy configs should still normalize to 10 pads")
    }

    private static func testUpdaterUsesSiteInstall() throws {
        try expect(AppUpdater.scriptURL == "https://jetmoji.fun/install.sh", "updater should use the site install script")
        try expect(AppUpdater.installedAppPath == "/Applications/Jetmoji.app", "updater should relaunch the installed app")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if !condition { throw Failure.message(message) }
    }
}
