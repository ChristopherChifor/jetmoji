import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: JetmojiStore
    var onCopy: (Int) -> Void
    var onSettings: () -> Void
    var onQuit: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(store.slots) { slot in
                    PadButton(
                        slot: slot,
                        isLast: store.lastUsedSlotID == slot.id,
                        collision: store.collidingIDs.contains(slot.id)
                    ) {
                        onCopy(slot.id)
                    }
                }
            }
            footer
        }
        .padding(16)
        .frame(width: 340)
        .background(JetmojiTheme.ink)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [JetmojiTheme.flame, JetmojiTheme.sky], startPoint: .bottomLeading, endPoint: .topTrailing))
                    .frame(width: 28, height: 28)
                Text("✈︎")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("jetmoji")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(JetmojiTheme.text)
                Text("Ten pads. Instant paste.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(JetmojiTheme.mute)
            }
            Spacer()
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !store.canPaste {
                PermissionBanner()
            }
            if let error = store.hotkeyError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(JetmojiTheme.flame)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let id = store.lastUsedSlotID, let slot = store.slot(id: id) {
                        Text("Clipboard: \(slot.emoji)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(JetmojiTheme.sky)
                    } else {
                        Text("Click a pad to copy. Hotkeys paste anywhere.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(JetmojiTheme.mute)
                    }
                }
                Spacer()
                Button("Settings") { onSettings() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(JetmojiTheme.sky)
                Button("Quit") { onQuit() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(JetmojiTheme.mute)
            }
        }
        .padding(.top, 4)
        .overlay(alignment: .top) {
            Rectangle().fill(JetmojiTheme.line).frame(height: 1)
        }
        .padding(.top, 8)
    }
}

struct PadButton: View {
    let slot: EmojiSlot
    let isLast: Bool
    let collision: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(slot.emoji)
                    .font(.system(size: 28))
                    .grayscale(slot.enabled ? 0 : 0.9)
                    .opacity(slot.enabled ? 1 : 0.45)
                Text(slot.resolvedShortcut?.displayString ?? "—")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(collision ? JetmojiTheme.flame : JetmojiTheme.mute)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isLast ? JetmojiTheme.sky.opacity(0.16) : JetmojiTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isLast ? JetmojiTheme.sky.opacity(0.7) : JetmojiTheme.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var helpText: String {
        let key = slot.resolvedShortcut?.displayString ?? "no shortcut"
        return "Pad \(slot.id)  \(slot.emoji)  \(key)"
    }
}

struct PermissionBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add /Applications/Jetmoji.app with the + button in Accessibility (a leftover Jetmoji row from an older build will not paste). Then Quit & Reopen.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(JetmojiTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Allow Accessibility") {
                    PasteService.requestAccess()
                    PasteService.openAccessibilitySettings()
                    JetmojiStore.shared.refreshPasteAccess()
                }
                .buttonStyle(.borderedProminent)
                .tint(JetmojiTheme.flame)
                .controlSize(.small)
                Button("Quit & Reopen") {
                    PasteService.relaunchApp()
                }
                .controlSize(.small)
                Spacer()
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(JetmojiTheme.flame.opacity(0.14))
        )
    }
}
