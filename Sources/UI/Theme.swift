import SwiftUI

enum JetmojiTheme {
    static let ink = Color(red: 0.06, green: 0.07, blue: 0.10)
    static let panel = Color(red: 0.11, green: 0.12, blue: 0.16)
    static let line = Color.white.opacity(0.08)
    static let sky = Color(red: 0.36, green: 0.88, blue: 1.0)
    static let flame = Color(red: 1.0, green: 0.42, blue: 0.18)
    static let text = Color.white.opacity(0.92)
    static let mute = Color.white.opacity(0.55)

    static let palette: [String] = [
        "😂", "😭", "😍", "🥰", "😊", "🥹", "😅", "😎", "🤔", "😴",
        "💀", "🔥", "✨", "❤️", "💔", "💯", "⭐", "🎉", "🙏", "👍",
        "👎", "👀", "🫡", "🤝", "💪", "🚀", "✈️", "🌈", "🍕", "☕",
        "✅", "❌", "⚠️", "💡", "🎵", "🏆", "🫶", "😘", "😜", "🙃",
        "😏", "😤", "🥺", "😡", "🤩", "😇", "🙈", "💬", "📌", "🍀",
    ]
}
