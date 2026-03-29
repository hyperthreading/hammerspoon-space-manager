# Focus Window Cache Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor the `Hyper+S` window switcher to use a stale-while-revalidate cache so hotkey interaction no longer blocks on current-Space window collection.

**Architecture:** Move current-Space window discovery into a dedicated cache layer maintained by `hs.window.filter` and `hs.spaces.watcher` subscriptions. Keep chooser interaction read-only against cached state, and debounce all refresh triggers so AX-heavy rebuilds happen in the background instead of inside the hotkey callback.

**Tech Stack:** Hammerspoon Lua, `hs.window.filter`, `hs.spaces.watcher`, `hs.timer`, `hs.chooser`, existing fuzzy matcher and IPC profiling helpers.

---

### Task 1: Restructure Module State

**Files:**

- Modify: `modules/focus-window.lua`

**Step 1: Add explicit cache state**

Introduce module-local state for cached chooser data and refresh bookkeeping:

- `choices`
- `windowMap`
- `spaceId`
- `lastRefreshAt`
- `refreshScheduled`
- `refreshReason`
- `refreshTimer`

**Step 2: Separate pure choice-building from refresh orchestration**

Keep a pure helper that converts windows into chooser items, then add separate helpers for:

- collecting windows from the active filter
- replacing cache state atomically
- scheduling debounced refreshes

**Step 3: Commit**

```bash
git add modules/focus-window.lua
git commit -m "refactor: add cached state for focus window chooser"
```

### Task 2: Move Standard-Window Filtering into hs.window.filter

**Files:**

- Modify: `modules/focus-window.lua`

**Step 1: Create a dedicated filter instance**

Instantiate a module-owned `hs.window.filter` configured for current-Space windows.

**Step 2: Configure role filtering**

Use filter rules that only keep standard windows, so `win:isStandard()` is no longer needed in the hot path.

**Step 3: Add a helper for reading windows from the filter**

Centralize all window reads through the dedicated filter instance.

**Step 4: Commit**

```bash
git add modules/focus-window.lua
git commit -m "refactor: use window filter rules for standard windows"
```

### Task 3: Add Background Refresh and Debounce

**Files:**

- Modify: `modules/focus-window.lua`

**Step 1: Implement `refreshCache(reason)`**

Refresh cached choices and window map from the dedicated filter, record timing, and update cache metadata.

**Step 2: Implement `scheduleRefresh(reason)`**

Debounce repeated refresh triggers so bursts collapse into one refresh.

**Step 3: Log refresh timing by reason**

Replace the current hotkey-centric slow log with refresh-centric logs that identify:

- refresh reason
- refresh duration
- cached window count

**Step 4: Commit**

```bash
git add modules/focus-window.lua
git commit -m "feat: debounce focus window cache refreshes"
```

### Task 4: Subscribe to Space and Window Events

**Files:**

- Modify: `modules/focus-window.lua`

**Step 1: Add a `hs.spaces.watcher` subscription**

Schedule a cache refresh when the active Space changes.

**Step 2: Add `hs.window.filter` subscriptions**

Schedule cache refreshes for:

- window creation/destruction
- window title changes
- relevant window set changes

**Step 3: Warm the cache at module startup**

Schedule an initial refresh during `init()` so the first hotkey press has data ready.

**Step 4: Commit**

```bash
git add modules/focus-window.lua
git commit -m "feat: prewarm focus window cache on space and window events"
```

### Task 5: Remove Synchronous Collection from the Hotkey Path

**Files:**

- Modify: `modules/focus-window.lua`

**Step 1: Update chooser open behavior**

Make `Hyper+S` read only from cached `choices` and never call a synchronous collection helper.

**Step 2: Preserve stale-while-revalidate semantics**

If cache exists, show it immediately even if a refresh is pending.

**Step 3: Handle empty cache safely**

If cache is empty, show a lightweight alert instead of blocking for a synchronous rebuild.

**Step 4: Commit**

```bash
git add modules/focus-window.lua
git commit -m "perf: remove synchronous collection from focus hotkey"
```

### Task 6: Re-check Focus Handoff Path

**Files:**

- Modify: `modules/focus-window.lua`

**Step 1: Keep cached window-object resolution as the primary path**

Use cached window objects first and fall back to `hs.window.get(...)` only if the cached object is stale.

**Step 2: Measure `focus()` versus `focus()+raise()`**

Re-check whether `raise()` is still necessary for reliable frontmost behavior.

**Step 3: Keep the lower-latency path**

If `focus()` alone is sufficient, remove `raise()`. Otherwise leave it in place with a short comment explaining why.

**Step 4: Commit**

```bash
git add modules/focus-window.lua
git commit -m "perf: tune focus handoff path"
```

### Task 7: Validate with IPC Profiling and Manual Checks

**Files:**

- Test: `modules/focus-window.lua`
- Test: `init.lua`

**Step 1: Run syntax validation**

Run: `luajit -e 'assert(loadfile("init.lua")); assert(loadfile("modules/focus-window.lua"))'`
Expected: no output

**Step 2: Reload Hammerspoon**

Run: `hs -q -c 'hs.reload(); return "reloaded"'`
Expected: reload completes and IPC reconnects

**Step 3: Measure cache refresh, fuzzy, and focus timings**

Run:

```bash
hs -t 10 -q -c 'return hs.inspect(require("modules.focus-window").profileBuildChoices())'
hs -t 10 -q -c 'return hs.inspect(require("modules.focus-window").profileFuzzy("zed focus"))'
hs -t 10 -q -c 'local focus=require("modules.focus-window"); local win=hs.window.focusedWindow(); return hs.inspect(focus.profileFocusWindow(win and win:id() or nil))'
```

Expected:

- no hotkey-path rebuild spike
- fuzzy time remains negligible
- focus handoff stays low-latency

**Step 4: Manually verify stale-while-revalidate behavior**

Check:

- `Hyper+S` opens immediately after idle use
- `Hyper+S` opens immediately after Space changes
- newly created or renamed windows appear after the background refresh
- temporary stale results self-correct without blocking

**Step 5: Commit**

```bash
git add modules/focus-window.lua init.lua docs/plans/2026-03-29-focus-window-cache-design.md docs/plans/2026-03-29-focus-window-cache.md
git commit -m "plan: optimize focus window chooser with background cache"
```
