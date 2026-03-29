# Dynamic Space Management Design

**Goal:** Let the Hammerspoon config add and remove macOS Spaces at runtime without breaking space names, switch targets, or move-window choices.

## Requirements

- Support creating a new Space from Hammerspoon.
- Support deleting the current Space from Hammerspoon.
- Keep renamed Space aliases stable after insertions and deletions.
- Refresh switch and move palettes after Space topology changes.
- Preserve the existing rename and move workflows.

## Approaches Considered

### 1. Keep index-based aliases and patch around reordering

This keeps `config.spaces` keyed by `1..N` and tries to update later indices after every add or remove. It is simple to start, but it makes rename persistence fragile because deleting one Space shifts every later index.

### 2. Treat `spaceID` as the source of truth and derive index on demand

This uses the macOS-managed `spaceID` as the persistent key, then recalculates the visible index each time the current screen's Spaces are queried. Renames survive reordering, palettes always show current positions, and add/remove can reuse Hammerspoon's `hs.spaces` APIs.

### 3. Delegate Space management to an external tool

This would move creation and deletion into yabai or AppleScript wrappers. It adds another dependency without solving the alias-mapping problem by itself, so it is unnecessary here.

## Recommended Approach

Use `spaceID` as the durable identifier and treat the visible Space number as derived state.

`config.lua` should load persisted aliases from `space-names.json`, build per-screen space lists from `hs.spaces.spacesForScreen()`, and expose helpers for:

- current screen lookup
- refreshing cached space lists
- finding a space by ID or current index
- persisting aliases keyed by `spaceID`

To avoid losing existing names, the loader should temporarily honor the current numeric-key format as a legacy fallback, then rewrite the file in the new `spaceID`-keyed format on the next save.

## Interaction Model

- `Hyper+Space`: switch palette, now backed by `hs.spaces.gotoSpace(spaceID)`
- `Hyper+M`: move-window palette, now shows dynamic Space choices
- `Hyper+R`: rename the current Space by `spaceID`
- `Hyper+=`: add a new Space on the current screen
- `Hyper+-`: delete the current Space after confirmation

Deleting the current Space must first switch to a neighbor, because `hs.spaces.removeSpace()` cannot remove the active Space. The implementation should use a temporary `hs.spaces.watcher` to wait for the switch before invoking the delete.

## Validation

- Add a Space and confirm it appears in the switch palette without reloading config.
- Rename a Space, delete an earlier Space, and confirm the renamed alias stays attached to the same desktop.
- Delete the current Space and confirm the flow switches away first, then removes it.
- Confirm `Hyper+M` still moves windows for the first nine Spaces and falls back to `hs.spaces.moveWindowToSpace()` beyond that range.
