import Foundation

enum CLI {
    static let commands: Set<String> = [
        "status", "paste", "set", "list", "reset", "settings", "help",
    ]

    static func run(arguments: [String]) {
        let args = arguments.filter { $0 != "--cli" }
        let command = args.first ?? "help"
        switch command {
        case "help", "--help", "-h":
            print(helpText)
            exit(0)
        case "status":
            status()
        case "list":
            list()
        case "paste":
            guard let id = parseSlot(args.dropFirst().first) else {
                fail("usage: jetmoji paste <0-9>")
                return
            }
            notify(JetmojiVersion.notificationPaste, object: String(id))
            print("{\"ok\":true,\"slot\":\(id)}")
            exit(0)
        case "set":
            guard let id = parseSlot(args.dropFirst().first),
                  let emoji = args.dropFirst(2).first,
                  let normalized = SlotText.normalizedEmoji(emoji)
            else {
                fail("usage: jetmoji set <0-9> <emoji>")
                return
            }
            setEmoji(id: id, emoji: normalized)
        case "reset":
            reset()
        case "settings":
            notify(JetmojiVersion.notificationReload, object: "settings")
            print("{\"ok\":true,\"hint\":\"Open Jetmoji from the menu bar, then click Settings.\"}")
            exit(0)
        default:
            fail("unknown command \(command)\n\n\(helpText)")
        }
    }

    private static func status() {
        let config = JetmojiConfig.loadForCLI()
        let ready = config.slots.filter(\.enabled).map { slot in
            let shortcut = slot.resolvedShortcut?.displayString ?? "None"
            return "{\"id\":\(slot.id),\"emoji\":\"\(jsonEscape(slot.emoji))\",\"shortcut\":\"\(jsonEscape(shortcut))\"}"
        }
        print("{\"version\":\"\(JetmojiVersion.short)\",\"accessibility\":\(PasteService.canPostEvents ? "true" : "false"),\"pads\":[\(ready.joined(separator: ","))]}")
        exit(0)
    }

    private static func list() {
        status()
    }

    private static func setEmoji(id: Int, emoji: String) {
        var config = JetmojiConfig.loadForCLI()
        config.normalize()
        if let index = config.slots.firstIndex(where: { $0.id == id }) {
            config.slots[index].emoji = emoji
        }
        do {
            try JetmojiStore.save(config, to: JetmojiPaths.configURL())
            notify(JetmojiVersion.notificationReload, object: nil)
            print("{\"ok\":true,\"id\":\(id),\"emoji\":\"\(jsonEscape(emoji))\"}")
            exit(0)
        } catch {
            fail(error.localizedDescription)
        }
    }

    private static func reset() {
        do {
            try JetmojiStore.save(.defaults(), to: JetmojiPaths.configURL())
            notify(JetmojiVersion.notificationReload, object: nil)
            print("{\"ok\":true}")
            exit(0)
        } catch {
            fail(error.localizedDescription)
        }
    }

    private static func parseSlot(_ raw: String?) -> Int? {
        guard let raw, let value = Int(raw), (0..<10).contains(value) else { return nil }
        return value
    }

    private static func notify(_ name: Notification.Name, object: String?) {
        DistributedNotificationCenter.default().postNotificationName(
            name,
            object: object,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    private static func jsonEscape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func fail(_ message: String) {
        fputs(message + "\n", stderr)
        exit(2)
    }

    static let helpText = """
    Jetmoji CLI — ten emoji pads, always ready.

      jetmoji status          JSON of the current pads
      jetmoji paste 0         Paste pad 0 into the front app (app must be running)
      jetmoji set 0 😂        Change pad 0's emoji
      jetmoji reset           Restore the default pads and shortcuts
      jetmoji help

    Global shortcuts default to ⌥⌘0 through ⌥⌘9. Rebind them in Settings.
    """
}

extension JetmojiConfig {
    static func loadForCLI() -> JetmojiConfig {
        guard let url = try? JetmojiPaths.configURL() else { return .defaults() }
        return JetmojiStore.load(from: url)
    }
}
