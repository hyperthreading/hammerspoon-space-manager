# Window Focus Switcher Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `Hyper+S` palette that focuses a window in the current Space using fuzzy matching on app name and window title.

**Architecture:** Reuse the shared chooser and fuzzy-search helpers already in `lib/`. Add one new module that builds chooser entries from `hs.window.filter.defaultCurrentSpace`, then wire the new module into config and startup.

**Tech Stack:** Hammerspoon Lua, `hs.window.filter`, `hs.window`, shared chooser utilities in `lib/`.

---

### Task 1: Document the New Hotkey

**Files:**

- Modify: `config.lua`

**Step 1: Add the new keybinding entry**

Add `focusWindow = { key = "s" }` under `M.keybindings`.

**Step 2: Verify the existing Space-switch key remains unchanged**

Check that `switchToSpace = { key = "space" }` stays in place.

**Step 3: Commit**

```bash
git add config.lua
git commit -m "chore: add focus window keybinding"
```

### Task 2: Implement the Window Focus Palette

**Files:**

- Create: `modules/focus-window.lua`
- Modify: `init.lua`

**Step 1: Build current-Space window choices**

Use `hs.window.filter.defaultCurrentSpace:getWindows()` and convert each standard window into chooser items containing:

- `text`: app name
- `subText`: window title
- `_appName`: app name for fuzzy search
- `_title`: window title for fuzzy search
- `win`: target `hs.window` object

**Step 2: Bind the chooser to `Hyper+S`**

Use `lib.palette.bind` with placeholder text for focusing windows in the current Space.

**Step 3: Focus the selected window**

In `onSelect`, call `focus()` and `raise()` on the chosen window.

**Step 4: Register the module at startup**

Require the new module from `init.lua`.

**Step 5: Commit**

```bash
git add init.lua modules/focus-window.lua
git commit -m "feat: add current-space window focus palette"
```

### Task 3: Validate the Configuration

**Files:**

- Test: `config.lua`
- Test: `init.lua`
- Test: `modules/focus-window.lua`

**Step 1: Run Lua syntax validation**

Run: `luac -p config.lua init.lua lib/fuzzy.lua lib/palette.lua modules/*.lua`
Expected: no output

**Step 2: Reload Hammerspoon and verify behavior manually**

Run through this checklist:

- `Hyper+S` opens the chooser
- Typing app name narrows results
- Typing window title narrows results
- Selecting a result focuses the matching window

**Step 3: Commit**

```bash
git add docs/plans/2026-03-29-window-focus-switcher.md
git commit -m "docs: add window focus switcher plan"
```
