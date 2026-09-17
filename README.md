# Jetmoji

Ten emoji pads in your Mac’s menu bar. Hit a shortcut anywhere and the emoji pastes immediately — then stays on the clipboard, so ⌘V keeps going.

**jetmoji.fun** · Apple Silicon · macOS 14+

## Install

From this folder:

```bash
bash install.sh
open /Applications/Jetmoji.app
```

Or build without installing:

```bash
bash build.sh
open build/Jetmoji.app
```

Jetmoji lives in the menu bar (no Dock icon). Click the jet to see your pads. Allow Accessibility when macOS asks if you want shortcuts to paste into other apps; without it, shortcuts still copy and you can paste with ⌘V.

## Use

- **Click a pad** to copy that emoji. The next ⌘V pastes it, as many times as you want.
- **Press the pad’s shortcut** from any app to paste immediately *and* leave that emoji on the clipboard.
- Defaults are **⌥⌘0** through **⌥⌘9** (Command-Option, not Command-Shift, so they don’t steal macOS screenshots). Rebind any pad in Settings — for example **⌘⇧0** for 😂.
- **Right-click** the menu bar icon for Settings or Quit.
- Click an emoji in Settings, then type or pick from the palette. Click the shortcut chip and press a new combo. Esc cancels; Delete clears.

## CLI

After `bash install.sh`, `~/.local/bin/jetmoji` is linked (add that directory to your PATH if needed). The app must be running for `paste`.

```bash
jetmoji status          # JSON of the current pads
jetmoji paste 0         # Paste pad 0 into the front app
jetmoji set 0 😂        # Change pad 0
jetmoji reset           # Restore defaults
jetmoji help
```

You can also run `/Applications/Jetmoji.app/Contents/MacOS/Jetmoji --cli status`.

## Build

Xcode command-line tools are enough. No packages to install.

```bash
bash build.sh
```

Settings are stored at `~/Library/Application Support/Jetmoji/config.json`. Nothing is uploaded.

This is an early local build. The site in `site/` is ready for [jetmoji.fun](https://jetmoji.fun) when that domain is pointed here.
