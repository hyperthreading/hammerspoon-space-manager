# Dynamic Space Management Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Spaces dynamically creatable and removable while keeping aliases stable across reordering.

**Architecture:** Replace the static `config.spaces` list with a per-screen cache keyed by macOS `spaceID`. Update the switch, move, rename, and new manage-space flows to read dynamic space lists and persist aliases by `spaceID` instead of index.

**Tech Stack:** Hammerspoon Lua, `hs.spaces`, `hs.dialog`, existing chooser utilities in `lib/`.

---

### Task 1: Replace Index-Based Alias State

**Files:**

- Modify: `config.lua`

**Step 1: Load persisted aliases and current Spaces**

Read `space-names.json`, inspect the current screen Space IDs from `hs.spaces.spacesForScreen()`, and build runtime entries with both `id` and derived `index`.

**Step 2: Migrate legacy numeric keys**

Use old `1..N` keys only as a fallback during lookup, then rewrite persisted aliases using `spaceID` keys on the next save.

**Step 3: Add helper functions**

Expose helpers for current screen lookup, refresh, `getSpaces`, `getSpaceById`, `getSpaceByIndex`, and `getCurrentSpace`.

### Task 2: Update Existing Space Consumers

**Files:**

- Modify: `modules/switch-space.lua`
- Modify: `modules/move-window.lua`
- Modify: `modules/rename-space.lua`

**Step 1: Switch by `spaceID`**

Replace `Ctrl+digit` Space switching with `hs.spaces.gotoSpace(spaceID)`.

**Step 2: Keep move-window working with dynamic lists**

Populate palette choices from the current screen's dynamic Spaces, then resolve each choice back to a current index before running the drag workaround.

**Step 3: Rename by `spaceID`**

Look up the active Space through config helpers and persist the rename through the new alias store.

### Task 3: Add Runtime Space Management

**Files:**

- Create: `modules/manage-space.lua`
- Modify: `init.lua`
- Modify: `config.lua`

**Step 1: Add hotkeys for add/remove**

Bind `Hyper+=` to create a Space and `Hyper+-` to remove the current Space.

**Step 2: Confirm destructive removal**

Prompt before deletion, switch to a neighbor Space, then remove the original Space after the active Space change is observed.

**Step 3: Refresh caches on topology changes**

Use an `hs.spaces.watcher` so Space additions and deletions are reflected without reloading Hammerspoon.

### Task 4: Validate the Configuration

**Files:**

- Test: `config.lua`
- Test: `init.lua`
- Test: `modules/*.lua`

**Step 1: Run syntax validation**

Run: `luac -p config.lua init.lua lib/*.lua modules/*.lua`
Expected: no output

**Step 2: Reload Hammerspoon and verify manually**

Check:

- `Hyper+=` adds a Space
- `Hyper+-` removes the current Space after confirmation
- `Hyper+Space` reflects the new Space order
- Renamed aliases stay attached after add/remove
- `Hyper+M` still moves windows to the selected Space
