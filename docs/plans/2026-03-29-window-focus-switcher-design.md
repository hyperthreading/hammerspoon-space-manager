# Window Focus Switcher Design

**Goal:** Add a `Hyper+S` command palette that fuzzy-matches windows in the current Space by app name and window title, then focuses the selected window.

## Requirements

- Reuse the existing chooser-based palette pattern.
- Only include windows visible in the current Space.
- Search against both app name and window title.
- Focus and raise the selected window.
- Keep the existing Space switcher on `Hyper+Space`.

## Approach

Create a new `modules/focus-window.lua` module and register it from `init.lua`. The module will use `hs.window.filter.defaultCurrentSpace:getWindows()` to enumerate windows in the current Space, then map each window into chooser items that expose app name and title as fuzzy-search keys.

The chooser will display `App Name` as the main text and `Window Title` as the subtitle so scanning stays fast. On selection, the module will call `focus()` and `raise()` on the target window. Non-standard windows and entries with no usable app or title metadata will be filtered out to reduce noise.

## Validation

- Confirm `Hyper+S` opens the chooser.
- Confirm fuzzy search matches app name and window title.
- Confirm the selected window becomes focused and frontmost.
- Confirm the config still loads with `Hyper+Space` for Space switching.
