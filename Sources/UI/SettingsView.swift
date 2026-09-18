import AppKit
import Carbon.HIToolbox
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: JetmojiStore
    var onChange: () -> Void
    @State private var restoredDefaults = false
    @State private var updatingApp = false
    @State private var updateFailed = false
    @State private var updateMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                padsCard
                permissionsCard
                generalCard
            }
            .padding(22)
        }
        .frame(minWidth: 520, minHeight: 620)
        .background(JetmojiTheme.ink)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 40, height: 40)
                Text("😂")
                    .font(.system(size: 26))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Jetmoji")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(JetmojiTheme.text)
                Text("v\(JetmojiVersion.short)  ·  \(JetmojiVersion.site.replacingOccurrences(of: "https://", with: ""))")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(JetmojiTheme.mute)
            }
            Spacer()
        }
    }

    private var padsCard: some View {
        SettingsCard(title: "Pads", subtitle: "Ten always-ready emojis. A shortcut pastes immediately and leaves that emoji on the clipboard.") {
            VStack(spacing: 0) {
                ForEach(store.slots) { slot in
                    SlotEditorRow(slot: slot, store: store, onChange: {
                        restoredDefaults = false
                        onChange()
                    })
                    if slot.id < 9 {
                        Divider().overlay(JetmojiTheme.line)
                    }
                }
            }
        }
    }

    private var permissionsCard: some View {
        SettingsCard(title: "Permissions", subtitle: "Each hotkey copies the emoji and pastes it into the app you were typing in. You can press it again and again.") {
            HStack {
                Circle()
                    .fill(store.canPaste ? Color.green : JetmojiTheme.flame)
                    .frame(width: 8, height: 8)
                Text(store.canPaste
                     ? "Accessibility is on. ⌥⌘0–9 insert instantly."
                     : "Turn Jetmoji on in Accessibility, then Quit & Reopen. Until then, hotkeys only copy.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(JetmojiTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            HStack {
                Button("Allow…") {
                    PasteService.requestAccess()
                    PasteService.openAccessibilitySettings()
                    store.refreshPasteAccess()
                }
                Button("Retry") {
                    store.refreshPasteAccess()
                    onChange()
                }
                if !store.canPaste {
                    Button("Quit & Reopen") {
                        PasteService.relaunchApp()
                    }
                }
                Spacer()
            }
            if let error = store.hotkeyError {
                Text(error)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(JetmojiTheme.flame)
            }
            if !store.collidingIDs.isEmpty {
                Text("Pads \(store.collidingIDs.sorted().map(String.init).joined(separator: ", ")) share the same shortcut.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(JetmojiTheme.flame)
            }
        }
    }

    private var generalCard: some View {
        SettingsCard(title: "General", subtitle: "Jetmoji lives in the menu bar and stays out of the Dock.") {
            Toggle("Open at login", isOn: Binding(
                get: { store.config.openAtLogin },
                set: { store.setOpenAtLogin($0) }
            ))
            .toggleStyle(.switch)
            .foregroundStyle(JetmojiTheme.text)

            HStack {
                if restoredDefaults {
                    Button("Default pads restored") {}
                        .disabled(true)
                } else {
                    Button("Restore default pads") {
                        store.restoreDefaults()
                        restoredDefaults = true
                        onChange()
                    }
                    .disabled(updatingApp)
                }

                if updatingApp {
                    ProgressView()
                        .controlSize(.small)
                    Text("Updating…")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(JetmojiTheme.mute)
                } else {
                    Button("Update app") {
                        startUpdate()
                    }
                    .help("Download the latest Jetmoji from jetmoji.fun, compile it, and restart.")
                }
                Spacer()
            }
            .padding(.top, 4)

            if let updateMessage {
                Text(updateMessage)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(updateFailed ? JetmojiTheme.flame : JetmojiTheme.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func startUpdate() {
        guard !updatingApp else { return }
        updatingApp = true
        updateFailed = false
        updateMessage = "Downloading and compiling the latest Jetmoji. The app will restart."
        Task {
            let outcome = await Task.detached(priority: .userInitiated) {
                AppUpdater.installLatest()
            }.value
            if outcome.succeeded {
                updateMessage = "Restarting…"
                PasteService.relaunchApp(bundlePath: AppUpdater.installedAppPath)
            } else {
                updatingApp = false
                updateFailed = true
                updateMessage = outcome.message
            }
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(JetmojiTheme.text)
                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(JetmojiTheme.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(JetmojiTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(JetmojiTheme.line, lineWidth: 1)
        )
    }
}

struct SlotEditorRow: View {
    let slot: EmojiSlot
    @ObservedObject var store: JetmojiStore
    var onChange: () -> Void
    @State private var emojiDraft = ""
    @FocusState private var emojiFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("\(slot.id)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(JetmojiTheme.mute)
                    .frame(width: 16)

                TextField("", text: $emojiDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 28))
                    .multilineTextAlignment(.center)
                    .focused($emojiFocused)
                    .frame(width: 48, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(JetmojiTheme.ink)
                    )
                    .help("Type or paste an emoji")
                    .onAppear { emojiDraft = slot.emoji }
                    .onChange(of: slot.emoji) { _, newValue in emojiDraft = newValue }
                    .onChange(of: emojiFocused) { _, focused in
                        guard focused else { return }
                        DispatchQueue.main.async {
                            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                        }
                    }
                    .onChange(of: emojiDraft) { _, newValue in
                        if let emoji = SlotText.emojiFromEdit(previous: slot.emoji, draft: newValue), emoji != slot.emoji {
                            applyEmoji(emoji)
                        } else if newValue != slot.emoji && SlotText.emojiFromEdit(previous: slot.emoji, draft: newValue) == nil && !newValue.isEmpty {
                            emojiDraft = slot.emoji
                        }
                    }
                    .onPasteCommand(of: [UTType.utf8PlainText, UTType.plainText]) { _ in
                        pasteEmojiFromClipboard()
                    }

                VStack(alignment: .trailing, spacing: 1) {
                    Text(slot.useCount.formatted())
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(slot.useCount > 0 ? JetmojiTheme.sky : JetmojiTheme.mute)
                    Text(slot.useCount == 1 ? "use" : "uses")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(JetmojiTheme.mute)
                }
                .frame(width: 44, alignment: .trailing)
                .help("Times this pad was copied or pasted")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(slot.useCount) \(slot.useCount == 1 ? "use" : "uses")")

                ShortcutRecorder(slot: slot, store: store, onChange: onChange)

                Toggle("", isOn: Binding(
                    get: { slot.enabled },
                    set: {
                        store.setEnabled($0, for: slot.id)
                        onChange()
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .help(slot.enabled ? "Pad enabled" : "Pad disabled")
            }

            if emojiFocused {
                EmojiPalette(
                    onPick: applyEmoji,
                    onPaste: pasteEmojiFromClipboard
                )
            }
        }
        .padding(.vertical, 8)
    }

    private func applyEmoji(_ emoji: String) {
        emojiDraft = emoji
        guard emoji != slot.emoji else { return }
        store.setEmoji(emoji, for: slot.id)
        onChange()
    }

    private func pasteEmojiFromClipboard() {
        guard let raw = NSPasteboard.general.string(forType: .string),
              let emoji = SlotText.emojiFromPaste(raw)
        else { return }
        applyEmoji(emoji)
    }
}

struct EmojiPalette: View {
    var onPick: (String) -> Void
    var onPaste: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onPaste) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Paste emoji")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                    Spacer()
                    Text("⌘V")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(JetmojiTheme.mute)
                }
                .foregroundStyle(JetmojiTheme.text)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(JetmojiTheme.panel)
                )
            }
            .buttonStyle(.plain)
            .help("Paste an emoji from the clipboard")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10), spacing: 4) {
                ForEach(JetmojiTheme.palette, id: \.self) { emoji in
                    Button {
                        onPick(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 16))
                            .frame(maxWidth: .infinity, minHeight: 26)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(JetmojiTheme.ink)
        )
    }
}

struct ShortcutRecorder: View {
    let slot: EmojiSlot
    @ObservedObject var store: JetmojiStore
    var onChange: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button {
                startRecording()
            } label: {
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(store.recordingSlotID == slot.id ? JetmojiTheme.ink : JetmojiTheme.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(store.recordingSlotID == slot.id ? JetmojiTheme.sky : JetmojiTheme.ink)
                    )
            }
            .buttonStyle(.plain)
            .help("Click, then press a shortcut. Esc cancels. Delete clears.")

            Button("Clear") {
                store.setShortcut(nil, for: slot.id)
                onChange()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(JetmojiTheme.mute)
        }
    }

    private var label: String {
        if store.recordingSlotID == slot.id {
            return "Press shortcut…"
        }
        return slot.resolvedShortcut?.displayString ?? "Click to record"
    }

    private func startRecording() {
        store.recordingSlotID = slot.id
        HotkeyCenter.shared.pause()
        ShortcutCapture.shared.begin { shortcut in
            if let shortcut {
                if shortcut.isEmpty {
                    store.setShortcut(nil, for: slot.id)
                } else {
                    store.setShortcut(shortcut, for: slot.id)
                }
            }
            store.recordingSlotID = nil
            HotkeyCenter.shared.resume()
            onChange()
        }
    }
}

@MainActor
final class ShortcutCapture {
    static let shared = ShortcutCapture()
    private var monitor: Any?
    private var handler: ((Shortcut?) -> Void)?

    func begin(handler: @escaping (Shortcut?) -> Void) {
        end()
        self.handler = handler
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == UInt16(kVK_Escape) {
                self?.finish(nil)
                return nil
            }
            guard let shortcut = Shortcut.from(event: event) else { return nil }
            self?.finish(shortcut)
            return nil
        }
    }

    func end() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        handler = nil
    }

    private func finish(_ shortcut: Shortcut?) {
        let callback = handler
        end()
        callback?(shortcut)
    }
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let store: JetmojiStore
    var onChange: (() -> Void)?

    init(store: JetmojiStore) {
        self.store = store
    }

    func show() {
        if window == nil {
            let root = SettingsView(store: store, onChange: { [weak self] in
                self?.onChange?()
            })
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Jetmoji Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 560, height: 680))
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        ShortcutCapture.shared.end()
        store.recordingSlotID = nil
        HotkeyCenter.shared.resume()
    }
}
