# hammerspoon-space-manager

A keyboard-driven macOS Space (virtual desktop) and window manager built on [Hammerspoon](https://www.hammerspoon.org/).

Switch spaces, move windows, rename desktops — all from a fast fuzzy-search palette without ever touching the trackpad.

## Features

- **Switch Space** — fuzzy-search palette to jump to any space instantly
- **Move Window** — send the focused window to another space via palette or direct hotkeys
- **Focus Window** — palette listing all windows on the current space with app icons
- **Rename Space** — give each space a custom name and emoji icon, persisted across restarts
- **Add / Remove Space** — create or delete spaces from the keyboard
- **Multi-monitor support** — each screen maintains its own space list
- **Custom palette UI** — dark-themed webview palette with fuzzy search, or fall back to the native `hs.chooser`

## Requirements

- macOS
- [Hammerspoon](https://www.hammerspoon.org/) (0.9.100+)
- **System Settings > Desktop & Dock > Shortcuts**: assign Ctrl+1 through Ctrl+9 to "Switch to Desktop N" (required for the move-window drag workaround on spaces 1–9)

## Installation

```bash
git clone https://github.com/hyperthreading/hammerspoon-space-manager.git ~/.hammerspoon
```

If you already have a Hammerspoon config, copy the files into your existing `~/.hammerspoon/` directory and merge `init.lua`.

Then reload Hammerspoon (`Cmd+Shift+R` from the Hammerspoon menu, or `hs.reload()` in the console).

## Key Bindings

All bindings use the **Hyper** key (`Ctrl + Alt + Shift + Cmd`).

| Key | Action |
| --- | --- |
| `Hyper + Space` | Open space switcher palette |
| `Hyper + S` | Open window switcher palette |
| `Hyper + M` | Open move-window-to-space palette |
| `Hyper + 1–9` | Move focused window to space 1–9 |
| `Hyper + R` | Rename current space |
| `Hyper + =` | Add a new space |
| `Hyper + -` | Remove current space |

Bindings are configured in [`config.lua`](config.lua).

## Project Structure

```
├── init.lua              # Entry point — loads all modules
├── config.lua            # Shared config, space cache, persistence
├── space-names.json      # Persisted space names and icons
├── lib/
│   ├── palette.lua       # Palette factory (delegates to backend)
│   ├── builtin-palette.lua   # hs.chooser-based palette
│   ├── custom-palette.lua    # Webview-based dark palette
│   └── fuzzy.lua         # Fuzzy matching engine
└── modules/
    ├── switch-space.lua  # Switch to a space
    ├── move-window.lua   # Move window to a space
    ├── focus-window.lua  # Focus a window on current space
    ├── rename-space.lua  # Rename a space
    └── manage-space.lua  # Add/remove spaces
```

## Configuration

Edit [`config.lua`](config.lua) to customize:

```lua
-- Modifier keys (default: Hyper)
M.hyper = { "ctrl", "alt", "shift", "cmd" }

-- Palette backend: "custom" (webview) or "builtin" (hs.chooser)
M.paletteBackend = "custom"

-- Key bindings
M.keybindings = {
    switchToSpace    = { key = "space" },
    focusWindow      = { key = "s" },
    moveWindowToSpace = { key = "m" },
    renameSpace      = { key = "r" },
    addSpace         = { key = "=" },
    removeSpace      = { key = "-" },
}
```

Default space names and icons can also be changed in the `defaultSpaces` table in `config.lua`.

## How It Works

### Space Persistence

Space names are stored by space ID (not index) in `space-names.json`, so custom names survive when spaces are reordered. Names are loaded on startup and saved automatically after any change.

### Move Window Strategy

For spaces 1–9, the module uses a drag-and-drop workaround — it programmatically grabs the window's zoom button and simulates `Ctrl+N` (the macOS native shortcut) during the drag. This is more reliable than the `hs.spaces` API for cross-space moves. Spaces 10+ fall back to the API.

### Fuzzy Search

The palette uses a custom scoring algorithm that rewards early matches, consecutive characters, and exact case matches. It searches across multiple fields (space name, index, app name, window title) depending on context.

## License

MIT
