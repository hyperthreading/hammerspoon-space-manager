# Focus Window Cache Design

**Goal:** Make `Hyper+S` feel instant by removing synchronous window collection from the hotkey path and replacing it with a stale-while-revalidate cache for current-Space windows.

## Context

The current implementation rebuilds chooser data inside the hotkey handler. That path can block for multiple seconds because `hs.window` metadata lookups are backed by macOS Accessibility APIs and may stall on specific windows or during Space transitions.

Measured behavior:

- Fuzzy filtering is negligible.
- Focus handoff is fast after removing repeated `hs.window.get(...)`.
- The remaining latency spike comes from `collectChoices()` running synchronously when `Hyper+S` is pressed.

## Decision

Use a stale-while-revalidate model:

- `Hyper+S` always shows the most recent cached choices immediately.
- Space changes and window/title lifecycle events trigger background cache refreshes.
- Refreshes are debounced so bursts of events collapse into one rebuild.
- No synchronous fallback refresh is performed from the hotkey path.

## Architecture

### State

Keep module-local state for:

- `choices`
- `windowMap`
- `spaceId`
- `lastRefreshAt`
- `refreshScheduled`
- `refreshReason`

### Data Source

Create a dedicated `hs.window.filter` instance scoped to the current Space and configured to include only `AXStandardWindow` roles. This shifts standard-window filtering from per-window checks into the filter itself.

### Refresh Triggers

Refresh cache on:

- Space change via `hs.spaces.watcher`
- Window lifecycle changes from `hs.window.filter`
- Window title changes from `hs.window.filter`
- Initial module warmup

Each trigger schedules a debounced refresh instead of rebuilding immediately.

### Hotkey Behavior

`Hyper+S` reads from cached `choices` only. If the cache is empty, show a lightweight alert and let the next background refresh populate it.

## Tradeoffs

### Pros

- Hotkey interaction stays fast even when AX lookups are temporarily slow.
- Most refresh work moves off the user interaction path.
- The structure supports future per-app workarounds without changing chooser behavior.

### Cons

- Immediately after a Space change, the chooser may briefly show stale results until the background refresh finishes.
- Current-Space tracking in Hammerspoon can still incur delay during refresh; the improvement is that the user no longer waits inside the hotkey path.

## Validation

- `Hyper+S` opens immediately even after a slow AX stall.
- Space switching prewarms the next cache without blocking hotkey handling.
- Window create/destroy/title changes eventually appear in the chooser.
- Slow logs shift from hotkey-triggered `collectChoices` spikes to debounced background refresh logs.
