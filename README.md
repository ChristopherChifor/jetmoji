# Jetmoji

Ten emoji pads in your Mac’s menu bar. Hit a shortcut anywhere in macOS and the emoji pastes immediately, then stays on your clipboard so ⌘V can keep going.

**[jetmoji.fun](https://jetmoji.fun)** · Apple Silicon · macOS 14+ · menu bar 😂

## Install

Build it on your Mac (no paid Apple Developer account, no download dialog):

```bash
git clone https://github.com/ChristopherChifor/jetmoji.git
cd jetmoji
bash install.sh
open /Applications/Jetmoji.app
```

Xcode Command Line Tools are required (`xcode-select --install` if `swift` is missing). That compiles from source and copies the app into `/Applications`.

Already in this folder? `bash install.sh` is enough. To build without installing: `bash build.sh` then `open build/Jetmoji.app`.

## Use

Jetmoji stays in the menu bar (no Dock icon). Open at login is on by default.

- **Click 😂** to open your pads. Click a pad to copy that emoji. The next ⌘V pastes it, as many times as you want. The menu bar icon briefly flashes the emoji you copied.
- **Press a shortcut** from any app to insert at the cursor *and* leave that emoji on the clipboard, so the next four ⌥⌘0s are 😂😂😂😂.
- Defaults are **⌥⌘0** through **⌥⌘9** (Command-Option, so they don’t steal macOS screenshots). In Settings you can swap any emoji, rebind any shortcut (including ⌘⇧0), or disable a pad.
- **Right-click** 😂 for Settings or Quit.

Allow **Accessibility** when macOS asks if you want shortcuts to paste into other apps. Without it, shortcuts still copy and you paste with ⌘V. If a leftover Jetmoji row from an older build is stuck off, add `/Applications/Jetmoji.app` with +, then Quit & Reopen from the popover.

## CLI

After `bash install.sh`, `~/.local/bin/jetmoji` is linked (add that directory to your PATH if needed). The app must be running for `paste`.

```bash
jetmoji status          # JSON of the current pads
jetmoji list            # one pad per line
jetmoji paste 0         # paste pad 0 into the front app
jetmoji set 0 😂        # change pad 0
jetmoji reset           # restore defaults
jetmoji help
```

You can also run `/Applications/Jetmoji.app/Contents/MacOS/Jetmoji --cli status`.

## Privacy

Jetmoji is a tiny local utility. Settings live at `~/Library/Application Support/Jetmoji/config.json`. It does not save or upload your clipboard anywhere.
